
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../theme/design_tokens.dart';
import '../widgets/average_speed_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/dashboard_timer_metric.dart';
import '../widgets/action_button.dart';
import '../widgets/score_result_card.dart';
import '../services/location_service.dart';
import '../services/eds_geofence_service.dart';
import '../services/eds_storage_service.dart';
import '../services/audio_service.dart';
import '../services/driving_score_service.dart';
import '../models/speed_data.dart';
import '../models/eds_point.dart';
import '../models/driving_score.dart';
import '../providers/subscription_provider.dart';
import '../providers/friends_provider.dart';
import '../providers/sharing_provider.dart';
import '../providers/driving_score_provider.dart';
import 'saved_eds_view.dart';
import 'profile_view.dart';
import 'paywall_view.dart';
import 'friends_view.dart';
import 'inbox_view.dart';
import 'community_view.dart';

class DashboardView extends ConsumerStatefulWidget {
  const DashboardView({super.key});

  @override
  ConsumerState<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends ConsumerState<DashboardView> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  StreamSubscription<SpeedData>? _speedSubscription;
  
  bool _hasPermission = false;
  static const String _permissionMessage = "Konum İzni Gerekli\n(İzin vermek için buraya dokunun)";

  SpeedStatus _currentStatus = SpeedStatus.safe;
  int _targetSpeed = 82;
  double _totalDistance = 10.0; // Mock total route distance
  bool _isActive = false; // By default, wait for user to hit BAŞLAT

  int _currentLiveSpeed = 0;
  int _averageSpeed = 0;
  double _currentDistanceMeters = 0.0;
  DateTime? _trackingStartTime;
  SpeedData? _lastSpeedData;
  
  late final EdsGeofenceService _geofenceService;
  EdsPoint? _activeEdsPoint;
  SpeedData? _manualTrackingStartPoint;

  double _lastAnnouncedDistanceKm = 0.0;

  // --- Sürüş Skor Sayaçları (setState DIŞINDA güncellenir) ---
  int _violationSeconds = 0;
  int _harshEventCount = 0;
  double _previousTickSpeed = 0.0;
  DateTime? _previousTickTime;

