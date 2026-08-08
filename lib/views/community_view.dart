import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shimmer/shimmer.dart';
import '../models/community_point.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/eds_point.dart';
import '../providers/sharing_provider.dart';
import '../services/eds_storage_service.dart';
import '../services/eds_geofence_service.dart';
import '../theme/design_tokens.dart';

class CommunityView extends ConsumerStatefulWidget {
  const CommunityView({super.key});

  @override
  ConsumerState<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends ConsumerState<CommunityView> {
  String _selectedRegion = 'malatya';
  final List<CommunityPoint> _points = [];
  List<EdsPoint> _customPoints = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final Map<String, bool> _upvoteStates = {};
  final ScrollController _scrollController = ScrollController();
  DocumentSnapshot? _lastDoc;

  static const List<String> _regions = [
    'Malatya', 'Elazığ', 'Ankara', 'İstanbul', 'İzmir',
    'Bursa', 'Antalya', 'Adana', 'Konya', 'Gaziantep',
    'Kayseri', 'Mersin', 'Diyarbakır', 'Samsun', 'Trabzon',
    'Eskişehir', 'Denizli', 'Sakarya', 'Muğla', 'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadCustomPoints();
    _loadPoints(reset: true);
  }

  Future<void> _loadCustomPoints() async {
    final points = await EdsStorageService().loadCustomPoints();
    if (mounted) {
      setState(() => _customPoints = points);
    }
  }

  Future<void> _loadPoints({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (reset) {
      _points.clear();
      _hasMore = true;
      _upvoteStates.clear();
      _lastDoc = null;
    }

    try {
      final service = ref.read(sharingServiceProvider);
      final result = await service.getCommunityPoints(
        region: _selectedRegion,
        limit: 20,
        lastDoc: _lastDoc,
      );

      final newPoints = result['points'] as List<CommunityPoint>;
      _lastDoc = result['lastDoc'] as DocumentSnapshot?;

      // Parallel fetch instead of sequential N+1 reads (F1 optimization)
      final voteResults = await Future.wait(
        newPoints.map((point) => service.hasUpvoted(point.id)),
      );
      for (int i = 0; i < newPoints.length; i++) {
        _upvoteStates[newPoints[i].id] = voteResults[i];
      }

      setState(() {
        _points.addAll(newPoints);
        _hasMore = newPoints.length == 20;
        _isLoading = false;
      });
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Yükleme hatası: $e')),
        );
      }
    }
  }

  Future<void> _toggleUpvote(CommunityPoint point) async {
    final service = ref.read(sharingServiceProvider);
    final hasVoted = _upvoteStates[point.id] ?? false;

    try {
      if (hasVoted) {
        await service.removeUpvote(point.id);
      } else {
        await service.upvoteCommunityPoint(point.id);
      }

      setState(() {
        _upvoteStates[point.id] = !hasVoted;
        final idx = _points.indexWhere((p) => p.id == point.id);
        if (idx != -1) {
          final old = _points[idx];
          _points[idx] = CommunityPoint(
            id: old.id,
            ownerUid: old.ownerUid,
            ownerName: old.ownerName,
            edsPoint: old.edsPoint,
            upvotes: old.upvotes + (hasVoted ? -1 : 1),
            region: old.region,
            geoHash: old.geoHash,
            createdAt: old.createdAt,
          );
        }
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Oylama hatası: $e')),
        );
      }
    }
  }

