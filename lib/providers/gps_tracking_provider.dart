import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';

import '../models/driving_score.dart';
import '../models/eds_point.dart';
import '../models/speed_data.dart';
import '../services/audio_service.dart';
import '../services/driving_score_service.dart';
import '../services/eds_geofence_service.dart';
import '../services/location_service.dart';
import '../theme/design_tokens.dart';
import 'driving_score_provider.dart';

final locationServiceProvider = Provider<LocationService>(
  (_) => LocationService(),
);

final edsGeofenceProvider = Provider<EdsGeofenceService>(
  (_) => EdsGeofenceService(),
);

final gpsSpeedStreamProvider = Provider<Stream<SpeedData>>((ref) {
  return ref.watch(locationServiceProvider).getLiveSpeedStream();
});

/// UI event emitted along with state changes; consumed by the view
/// (snackbars). Value-based so identical emissions don't rebuild.
enum TrackingUiEvent { none, enteredEds, exitedEds }

class CustomEdsPrompt {
  final SpeedData startPoint;
  final SpeedData endPoint;
  final double distanceMeters;
  final int targetSpeed;
  final String? edsPointName;

  const CustomEdsPrompt({
    required this.startPoint,
    required this.endPoint,
    required this.distanceMeters,
    required this.targetSpeed,
    this.edsPointName,
  });
}

/// Immutable snapshot of all tracking state previously scattered across
/// ~15 private fields in `_DashboardViewState`.
class TrackingState {
  final bool hasPermission;

  // Corridor/activation
  final bool isActive;
  final EdsPoint? activeEdsPoint;
  final int targetSpeed;
  final double totalDistanceKm;

  // Live telemetry
  final int currentLiveSpeed;
  final int averageSpeed;
  final double currentDistanceMeters;
  final SpeedStatus currentStatus;

  // Session bookkeeping (scoring)
  final DateTime? trackingStartTime;
  final SpeedData? lastSpeedData;
  final SpeedData? manualStartPoint;
  final int violationSeconds;
  final int harshEventCount;
  final double previousTickSpeed;
  final DateTime? previousTickTime;
  final double lastAnnouncedDistanceKm;

  // UI side-effect channels
  final DrivingScore? lastSession;
  final TrackingUiEvent event;
  final CustomEdsPrompt? customEdsPrompt;

  AudioMode get audioMode => AudioService().currentMode;

  const TrackingState({
    this.hasPermission = false,
    this.isActive = false,
    this.activeEdsPoint,
    this.targetSpeed = 82,
    this.totalDistanceKm = 10.0,
    this.currentLiveSpeed = 0,
    this.averageSpeed = 0,
    this.currentDistanceMeters = 0.0,
    this.currentStatus = SpeedStatus.safe,
    this.trackingStartTime,
    this.lastSpeedData,
    this.manualStartPoint,
    this.violationSeconds = 0,
    this.harshEventCount = 0,
    this.previousTickSpeed = 0.0,
    this.previousTickTime,
    this.lastAnnouncedDistanceKm = 0.0,
    this.lastSession,
    this.event = TrackingUiEvent.none,
    this.customEdsPrompt,
  });

