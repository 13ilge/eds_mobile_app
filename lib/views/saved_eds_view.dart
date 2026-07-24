import 'package:flutter/material.dart';
import '../models/eds_point.dart';
import '../services/eds_storage_service.dart';
import '../theme/design_tokens.dart';

class SavedEdsView extends StatefulWidget {
  const SavedEdsView({super.key});

  @override
  State<SavedEdsView> createState() => _SavedEdsViewState();
}

class _SavedEdsViewState extends State<SavedEdsView> {
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
