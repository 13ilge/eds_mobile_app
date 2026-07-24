/// EDUCATIONAL NOTE: Views Layer
/// The 'views' or 'screens' directory contains the top-level UI files.
/// A View acts as a container that brings together various Widgets and handles the screen's state.
/// It orchestrates the layout but delegates detailed rendering to smaller modular widgets.

import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'dart:async';
import '../theme/design_tokens.dart';
import '../widgets/average_speed_card.dart';
import '../widgets/metric_card.dart';
import '../widgets/action_button.dart';
import '../services/location_service.dart';
import '../services/eds_geofence_service.dart';
import '../services/eds_storage_service.dart';
import '../services/audio_service.dart';
import '../models/speed_data.dart';
import '../models/eds_point.dart';
import 'saved_eds_view.dart';

class DashboardView extends StatefulWidget {
  const DashboardView({super.key});

  @override
  State<DashboardView> createState() => _DashboardViewState();
}

class _DashboardViewState extends State<DashboardView> with WidgetsBindingObserver {
  final LocationService _locationService = LocationService();
  StreamSubscription<SpeedData>? _speedSubscription;
  
  // Permission State
  bool _hasPermission = false;
  static const String _permissionMessage = "Konum İzni Gerekli\n(İzin vermek için buraya dokunun)";

  // UI / Metric State
  SpeedStatus _currentStatus = SpeedStatus.safe;
  int _targetSpeed = 82;
  double _totalDistance = 10.0; // Mock total route distance
  bool _isActive = false; // By default, wait for user to hit BAŞLAT

  // Tracking State
  int _currentLiveSpeed = 0;
  int _averageSpeed = 0;
  double _currentDistanceMeters = 0.0;
  DateTime? _trackingStartTime;
  SpeedData? _lastSpeedData;
  
  // Geofence State
  late final EdsGeofenceService _geofenceService;
  EdsPoint? _activeEdsPoint;
  SpeedData? _manualTrackingStartPoint;

  // Audio State
  double _lastAnnouncedDistanceKm = 0.0;

  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  Timer? _uiTimer;

  @override
  void initState() {
    super.initState();
    _geofenceService = EdsGeofenceService();
    WidgetsBinding.instance.addObserver(this);
    _initializeLocation();
  }