  TrackingState copyWith({
    bool? hasPermission,
    bool? isActive,
    bool clearActiveEdsPoint = false,
    EdsPoint? activeEdsPoint,
    int? targetSpeed,
    double? totalDistanceKm,
    int? currentLiveSpeed,
    int? averageSpeed,
    double? currentDistanceMeters,
    SpeedStatus? currentStatus,
    bool clearTrackingStartTime = false,
    DateTime? trackingStartTime,
    bool clearLastSpeedData = false,
    SpeedData? lastSpeedData,
    bool clearManualStartPoint = false,
    SpeedData? manualStartPoint,
    int? violationSeconds,
    int? harshEventCount,
    double? previousTickSpeed,
    bool clearPreviousTickTime = false,
    DateTime? previousTickTime,
    double? lastAnnouncedDistanceKm,
    DrivingScore? lastSession,
    TrackingUiEvent? event,
    bool clearCustomEdsPrompt = false,
    CustomEdsPrompt? customEdsPrompt,
  }) {
    return TrackingState(
      hasPermission: hasPermission ?? this.hasPermission,
      isActive: isActive ?? this.isActive,
      activeEdsPoint: clearActiveEdsPoint
          ? null
          : (activeEdsPoint ?? this.activeEdsPoint),
      targetSpeed: targetSpeed ?? this.targetSpeed,
      totalDistanceKm: totalDistanceKm ?? this.totalDistanceKm,
      currentLiveSpeed: currentLiveSpeed ?? this.currentLiveSpeed,
      averageSpeed: averageSpeed ?? this.averageSpeed,
      currentDistanceMeters:
          currentDistanceMeters ?? this.currentDistanceMeters,
      currentStatus: currentStatus ?? this.currentStatus,
      trackingStartTime: clearTrackingStartTime
          ? null
          : (trackingStartTime ?? this.trackingStartTime),
      lastSpeedData: clearLastSpeedData
          ? null
          : (lastSpeedData ?? this.lastSpeedData),
      manualStartPoint: clearManualStartPoint
          ? null
          : (manualStartPoint ?? this.manualStartPoint),
      violationSeconds: violationSeconds ?? this.violationSeconds,
      harshEventCount: harshEventCount ?? this.harshEventCount,
      previousTickSpeed: previousTickSpeed ?? this.previousTickSpeed,
      previousTickTime: clearPreviousTickTime
          ? null
          : (previousTickTime ?? this.previousTickTime),
      lastAnnouncedDistanceKm:
          lastAnnouncedDistanceKm ?? this.lastAnnouncedDistanceKm,
      lastSession: lastSession ?? this.lastSession,
      event: event ?? this.event,
      customEdsPrompt: clearCustomEdsPrompt
          ? null
          : (customEdsPrompt ?? this.customEdsPrompt),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is TrackingState &&
        hasPermission == other.hasPermission &&
        isActive == other.isActive &&
        activeEdsPoint == other.activeEdsPoint &&
        targetSpeed == other.targetSpeed &&
        totalDistanceKm == other.totalDistanceKm &&
        currentLiveSpeed == other.currentLiveSpeed &&
        averageSpeed == other.averageSpeed &&
        currentDistanceMeters == other.currentDistanceMeters &&
        currentStatus == other.currentStatus &&
        trackingStartTime == other.trackingStartTime &&
        lastSpeedData == other.lastSpeedData &&
        manualStartPoint == other.manualStartPoint &&
        violationSeconds == other.violationSeconds &&
        harshEventCount == other.harshEventCount &&
        previousTickSpeed == other.previousTickSpeed &&
        previousTickTime == other.previousTickTime &&
        lastAnnouncedDistanceKm == other.lastAnnouncedDistanceKm &&
        lastSession == other.lastSession &&
        event == other.event &&
        customEdsPrompt == other.customEdsPrompt;
  }

  @override
  int get hashCode => Object.hash(
    hasPermission,
    isActive,
    activeEdsPoint,
    targetSpeed,
    totalDistanceKm,
    currentLiveSpeed,
    averageSpeed,
    currentDistanceMeters,
    currentStatus,
    trackingStartTime,
    lastSpeedData,
    manualStartPoint,
    violationSeconds,
    harshEventCount,
    previousTickSpeed,
    previousTickTime,
    lastAnnouncedDistanceKm,
    lastSession,
    event,
    customEdsPrompt,
  );
}

class GpsTrackingNotifier extends StateNotifier<TrackingState> {
  final Ref ref;

  /// Mirror of the widget's previous state kept for transition checks
  /// (e.g. violation → safe TTS) within a single tick.
  StreamSubscription<SpeedData>? _speedSubscription;

  static const double _harshThresholdKmh = 15.0;
  static const int _minSessionSeconds = 30;

  GpsTrackingNotifier(this.ref) : super(const TrackingState());

  @override
  void dispose() {
    _speedSubscription?.cancel();
    super.dispose();
  }

  /// Requests location permission and, once granted, subscribes to GPS.
  /// Safe to call multiple times (re-resume, permission card tap).
  Future<void> requestPermission() async {
    bool hasPermission;
    try {
      hasPermission = await ref
          .read(locationServiceProvider)
          .checkAndRequestPermission();
    } catch (e) {
      hasPermission = false;
    }
    state = state.copyWith(hasPermission: hasPermission);
    if (hasPermission) {
      _subscribeToGps();
    }
  }

  /// Mirrors `_startListeningToGPS`'s double-subscription guard.
  void _subscribeToGps() {
    if (_speedSubscription != null) return;
    final stream = ref.read(gpsSpeedStreamProvider);
    _speedSubscription = stream.listen(_onGpsTick);
  }

