import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/eds_point.dart';
import '../services/eds_storage_service.dart';
import '../services/sharing_service.dart';
import '../providers/auth_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/subscription_provider.dart';
import '../theme/design_tokens.dart';
import 'paywall_view.dart';

class SavedEdsView extends ConsumerStatefulWidget {
  const SavedEdsView({super.key});

  @override
  ConsumerState<SavedEdsView> createState() => _SavedEdsViewState();
}

class _SavedEdsViewState extends ConsumerState<SavedEdsView> {
  final EdsStorageService _storageService = EdsStorageService();
  List<EdsPoint> _points = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPoints();
  }

  Future<void> _loadPoints() async {
    setState(() {
      _isLoading = true;
    });
    final points = await _storageService.loadCustomPoints();
    setState(() {
      _points = points;
      _isLoading = false;
    });
  }

  Future<void> _deletePoint(String id) async {
    await _storageService.deleteCustomPoint(id);
    _loadPoints();
  }

  void _editPoint(EdsPoint point) {
    final nameController = TextEditingController(text: point.name);
    final limitController = TextEditingController(text: point.speedLimit.toString());

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignTokens.cardSurface,
          title: const Text('EDS Düzenle', style: DesignTokens.labelLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 14, color: DesignTokens.textDark),
                decoration: const InputDecoration(
                  labelText: 'Güzergah Adı',
                  labelStyle: TextStyle(fontSize: 14, color: DesignTokens.textGrey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textGrey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textDark)),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: limitController,
                keyboardType: TextInputType.number,
                style: const TextStyle(fontSize: 14, color: DesignTokens.textDark),
                decoration: const InputDecoration(
                  labelText: 'Hız Limiti (km/h)',
                  labelStyle: TextStyle(fontSize: 14, color: DesignTokens.textGrey),
                  border: OutlineInputBorder(),
                  enabledBorder: OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textGrey)),
                  focusedBorder: OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textDark)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('İPTAL', style: TextStyle(fontSize: 14, color: DesignTokens.textGrey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.textDark),
              onPressed: () async {
                final newName = nameController.text.trim();
                final newLimit = int.tryParse(limitController.text.trim()) ?? 82;
                if (newName.isEmpty) return;

                final updatedPoint = EdsPoint(
                  id: point.id,
                  name: newName,
                  startLatitude: point.startLatitude,
                  startLongitude: point.startLongitude,
                  endLatitude: point.endLatitude,
                  endLongitude: point.endLongitude,
                  isBidirectional: point.isBidirectional,
                  speedLimit: newLimit,
                );

                await _storageService.saveCustomPoint(updatedPoint);
                if (!context.mounted) return;
                Navigator.pop(context);
                _loadPoints();
              },
              child: const Text('KAYDET', style: TextStyle(fontSize: 14, color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _showShareDialog(EdsPoint point) {
    final isPro = ref.read(isProProvider);
    if (!isPro) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PaywallView()),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: DesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return _ShareBottomSheet(point: point);
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Kayıtlı Noktalarım'),
        backgroundColor: DesignTokens.background,
        elevation: 0,
        iconTheme: const IconThemeData(color: DesignTokens.textDark),
        titleTextStyle: DesignTokens.labelLarge.copyWith(fontSize: 20),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : _points.isEmpty
          ? _buildEmptyState()
          : _buildList(),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.location_off, size: 64, color: DesignTokens.textGrey),
          const SizedBox(height: 16),
          Text(
            'Henüz özel bir EDS noktası\nkaydetmediniz.',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 14, color: DesignTokens.textGrey),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _points.length,
      itemBuilder: (context, index) {
        final point = _points[index];
        return Card(
          color: DesignTokens.cardSurface,
          margin: const EdgeInsets.only(bottom: 12),
          child: ListTile(
            title: Text(point.name, style: DesignTokens.labelLarge),
            subtitle: Text('Hız Limiti: ${point.speedLimit} km/h', style: DesignTokens.labelSmall),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.share_outlined, color: DesignTokens.primaryBlue),
                  onPressed: () => _showShareDialog(point),
                  tooltip: 'Paylaş',
                ),
                IconButton(
                  icon: const Icon(Icons.edit_outlined, color: DesignTokens.textDark),
                  onPressed: () => _editPoint(point),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, color: DesignTokens.statusViolation),
                  onPressed: () => _deletePoint(point.id),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ShareBottomSheet extends ConsumerStatefulWidget {
  final EdsPoint point;
  const _ShareBottomSheet({required this.point});

  @override
  ConsumerState<_ShareBottomSheet> createState() => _ShareBottomSheetState();
}

class _ShareBottomSheetState extends ConsumerState<_ShareBottomSheet> {
  bool _isSending = false;
  String? _selectedRegion;

  static const List<String> _regions = [
    'Malatya', 'Elazığ', 'Ankara', 'İstanbul', 'İzmir',
    'Bursa', 'Antalya', 'Adana', 'Konya', 'Gaziantep',
    'Kayseri', 'Mersin', 'Diyarbakır', 'Samsun', 'Trabzon',
    'Eskişehir', 'Denizli', 'Sakarya', 'Muğla', 'Diğer',
  ];

  @override
  Widget build(BuildContext context) {
    final friendsAsync = ref.watch(friendsListProvider);

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40, height: 4,
              decoration: BoxDecoration(
                color: DesignTokens.textGrey,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            '${widget.point.name} Paylaş',
            style: DesignTokens.labelLarge.copyWith(fontSize: 18),
          ),
          const SizedBox(height: 24),

          const Text('Arkadaşa Gönder',
              style: TextStyle(fontWeight: FontWeight.w600, color: DesignTokens.textDark, fontSize: 15)),
          const SizedBox(height: 8),
          friendsAsync.when(
            data: (friends) {
              if (friends.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: Text('Henüz arkadaşınız yok.',
                      style: TextStyle(color: DesignTokens.textGrey, fontSize: 13)),
                );
              }
              return SizedBox(
                height: friends.length > 3 ? 160 : (friends.length * 56).toDouble(),
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: friends.length,
                  itemBuilder: (context, index) {
                    final f = friends[index];
                    final myUid = ref.read(currentUserUidProvider) ?? '';
                    final friendName = f.friendNameFor(myUid);
                    final friendUid = f.friendUidFor(myUid);

                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: DesignTokens.primaryBlue.withValues(alpha: 0.1),
                        child: Text(
                          friendName.isNotEmpty ? friendName[0].toUpperCase() : '?',
                          style: const TextStyle(color: DesignTokens.primaryBlue, fontSize: 14),
                        ),
                      ),
                      title: Text(friendName,
                          style: const TextStyle(color: DesignTokens.textDark, fontSize: 14)),
                      trailing: _isSending
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.send, color: DesignTokens.primaryBlue, size: 20),
                      onTap: _isSending
                          ? null
                          : () => _sendToFriend(friendUid, friendName),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => const Text('Arkadaş listesi yüklenemedi.',
                style: TextStyle(color: DesignTokens.textGrey)),
          ),

          const Divider(height: 32),

          const Text('Topluluğa Paylaş',
              style: TextStyle(fontWeight: FontWeight.w600, color: DesignTokens.textDark, fontSize: 15)),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            value: _selectedRegion,
            decoration: const InputDecoration(
              labelText: 'Şehir Seçin',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            ),
            items: _regions.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
            onChanged: (val) => setState(() => _selectedRegion = val),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            onPressed: _selectedRegion == null || _isSending
                ? null
                : () => _shareWithCommunity(),
            style: ElevatedButton.styleFrom(
              backgroundColor: DesignTokens.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.public),
            label: const Text('Topluluğa Paylaş'),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Future<void> _sendToFriend(String friendUid, String friendName) async {
    setState(() => _isSending = true);
    try {
      await SharingService().shareWithFriend(widget.point, friendUid, friendName);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$friendName kullanıcısına gönderildi!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  Future<void> _shareWithCommunity() async {
    setState(() => _isSending = true);
    try {
      await SharingService().shareWithCommunity(widget.point, _selectedRegion!);
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Topluluk havuzuna paylaşıldı!')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Hata: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }
}