  static const double _harshThreshold = 15.0; // km/h — ardışık tick arası fark eşiği
  static const int _minSessionSeconds = 30; // Minimum seans süresi (skor hesaplama için)

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
    _geofenceService = EdsGeofenceService();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _speedSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_hasPermission) {
      _initializeLocation();
    }
  }

  Future<void> _initializeLocation() async {
    try {
      final hasPermission = await _locationService.checkAndRequestPermission();
      if (mounted) {
        setState(() {
          _hasPermission = hasPermission;
        });
        
        if (hasPermission && _speedSubscription == null) {
          _startListeningToGPS();
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hasPermission = false;
        });
      }
    }
  }

  void _startListeningToGPS() {
    _speedSubscription?.cancel();

    _speedSubscription = _locationService.getLiveSpeedStream().listen((SpeedData data) {
      if (!mounted) return;

      final int newLiveSpeed = data.currentSpeed < 1 ? 0 : data.currentSpeed.round();

      bool didAutoStart = false;
      if (!_isActive) {
        final matchedPoint = _geofenceService.checkAutomaticStart(data);
        if (matchedPoint != null) {
          _isActive = true;
          _activeEdsPoint = matchedPoint;
          _targetSpeed = matchedPoint.speedLimit;
          _totalDistance = Geolocator.distanceBetween(
            matchedPoint.startLatitude, matchedPoint.startLongitude,
            matchedPoint.endLatitude, matchedPoint.endLongitude,
          ) / 1000.0;
          didAutoStart = true;
        }
      }

      int newAverageSpeed = _averageSpeed;
      double newDistance = _currentDistanceMeters;
      SpeedStatus newStatus = _currentStatus;

      if (_isActive) {
        if (_manualTrackingStartPoint == null && _activeEdsPoint == null) {
          _manualTrackingStartPoint = data;
        }
        
        _trackingStartTime ??= data.timestamp;

        if (_lastSpeedData != null) {
          final double distanceDelta = Geolocator.distanceBetween(
            _lastSpeedData!.latitude, _lastSpeedData!.longitude,
            data.latitude, data.longitude,
          );
          
          newDistance += distanceDelta;
          
          final int elapsedSeconds = data.timestamp.difference(_trackingStartTime!).inSeconds;
          
          if (elapsedSeconds > 0) {
            final double distanceKm = newDistance / 1000.0;
            final double hours = elapsedSeconds / 3600.0;
            newAverageSpeed = (distanceKm / hours).round();
          }
        }
        
        _lastSpeedData = data;

        // --- Skor sayaç güncellemeleri (setState DIŞINDA) ---
        // Violation süre sayacı
        if (newStatus == SpeedStatus.violation && _previousTickTime != null) {
          final tickDelta = data.timestamp.difference(_previousTickTime!).inSeconds;
          _violationSeconds += tickDelta;
        }

        // Harsh event algılama (ani hızlanma/fren)
        if (_previousTickSpeed > 0 && newLiveSpeed > 0) {
          final speedDelta = (newLiveSpeed - _previousTickSpeed).abs().toDouble();
          if (speedDelta > _harshThreshold) {
            _harshEventCount++;
          }
        }

        _previousTickSpeed = newLiveSpeed.toDouble();
        _previousTickTime = data.timestamp;

        final SpeedStatus prevStatus = _currentStatus;

        if (newAverageSpeed > _targetSpeed + 5) {
           newStatus = SpeedStatus.violation;
        } else if (newAverageSpeed > _targetSpeed) {
           newStatus = SpeedStatus.warning;
        } else {
           newStatus = SpeedStatus.safe;
        }

        if (newStatus == SpeedStatus.violation) {
          AudioService().speakViolation(); // fire-and-forget with internal try/catch
        } else if (prevStatus == SpeedStatus.violation && newStatus == SpeedStatus.safe) {
          AudioService().speakSafe();
        }

        final double distanceKm = newDistance / 1000.0;
        if (distanceKm - _lastAnnouncedDistanceKm >= 5.0) {
           _lastAnnouncedDistanceKm = distanceKm;
           AudioService().speakMilestone(newAverageSpeed, distanceKm);
        }

        bool didAutoStop = false;
        if (_activeEdsPoint != null) {
          if (_geofenceService.checkAutomaticStop(data, _activeEdsPoint!, newDistance)) {
            didAutoStop = true;
          }
        }

        if (didAutoStop) {
          _isActive = false;
          _currentDistanceMeters = newDistance;
          _currentStatus = newStatus;
          _averageSpeed = newAverageSpeed;
          _currentLiveSpeed = newLiveSpeed;

          // Skor hesapla ve göster (resetTrackingState ÖNCE)
          _handleSessionEnd(edsPointName: _activeEdsPoint?.name);

          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('EDS Bölgesinden Çıkıldı. Takip Sonlandırıldı.')),
            );
          }
          return;
        }

      }

      final bool needsRebuild =
          newLiveSpeed != _currentLiveSpeed ||
          newAverageSpeed != _averageSpeed ||
          newStatus != _currentStatus ||
          didAutoStart;

      _currentLiveSpeed = newLiveSpeed;
      _averageSpeed = newAverageSpeed;
      _currentDistanceMeters = newDistance;
      _currentStatus = newStatus;

      if (needsRebuild) {
        setState(() {});
      }

      if (didAutoStart && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('EDS Bölgesine Girildi: ${_activeEdsPoint!.name}')),
        );
      }
    });
  }

  void _resetTrackingState() {
    _trackingStartTime = null;
    _lastSpeedData = null;
    _currentDistanceMeters = 0.0;
    _averageSpeed = 0;
    _activeEdsPoint = null;
    _manualTrackingStartPoint = null;
    _lastAnnouncedDistanceKm = 0.0;
    // Skor sayaçlarını sıfırla
    _violationSeconds = 0;
    _harshEventCount = 0;
    _previousTickSpeed = 0.0;
    _previousTickTime = null;
  }

  /// Seans bittiğinde skor hesaplar, kaydeder, TTS ile okur ve diyalog gösterir.
  /// _resetTrackingState() bu metodun içinde çağrılır.
  void _handleSessionEnd({String? edsPointName}) {
    final totalSeconds = _trackingStartTime != null
        ? DateTime.now().difference(_trackingStartTime!).inSeconds
        : 0;

    // Minimum seans kontrolü — çok kısa seanslar için skor gösterme
    if (totalSeconds < _minSessionSeconds) {
      _resetTrackingState();
      return;
    }

    // Pure function çağrısı — side effect yok
    final scoreValue = DrivingScoreService.calculateScore(
      totalSessionSeconds: totalSeconds,
      violationSeconds: _violationSeconds,
      averageSpeed: _averageSpeed,
      targetSpeed: _targetSpeed,
      harshEventCount: _harshEventCount,
    );

    // Bileşen ratio'larını hesapla
    final complianceRatio = (1.0 - (_violationSeconds / totalSeconds)).clamp(0.0, 1.0);
    final speedAccuracy = (1.0 - ((_averageSpeed - _targetSpeed).abs() / _targetSpeed)).clamp(0.0, 1.0);
    final smoothness = (1.0 - (_harshEventCount / DrivingScoreService.defaultExpectedMaxEvents)).clamp(0.0, 1.0);

    final drivingScore = DrivingScore(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionDate: DateTime.now(),
      score: scoreValue,
      complianceRatio: complianceRatio,
      speedAccuracy: speedAccuracy,
      smoothness: smoothness,
      durationSeconds: totalSeconds,
      distanceKm: _currentDistanceMeters / 1000.0,
      averageSpeed: _averageSpeed,
      targetSpeed: _targetSpeed,
      edsPointName: edsPointName,
    );

    // Riverpod üzerinden kaydet
    ref.read(drivingScoreListProvider.notifier).addScore(drivingScore);

    // TTS ile skoru oku (fire-and-forget, setState DIŞINDA)
    AudioService().speakScore(scoreValue);

    // Skor diyaloğunu göster
    _showScoreDialog(drivingScore);

    // Sayaçları sıfırla
    _resetTrackingState();
  }

  void _showScoreDialog(DrivingScore score) {
    if (!mounted) return;
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
    if (!_hasPermission) {
      await _initializeLocation();
    }
  }



  void _toggleTracking() {
    if (_isActive) {
      final endPoint = _lastSpeedData;
      final startPoint = _manualTrackingStartPoint;
      final distance = _currentDistanceMeters;
      final edsPointName = _activeEdsPoint?.name;
      final wasAutoEds = _activeEdsPoint != null;

      setState(() {
        _isActive = false;
        _currentStatus = SpeedStatus.safe;
      });

      // Skor hesapla ve göster
      _handleSessionEnd(edsPointName: edsPointName);

      if (!wasAutoEds && startPoint != null && endPoint != null && distance > 500) {
        _promptSaveCustomEds(startPoint, endPoint, distance);
      }
    } else {
      setState(() {
        _isActive = true;
        _currentStatus = SpeedStatus.safe;
        _resetTrackingState();
      });
    }
  }

  void _promptSaveCustomEds(SpeedData start, SpeedData end, double distance) {
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
                'Katedilen mesafe: ${(distance / 1000).toStringAsFixed(1)} km.\nBu rotayı özel EDS noktası olarak kaydetmek ister misiniz?',
                style: const TextStyle(fontSize: 14, color: DesignTokens.textDark),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: const TextStyle(fontSize: 14, color: DesignTokens.textDark),
                decoration: InputDecoration(
                  labelText: 'Güzergah Adı (Örn: İşe Gidiş)',
                  labelStyle: const TextStyle(fontSize: 14, color: DesignTokens.textGrey),
                  border: const OutlineInputBorder(),
                  enabledBorder: const OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textGrey)),
                  focusedBorder: const OutlineInputBorder(borderSide: BorderSide(color: DesignTokens.textDark)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                _resetTrackingState();
              },
              child: const Text('İPTAL', style: TextStyle(fontSize: 14, color: DesignTokens.textGrey, fontWeight: FontWeight.bold)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: DesignTokens.statusViolation),
              onPressed: () async {
                if (nameController.text.trim().isEmpty) return;
                
                final newPoint = EdsPoint(
                  id: DateTime.now().millisecondsSinceEpoch.toString(),
                  name: nameController.text.trim(),
                  startLatitude: start.latitude,
                  startLongitude: start.longitude,
                  endLatitude: end.latitude,
                  endLongitude: end.longitude,
                  isBidirectional: true,
                  speedLimit: _targetSpeed,
                );

                await EdsStorageService().saveCustomPoint(newPoint);
                await _geofenceService.reloadPoints();

                if (!context.mounted) return;
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Özel EDS Noktası Kaydedildi!')),
                );
                
                _resetTrackingState();
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
      key: _scaffoldKey,
      drawer: Drawer(
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
                      child: const Icon(Icons.speed, size: 36, color: DesignTokens.textDark),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'EDS Asistanı', 
                      style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: DesignTokens.textDark, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    const Text('Sürüş ve Radar Kontrol', style: DesignTokens.labelSmall),
                  ],
                ),
              ),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 24.0),
                child: Divider(height: 1, color: DesignTokens.background, thickness: 2),
              ),
              const SizedBox(height: 24),
              _buildDrawerItem(
                icon: Icons.home_rounded,
                title: 'Sürüş Ekranı',
                onTap: () => Navigator.pop(context),
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.map_rounded,
                title: 'Özel Noktalarım',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const SavedEdsView()))
                    .then((_) => _geofenceService.reloadPoints());
                },
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.person_rounded,
                title: 'Profilim',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const ProfileView()));
                },
              ),
              const SizedBox(height: 8),
              _buildDrawerItemWithBadge(
                icon: Icons.people_rounded,
                title: 'Arkadaşlarım',
                badgeCount: ref.watch(pendingRequestCountProvider),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const FriendsView()));
                },
              ),
              const SizedBox(height: 8),
              _buildDrawerItemWithBadge(
                icon: Icons.inbox_rounded,
                title: 'Gelen Kutusu',
                badgeCount: ref.watch(incomingShareCountProvider),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const InboxView()));
                },
              ),
              const SizedBox(height: 8),
              _buildDrawerItem(
                icon: Icons.public_rounded,
                title: 'Topluluk',
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (context) => const CommunityView()));
                },
              ),
              const SizedBox(height: 8),
              if (!ref.watch(isProProvider))
                _buildDrawerItem(
                  icon: Icons.workspace_premium,
                  title: 'Pro\'ya Yükselt',
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PaywallView()));
                  },
                ),
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _buildDashboardContent(),
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
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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

  Widget _buildDrawerItem({required IconData icon, required String title, required VoidCallback onTap}) {
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

  Widget _buildDashboardContent() {
    final double currentDistanceKm = _isActive ? (_currentDistanceMeters / 1000.0) : 0.0;

    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AverageSpeedCard(
              speed: _isActive ? _averageSpeed : 0, 
              status: _isActive ? _currentStatus : SpeedStatus.safe,
              currentDistance: currentDistanceKm,
              totalDistance: _isActive ? _totalDistance : 0.0,
              hasPermission: _hasPermission,
              statusMessage: _permissionMessage,
              onTap: _handleHeroCardTap,
              onMenuTap: () => _scaffoldKey.currentState?.openDrawer(),
              onAudioTap: () async {
                await AudioService().cycleMode();
                if (mounted) setState(() {});
              },
              audioMode: AudioService().currentMode,
            ),
            
            const SizedBox(height: 16),
            
            Row(
              children: [
                Expanded(
                  child: MetricCard(
                    label: 'ANLIK HIZ',
                    valueText: _isActive ? _currentLiveSpeed.toString() : '0', 
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: DashboardTimerMetric(
                    isActive: _isActive,
                    activeEdsPoint: _activeEdsPoint,
                    totalDistance: _isActive ? _totalDistance : 0.0,
                    currentDistanceMeters: _currentDistanceMeters,
                    trackingStartTime: _trackingStartTime,
                    targetSpeed: _targetSpeed,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            ActionButton(
              isActive: _isActive,
              status: _currentStatus,
              onTap: _toggleTracking,
            ),
          ],
        ),
      ),
    );
  }
}