  Future<void> _importPoint(CommunityPoint point) async {
    try {
      await ref.read(sharingServiceProvider).importCommunityPoint(point);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${point.edsPoint.name} noktanıza eklendi!')),
        );
        _loadCustomPoints();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  bool _isPointImported(CommunityPoint point) {
    return _customPoints.any((existing) => existing.hasSameCoordinates(point.edsPoint));
  }

  Future<void> _removePoint(CommunityPoint point) async {
    try {
      final target = _customPoints.firstWhere((existing) => existing.hasSameCoordinates(point.edsPoint));

      await EdsStorageService().deleteCustomPoint(target.id);
      await EdsGeofenceService().reloadPoints();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${point.edsPoint.name} noktanızdan çıkarıldı!')),
        );
        _loadCustomPoints();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DesignTokens.background,
      appBar: AppBar(
        backgroundColor: DesignTokens.background,
        elevation: 0,
        centerTitle: true,
        title: const Text('Topluluk',
            style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: DropdownButtonFormField<String>(
              value: _selectedRegion,
              decoration: InputDecoration(
                labelText: 'Şehir',
                border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12)),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                filled: true,
                fillColor: DesignTokens.cardSurface,
              ),
              items: _regions.map((r) {
                return DropdownMenuItem(
                  value: r.toLowerCase(),
                  child: Text(r),
                );
              }).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedRegion = val);
                  _loadPoints(reset: true);
                }
              },
            ),
          ),

          Expanded(
            child: _points.isEmpty && _isLoading
                ? _buildShimmerList()
                : _points.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.public_off,
                                size: 64,
                                color: DesignTokens.textGrey.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            const Text(
                              'Bu şehirde henüz paylaşım yok',
                              style: TextStyle(
                                  color: DesignTokens.textGrey, fontSize: 16),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: _points.length + (_hasMore ? 1 : 0),
                        itemBuilder: (context, index) {
                          if (index == _points.length) {
                            return Padding(
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              child: Center(
                                child: _isLoading
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(
                                        onPressed: _loadPoints,
                                        child: const Text('Daha Fazla Yükle'),
                                      ),
                              ),
                            );
                          }

                          final point = _points[index];
                          final hasVoted =
                              _upvoteStates[point.id] ?? false;
                          final isImported = _isPointImported(point);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: DesignTokens.cardDecoration,
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.location_on,
                                        color: DesignTokens.primaryBlue,
                                        size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        point.edsPoint.name,
                                        style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            color: DesignTokens.textDark,
                                            fontSize: 15),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: DesignTokens.primaryBlue
                                            .withValues(alpha: 0.1),
                                        borderRadius:
                                            BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${point.edsPoint.speedLimit} km/h',
                                        style: const TextStyle(
                                            color: DesignTokens.primaryBlue,
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    Text(
                                      'Paylaşan: ${point.ownerName}',
                                      style: const TextStyle(
                                          color: DesignTokens.textGrey,
                                          fontSize: 12),
                                    ),
                                    const Spacer(),
                                    GestureDetector(
                                      onTap: () => _toggleUpvote(point),
                                      child: Row(
                                        children: [
                                          Icon(
                                            hasVoted
                                                ? Icons.thumb_up
                                                : Icons.thumb_up_outlined,
                                            color: hasVoted
                                                ? DesignTokens.primaryBlue
                                                : DesignTokens.textGrey,
                                            size: 18,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '${point.upvotes}',
                                            style: TextStyle(
                                              color: hasVoted
                                                  ? DesignTokens.primaryBlue
                                                  : DesignTokens.textGrey,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    GestureDetector(
                                      onTap: () => isImported ? _removePoint(point) : _importPoint(point),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: isImported ? DesignTokens.statusViolation : DesignTokens.statusSafe,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(isImported ? Icons.remove : Icons.add,
                                                color: Colors.white,
                                                size: 16),
                                            const SizedBox(width: 4),
                                            Text(isImported ? 'Çıkar' : 'Ekle',
                                                style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 12,
                                                    fontWeight:
                                                        FontWeight.bold)),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: DesignTokens.cardDecoration,
          child: Shimmer.fromColors(
            baseColor: Colors.grey[300]!,
            highlightColor: Colors.grey[100]!,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(width: 120, height: 14, color: Colors.white),
                        const SizedBox(height: 6),
                        Container(width: 80, height: 10, color: Colors.white),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(width: double.infinity, height: 40, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12))),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: Container(height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                    const SizedBox(width: 16),
                    Expanded(child: Container(height: 32, decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)))),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
