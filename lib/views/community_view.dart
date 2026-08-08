import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/community_point.dart';
import '../providers/sharing_provider.dart';
import '../theme/design_tokens.dart';

class CommunityView extends ConsumerStatefulWidget {
  const CommunityView({super.key});

  @override
  ConsumerState<CommunityView> createState() => _CommunityViewState();
}

class _CommunityViewState extends ConsumerState<CommunityView> {
  String _selectedRegion = 'malatya';
  final List<CommunityPoint> _points = [];
  bool _isLoading = false;
  bool _hasMore = true;
  final Map<String, bool> _upvoteStates = {};

  static const List<String> _regions = [
    'Malatya', 'Elazığ', 'Ankara', 'İstanbul', 'İzmir',
    'Bursa', 'Antalya', 'Adana', 'Konya', 'Gaziantep',
    'Kayseri', 'Mersin', 'Diyarbakır', 'Samsun', 'Trabzon',
    'Eskişehir', 'Denizli', 'Sakarya', 'Muğla', 'Diğer',
  ];

  @override
  void initState() {
    super.initState();
    _loadPoints(reset: true);
  }

  Future<void> _loadPoints({bool reset = false}) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);

    if (reset) {
      _points.clear();
      _hasMore = true;
      _upvoteStates.clear();
    }

    try {
      final service = ref.read(sharingServiceProvider);
      final newPoints = await service.getCommunityPoints(
        region: _selectedRegion,
        limit: 20,
      );

      for (final point in newPoints) {
        final hasVoted = await service.hasUpvoted(point.id);
        _upvoteStates[point.id] = hasVoted;
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
                labelText: 'Åehir',
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
                ? const Center(child: CircularProgressIndicator())
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
                                      onTap: () => _importPoint(point),
                                      child: Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 10, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: DesignTokens.statusSafe,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.add,
                                                color: Colors.white,
                                                size: 16),
                                            SizedBox(width: 4),
                                            Text('Ekle',
                                                style: TextStyle(
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
}