  @override
  void dispose() {
    _uiTimer?.cancel();
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
    // F14 fix: Cancel any existing subscription before creating a new one
    _speedSubscription?.cancel();

    _speedSubscription = _locationService.getLiveSpeedStream().listen((SpeedData data) {
      if (!mounted) return;

      // --- All computation OUTSIDE setState ---
      final int newLiveSpeed = data.currentSpeed < 1 ? 0 : data.currentSpeed.round();

      // Check for automatic start (only when not active)
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
          // Calculate distance between last point and current point
          final double distanceDelta = Geolocator.distanceBetween(
            _lastSpeedData!.latitude, _lastSpeedData!.longitude,
            data.latitude, data.longitude,
          );
          
          // Accumulate distance
          newDistance += distanceDelta;
          
          // Calculate elapsed time
          final int elapsedSeconds = data.timestamp.difference(_trackingStartTime!).inSeconds;
          
          if (elapsedSeconds > 0) {
            // True Average Speed Formula: Total Distance / Total Time
            final double distanceKm = newDistance / 1000.0;
            final double hours = elapsedSeconds / 3600.0;
            newAverageSpeed = (distanceKm / hours).round();
          }
        }
        
        _lastSpeedData = data;

        // Status Check
        final SpeedStatus prevStatus = _currentStatus;

        if (newAverageSpeed > _targetSpeed + 5) {
           newStatus = SpeedStatus.violation;
        } else if (newAverageSpeed > _targetSpeed) {
           newStatus = SpeedStatus.warning;
        } else {
           newStatus = SpeedStatus.safe;
        }

        // --- Audio calls OUTSIDE setState with error handling (F4 fix) ---
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

        // Check for automatic stop
        bool didAutoStop = false;
        if (_activeEdsPoint != null) {
          if (_geofenceService.checkAutomaticStop(data, _activeEdsPoint!, newDistance)) {
            didAutoStop = true;
          }
        }

        // Handle auto-stop (snackbar shown after setState)
        if (didAutoStop) {
          _isActive = false;
          _currentDistanceMeters = newDistance;
          _currentStatus = newStatus;
          _averageSpeed = newAverageSpeed;
          _currentLiveSpeed = newLiveSpeed;
          _resetTrackingState();

          setState(() {});

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('EDS Bölgesinden Çıkıldı. Takip Sonlandırıldı.')),
            );
          }
          return;
        }

      }

      // --- Only rebuild if display values actually changed ---
      final bool needsRebuild =
          newLiveSpeed != _currentLiveSpeed ||
          newAverageSpeed != _averageSpeed ||
          newStatus != _currentStatus ||
          didAutoStart;

      // Always update internal state
      _currentLiveSpeed = newLiveSpeed;
      _averageSpeed = newAverageSpeed;
      _currentDistanceMeters = newDistance;
      _currentStatus = newStatus;

      if (needsRebuild) {
        setState(() {});
      }

      // Show auto-start snackbar after state update
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
  }

  Future<void> _handleHeroCardTap() async {
    if (!_hasPermission) {
      await _initializeLocation();
    }
  }



  void _toggleTracking() {
    if (_isActive) {
      // Stopping
      final endPoint = _lastSpeedData;
      final startPoint = _manualTrackingStartPoint;
      final distance = _currentDistanceMeters;
      
      setState(() {
        _isActive = false;
        _currentStatus = SpeedStatus.safe;
      });

      _uiTimer?.cancel();

      // Show dialog if manually started and distance > 500m
      if (_activeEdsPoint == null && startPoint != null && endPoint != null && distance > 500) {
        _promptSaveCustomEds(startPoint, endPoint, distance);
      } else {
        _resetTrackingState();
      }
    } else {
      // Starting
      setState(() {
        _isActive = true;
        _currentStatus = SpeedStatus.safe;
        _resetTrackingState();
      });
      
      _uiTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
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
            ],
          ),
        ),
      ),
      body: SafeArea(
        child: _buildDashboardContent(),
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

    // Dynamic Bottom Right Card Logic
    String brLabel = 'MAX HEDEF HIZ';
    String brValue = _isActive ? _targetSpeed.toString() : '0';
    String brUnit = 'km/s';

    if (_isActive) {
      if (_activeEdsPoint != null) {
        // Known Route
        final double limit = _activeEdsPoint!.speedLimit.toDouble();
        final double minTimeHours = _totalDistance / limit;
        
        double elapsedHours = 0;
        if (_trackingStartTime != null) {
          elapsedHours = DateTime.now().difference(_trackingStartTime!).inSeconds / 3600.0;
        }

        final double remainingDistance = _totalDistance - currentDistanceKm;
        final double remainingTime = minTimeHours - elapsedHours;

        if (remainingDistance <= 0 || remainingTime <= 0) {
          brLabel = 'GÜVENLİ HIZ';
          brValue = limit.toInt().toString();
        } else {
          final double safeSpeed = remainingDistance / remainingTime;
          brLabel = 'KALAN GÜVENLİ HIZ';
          brValue = safeSpeed > 130 ? '130+' : safeSpeed.toInt().toString();
        }
      } else {
        // Unknown Route (Manual)
        brLabel = 'SÜRÜŞ SÜRESİ';
        brUnit = '';
        if (_trackingStartTime != null) {
          final duration = DateTime.now().difference(_trackingStartTime!);
          final minutes = duration.inMinutes.toString().padLeft(2, '0');
          final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
          brValue = '$minutes:$seconds';
        } else {
          brValue = '00:00';
        }
      }
    }


    return SingleChildScrollView(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Block 1: AverageSpeedCard 
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
                  child: MetricCard(
                    label: brLabel,
                    valueText: brValue,
                    unit: brUnit,
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
