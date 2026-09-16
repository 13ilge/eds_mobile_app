import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../theme/design_tokens.dart';
import '../models/driving_score.dart';
import '../models/eds_point.dart';
import '../providers/friends_provider.dart';
import '../providers/gps_tracking_provider.dart';
import '../providers/sharing_provider.dart';
import '../providers/subscription_provider.dart';
import '../services/eds_geofence_service.dart';
import '../services/eds_storage_service.dart';
import '../widgets/action_button.dart';
import '../widgets/average_speed_card.dart';
import '../widgets/dashboard_timer_metric.dart';
import '../widgets/metric_card.dart';
import '../widgets/score_result_card.dart';
import 'community_view.dart';
import 'friends_view.dart';
import 'inbox_view.dart';
import 'paywall_view.dart';
import 'profile_view.dart';
import 'saved_eds_view.dart';
import 'score_history_view.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});
  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView>
    with WidgetsBindingObserver {
  static const String _permissionMessage =
      "Konum İzni Gerekli\n(İzin vermek için buraya dokunun)";
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Permission + GPS subscription lifecycle handled by the notifier.
    ref.read(gpsTrackingNotifier.notifier).requestPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        !ref.read(gpsTrackingNotifier).hasPermission) {
      ref.read(gpsTrackingNotifier.notifier).requestPermission();
    }
  }

  @override
  Widget build(BuildContext context) {
    final tracking = ref.watch(gpsTrackingNotifier);

    // UI side effects driven by state transitions.
    ref.listen<TrackingState>(gpsTrackingNotifier, (previous, next) {
      if (previous?.event != TrackingUiEvent.enteredEds &&
          next.event == TrackingUiEvent.enteredEds) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'EDS Bölgesine Girildi: ${next.activeEdsPoint?.name}',
            ),
          ),
        );
      }
      if (previous?.event != TrackingUiEvent.exitedEds &&
          next.event == TrackingUiEvent.exitedEds) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('EDS Bölgesinden Çıkıldı. Takip Sonlandırıldı.'),
          ),
        );
      }
      if (next.lastSession != null &&
          previous?.lastSession?.id != next.lastSession?.id) {
        _showScoreDialog(next.lastSession!);
      }
      if (previous?.customEdsPrompt == null && next.customEdsPrompt != null) {
        _promptSaveCustomEds(next.customEdsPrompt!);
      }
    });

    return Scaffold(
      key: _scaffoldKey,
      drawer: _buildDrawer(context),
      body: SafeArea(child: _buildDashboardContent(tracking)),
    );
  }

  Drawer _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: DesignTokens.cardSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: DesignTokens.background,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.speed,
                      size: 36,
                      color: DesignTokens.textDark,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'EDS Asistanı',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: DesignTokens.textDark,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Sürüş ve Radar Kontrol',
                    style: DesignTokens.labelSmall,
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 24.0),
              child: Divider(
                height: 1,
                color: DesignTokens.background,
                thickness: 2,
              ),
            ),
            const SizedBox(height: 24),
            _buildDrawerItem(
              icon: Icons.home_rounded,
              title: 'Sürüş Ekranı',
              onTap: () => Navigator.pop(context),
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.history_rounded,
              title: 'Sürüş Geçmişim',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ScoreHistoryView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.map_rounded,
              title: 'Özel Noktalarım',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const SavedEdsView()),
                ).then((_) => EdsGeofenceService().reloadPoints());
              },
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.person_rounded,
              title: 'Profilim',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const ProfileView()),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildDrawerItemWithBadge(
              icon: Icons.people_rounded,
              title: 'Arkadaşlarım',
              badgeCount: ref.watch(pendingRequestCountProvider),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const FriendsView()),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildDrawerItemWithBadge(
              icon: Icons.inbox_rounded,
              title: 'Gelen Kutusu',
              badgeCount: ref.watch(incomingShareCountProvider),
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InboxView()),
                );
              },
            ),
            const SizedBox(height: 8),
            _buildDrawerItem(
              icon: Icons.public_rounded,
              title: 'Topluluk',
              onTap: () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const CommunityView(),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            if (!ref.watch(isProProvider))
              _buildDrawerItem(
                icon: Icons.workspace_premium,
                title: 'Pro\'ya Yükselt',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const PaywallView(),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildDrawerItemWithBadge({
    required IconData icon,
    required String title,
    required int badgeCount,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, color: DesignTokens.textDark, size: 28),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: DesignTokens.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: DesignTokens.statusViolation,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '$badgeCount',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDrawerItem({
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 16.0),
          child: Row(
            children: [
              Icon(icon, color: DesignTokens.textDark, size: 28),
              const SizedBox(width: 16),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  color: DesignTokens.textDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDashboardContent(TrackingState tracking) {
    final double currentDistanceKm = tracking.isActive
        ? (tracking.currentDistanceMeters / 1000.0)
        : 0.0;
    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AverageSpeedCard(
              speed: tracking.isActive ? tracking.averageSpeed : 0,
              status: tracking.isActive
                  ? tracking.currentStatus
                  : SpeedStatus.safe,
              currentDistance: currentDistanceKm,
              totalDistance: tracking.isActive ? tracking.totalDistanceKm : 0.0,
              hasPermission: tracking.hasPermission,
              statusMessage: _permissionMessage,
              onTap: _handleHeroCardTap,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onAudioTap: () =>
                  ref.read(gpsTrackingNotifier.notifier).cycleAudioMode(),
              audioMode: tracking.audioMode,
            ),

            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'ANLIK HIZ',
                    valueText: tracking.isActive
                        ? tracking.currentLiveSpeed.toString()
                        : '0',
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DashboardTimerMetric(
                    isActive: tracking.isActive,
                    activeEdsPoint: tracking.activeEdsPoint,
                    totalDistance: tracking.isActive
                        ? tracking.totalDistanceKm
                        : 0.0,
                    currentDistanceMeters: tracking.currentDistanceMeters,
                    trackingStartTime: tracking.trackingStartTime,
                    targetSpeed: tracking.targetSpeed,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ActionButton(
              isActive: tracking.isActive,
              status: tracking.currentStatus,
              onTap: () =>
                  ref.read(gpsTrackingNotifier.notifier).toggleTracking(),
            ),
          ],
        ),
      ),
    );
  }

  void _showScoreDialog(DrivingScore score) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      isDismissible: true,
      builder: (context) => ScoreResultCard(
        score: score,
        onDismiss: () => Navigator.pop(context),
      ),
    );
  }

  Future<void> _handleHeroCardTap() async {
    if (!ref.read(gpsTrackingNotifier).hasPermission) {
      await ref.read(gpsTrackingNotifier.notifier).requestPermission();
    }
  }

  void _promptSaveCustomEds(CustomEdsPrompt prompt) {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        return AlertDialog(
          backgroundColor: DesignTokens.cardSurface,
          title: Text('Güzergahı Kaydet', style: DesignTokens.labelLarge),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Katedilen mesafe: ${(prompt.distanceMeters / 1000).toStringAsFixed(1)} km.\nBu rotayı özel EDS noktası olarak kaydetmek ister misiniz?',
                style: const TextStyle(
                  fontSize: 14,
                  color: DesignTokens.textDark,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(
                  fontSize: 14,
                  color: DesignTokens.textDark,
                ),
                decoration: InputDecoration(
                  labelText: 'Güzergah Adı (Örn: İşe Gidiş)',
                  labelStyle: const TextStyle(
                    fontSize: 14,
                    color: DesignTokens.textGrey,
                  ),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: DesignTokens.textGrey),
                  ),
                  focusedBorder: const OutlineInputBorder(
                    borderSide: BorderSide(color: DesignTokens.textDark),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                ref.read(gpsTrackingNotifier.notifier).clearCustomEdsPrompt();
              },
              child: const Text(
                'İPTAL',
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.textGrey,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: DesignTokens.statusViolation,
              ),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;

                final newPoint = EdsPoint(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  startLatitude: prompt.startPoint.latitude,
                  startLongitude: prompt.startPoint.longitude,
                  endLatitude: prompt.endPoint.latitude,
                  endLongitude: prompt.endPoint.longitude,
                  isBidirectional: true,
                  speedLimit: prompt.targetSpeed,
                );
                await EdsStorageService().saveCustomPoint(newPoint);
                await EdsGeofenceService().reloadPoints();
                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Özel EDS Noktası Kaydedildi!')),
                );

                ref.read(gpsTrackingNotifier.notifier).clearCustomEdsPrompt();
              },
              child: const Text(
                'KAYDET',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