  void cycleAudioMode() {
    final service = AudioService();
    service.cycleMode();
    // Reading again after a synchronous toggle keeps the getter fresh.
    forceRebuild();
  }

  /// No-op state replacement so widgets re-read `audioMode`.
  /// (AudioService is a mutable singleton; its mode is not part of
  /// TrackingState to avoid load-order issues at notifier creation.)
  void forceRebuild() {
    state = state.copyWith();
  }

  void _onGpsTick(SpeedData data) {
    final st = state;
    final int newLiveSpeed = data.currentSpeed < 1
        ? 0
        : data.currentSpeed.round();
    bool didAutoStart = false;
    TrackingState next = st;

    if (!st.isActive) {
      final matchedPoint = ref
          .read(edsGeofenceProvider)
          .checkAutomaticStart(data);
      if (matchedPoint != null) {
        next = next.copyWith(
          isActive: true,
          activeEdsPoint: matchedPoint,
          targetSpeed: matchedPoint.speedLimit,
          totalDistanceKm:
              Geolocator.distanceBetween(
                matchedPoint.startLatitude,
                matchedPoint.startLongitude,
                matchedPoint.endLatitude,
                matchedPoint.endLongitude,
              ) /
              1000.0,
        );
        didAutoStart = true;
      }
    }

    if (next.isActive) {
      if (next.manualStartPoint == null && next.activeEdsPoint == null) {
        next = next.copyWith(
          manualStartPoint: data,
          clearManualStartPoint: false,
        );
      }
      if (next.trackingStartTime == null) {
        next = next.copyWith(trackingStartTime: data.timestamp);
      }

      final SpeedData? lastData = next.lastSpeedData;
      double newDistance = next.currentDistanceMeters;
      int newAverageSpeed = next.averageSpeed;
      SpeedStatus newStatus = next.currentStatus;

      if (lastData != null) {
        final double distanceDelta = Geolocator.distanceBetween(
          lastData.latitude,
          lastData.longitude,
          data.latitude,
          data.longitude,
        );
        newDistance += distanceDelta;

        final int elapsedSeconds = data.timestamp
            .difference(next.trackingStartTime!)
            .inSeconds;
        if (elapsedSeconds > 0) {
          final double distanceKm = newDistance / 1000.0;
          final double hours = elapsedSeconds / 3600.0;
          newAverageSpeed = (distanceKm / hours).round();
        }
      }
      next = next.copyWith(
        lastSpeedData: data,
        currentDistanceMeters: newDistance,
        averageSpeed: newAverageSpeed,
      );

      // Violation duration counter
      if (newStatus == SpeedStatus.violation && next.previousTickTime != null) {
        final tickDelta = data.timestamp
            .difference(next.previousTickTime!)
            .inSeconds;
        next = next.copyWith(
          violationSeconds: next.violationSeconds + tickDelta,
        );
      }
      // Harsh event detection (sudden acceleration/braking)
      if (next.previousTickSpeed > 0 && newLiveSpeed > 0) {
        final speedDelta = (newLiveSpeed - next.previousTickSpeed)
            .abs()
            .toDouble();
        if (speedDelta > _harshThresholdKmh) {
          next = next.copyWith(harshEventCount: next.harshEventCount + 1);
        }
      }
      next = next.copyWith(
        previousTickSpeed: newLiveSpeed.toDouble(),
        previousTickTime: data.timestamp,
      );

      final SpeedStatus prevStatus = next.currentStatus;
      if (newAverageSpeed > next.targetSpeed + 5) {
        newStatus = SpeedStatus.violation;
      } else if (newAverageSpeed > next.targetSpeed) {
        newStatus = SpeedStatus.warning;
      } else {
        newStatus = SpeedStatus.safe;
      }
      if (newStatus == SpeedStatus.violation) {
        AudioService().speakViolation(); // fire-and-forget, internally guarded
      } else if (prevStatus == SpeedStatus.violation &&
          newStatus == SpeedStatus.safe) {
        AudioService().speakSafe();
      }
      next = next.copyWith(currentStatus: newStatus);

      final double distanceKm = newDistance / 1000.0;
      if (distanceKm - next.lastAnnouncedDistanceKm >= 5.0) {
        next = next.copyWith(lastAnnouncedDistanceKm: distanceKm);
        AudioService().speakMilestone(newAverageSpeed, distanceKm);
      }

      bool didAutoStop = false;
      if (next.activeEdsPoint != null &&
          ref
              .read(edsGeofenceProvider)
              .checkAutomaticStop(data, next.activeEdsPoint!, newDistance)) {
        didAutoStop = true;
      }
      if (didAutoStop) {
        // Preserve the values needed for the UI before ending the session.
        final stoppedState = next.copyWith(isActive: false);
        state = stoppedState.copyWith(event: TrackingUiEvent.exitedEds);
        _endSession(edsPointName: next.activeEdsPoint?.name);
        return;
      }
    }

    if (didAutoStart) {
      next = next.copyWith(event: TrackingUiEvent.enteredEds);
    }
    state = next.copyWith(currentLiveSpeed: newLiveSpeed);
  }

