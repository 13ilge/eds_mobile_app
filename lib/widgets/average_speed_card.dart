import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';
import '../services/audio_service.dart';

class AverageSpeedCard extends StatelessWidget {
  final int speed;
  final SpeedStatus status;
  final double currentDistance;
  final double totalDistance;
  
  final bool hasPermission;
  final String statusMessage;
  final VoidCallback onTap;
  final VoidCallback? onMenuTap;
  final VoidCallback? onAudioTap;
  final AudioMode audioMode;

  const AverageSpeedCard({
    super.key,
    required this.speed,
    required this.status,
    required this.currentDistance,
    required this.totalDistance,
    required this.hasPermission,
    required this.statusMessage,
    required this.onTap,
    this.onMenuTap,
    this.onAudioTap,
    this.audioMode = AudioMode.mute,
  });

  @override
  Widget build(BuildContext context) {
    final statusColor = DesignTokens.getStatusColor(status);
    final height = MediaQuery.of(context).size.height * 0.52;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: double.infinity,
          height: height,
          decoration: BoxDecoration(
            color: DesignTokens.cardSurface,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ).copyWith(
            color: statusColor.withValues(alpha: 0.10),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: hasPermission 
              ? _buildNormalLayout(statusColor) 
              : _buildPermissionWarning(),
        ),
      ),
    );
  }

  Widget _buildPermissionWarning() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.location_off, size: 64, color: DesignTokens.statusWarning),
        const SizedBox(height: 24),
        Text(
          statusMessage,
          style: DesignTokens.labelLarge.copyWith(
            color: DesignTokens.statusWarning,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNormalLayout(Color statusColor) {
    final double progress = totalDistance > 0 ? (currentDistance / totalDistance) : 0.0;
    final clampedProgress = progress.clamp(0.0, 1.0);

    IconData getAudioIcon(AudioMode mode) {
      switch (mode) {
        case AudioMode.mute: return Icons.volume_off;
        case AudioMode.alertsOnly: return Icons.notifications_active;
        case AudioMode.assistant: return Icons.record_voice_over;
      }
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Stack(
          alignment: Alignment.topCenter,
          children: [
            if (onMenuTap != null)
              Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    Icons.menu, 
                    color: DesignTokens.textDark.withValues(alpha: 0.5), 
                    size: 28,
                  ),
                  onPressed: onMenuTap,
                ),
              ),
            if (onAudioTap != null)
              Align(
                alignment: Alignment.topRight,
                child: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    getAudioIcon(audioMode), 
                    color: DesignTokens.textDark.withValues(alpha: 0.5), 
                    size: 28,
                  ),
                  onPressed: onAudioTap,
                ),
              ),
            Column(
              children: [
                const Text(
                  'ORTALAMA HIZ',
                  style: DesignTokens.labelSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  speed.toString(),
                  style: TextStyle(
                    fontSize: 138,
                    fontWeight: FontWeight.w900,
                    color: statusColor,
                    height: 1.0,
                    letterSpacing: -4.0,
                  ),
                ),
                Text(
                  'km/s',
                  style: DesignTokens.labelSmall.copyWith(
                    color: DesignTokens.textDark.withValues(alpha: 0.5),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ],
            ),
          ],
        ),
        Column(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final maxWidth = constraints.maxWidth;
                return Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.centerLeft,
                  children: [
                    Container(
                      height: 8,
                      width: maxWidth,
                      decoration: BoxDecoration(
                        color: DesignTokens.textDark.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    Container(
                      height: 8,
                      width: maxWidth * clampedProgress,
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Gidilen: ${currentDistance.toStringAsFixed(1)} km',
                  style: DesignTokens.labelSmall.copyWith(
                    color: DesignTokens.textDark.withValues(alpha: 0.6),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'Toplam: ${totalDistance.toStringAsFixed(1)} km',
                  style: DesignTokens.labelSmall.copyWith(
                    color: DesignTokens.textDark.withValues(alpha: 0.6),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