  void _resetSessionCounters(TrackingState base) {
    state = base.copyWith(
      clearTrackingStartTime: true,
      clearLastSpeedData: true,
      clearManualStartPoint: true,
      clearActiveEdsPoint: true,
      currentDistanceMeters: 0.0,
      averageSpeed: 0,
      lastAnnouncedDistanceKm: 0.0,
      violationSeconds: 0,
      harshEventCount: 0,
      previousTickSpeed: 0.0,
      clearPreviousTickTime: true,
    );
  }

  void _endSession({String? edsPointName}) {
    final st = state;
    final totalSeconds = st.trackingStartTime != null
        ? DateTime.now().difference(st.trackingStartTime!).inSeconds
        : 0;
    if (totalSeconds < _minSessionSeconds) {
      _resetSessionCounters(st);
      return;
    }
    final scoreValue = DrivingScoreService.calculateScore(
      totalSessionSeconds: totalSeconds,
      violationSeconds: st.violationSeconds,
      averageSpeed: st.averageSpeed,
      targetSpeed: st.targetSpeed,
      harshEventCount: st.harshEventCount,
    );
    final complianceRatio = (1.0 - (st.violationSeconds / totalSeconds)).clamp(
      0.0,
      1.0,
    );
    final speedAccuracy =
        (1.0 - ((st.averageSpeed - st.targetSpeed).abs() / st.targetSpeed))
            .clamp(0.0, 1.0);
    final smoothness =
        (1.0 -
                (st.harshEventCount /
                    DrivingScoreService.defaultExpectedMaxEvents))
            .clamp(0.0, 1.0);
    final drivingScore = DrivingScore(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      sessionDate: DateTime.now(),
      score: scoreValue,
      complianceRatio: complianceRatio,
      speedAccuracy: speedAccuracy,
      smoothness: smoothness,
      durationSeconds: totalSeconds,
      distanceKm: st.currentDistanceMeters / 1000.0,
      averageSpeed: st.averageSpeed,
      targetSpeed: st.targetSpeed,
      edsPointName: edsPointName,
    );
    // Fire-and-forget persistence via Riverpod (same as before).
    ref
        .read(drivingScoreListProvider.notifier)
        .addScore(drivingScore)
        .then((_) {}, onError: (e) {});
    AudioService().speakScore(scoreValue);
    state = st.copyWith(lastSession: drivingScore);
    _resetSessionCounters(state);
  }

  /// Manual start/stop from the action button.
  void toggleTracking() {
    if (state.isActive) {
      final endPoint = state.lastSpeedData;
      final startPoint = state.manualStartPoint;
      final distance = state.currentDistanceMeters;
      final edsPointName = state.activeEdsPoint?.name;
      final wasAutoEds = state.activeEdsPoint != null;

      state = state.copyWith(isActive: false, currentStatus: SpeedStatus.safe);

      // Capture prompt data BEFORE _endSession resets the counters.
      if (!wasAutoEds &&
          startPoint != null &&
          endPoint != null &&
          distance > 500) {
        state = state.copyWith(
          customEdsPrompt: CustomEdsPrompt(
            startPoint: startPoint,
            endPoint: endPoint,
            distanceMeters: distance,
            targetSpeed: state.targetSpeed,
            edsPointName: edsPointName,
          ),
        );
      }
      _endSession(edsPointName: edsPointName);
    } else {
      state = state.copyWith(isActive: true, currentStatus: SpeedStatus.safe);
      _resetSessionCounters(state);
    }
  }

  /// Clears the custom-route prompt after the view's dialog has resolved.
  void clearCustomEdsPrompt() {
    state = state.copyWith(clearCustomEdsPrompt: true);
  }
}

final gpsTrackingNotifier =
    StateNotifierProvider<GpsTrackingNotifier, TrackingState>((ref) {
      return GpsTrackingNotifier(ref);
    });
