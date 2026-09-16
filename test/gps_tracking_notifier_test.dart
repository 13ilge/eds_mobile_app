import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eds_mobile_app/models/speed_data.dart';
import 'package:eds_mobile_app/providers/gps_tracking_provider.dart';
import 'package:eds_mobile_app/services/eds_data_repository.dart';
import 'package:eds_mobile_app/services/eds_geofence_service.dart';
import 'package:eds_mobile_app/services/location_service.dart';
import 'package:eds_mobile_app/theme/design_tokens.dart';

/// Fake LocationService: always grants permission, exposes a controllable
/// speed stream.
class FakeLocationService extends LocationService {
  final StreamController<SpeedData> controller =
      StreamController<SpeedData>.broadcast();

  @override
  Future<bool> checkAndRequestPermission() async => true;

  @override
  Stream<SpeedData> getLiveSpeedStream() => controller.stream;

  void emit(SpeedData data) => controller.add(data);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late FakeLocationService fake;
  late ProviderContainer container;

  final corridor = EdsDataRepository.malatyaEdsPoints.first;

  setUp(() async {
    // The geofence singleton loads its point list asynchronously; make sure
    // it is ready before any tick enters the notifier.
    await EdsGeofenceService().reloadPoints();
    fake = FakeLocationService();
    container = ProviderContainer(
      overrides: [locationServiceProvider.overrideWithValue(fake)],
    );
  });

  tearDown(() {
    container.dispose();
    fake.controller.close();
  });

  GpsTrackingNotifier notifier() =>
      container.read(gpsTrackingNotifier.notifier);

  TrackingState state() => container.read(gpsTrackingNotifier);

  SpeedData tickAt(
    DateTime ts,
    double lat,
    double lng, {
    double? heading = 45.0,
    double speedKmh = 60,
  }) {
    return SpeedData(
      currentSpeed: speedKmh,
      timestamp: ts,
      latitude: lat,
      longitude: lng,
      heading: heading,
    );
  }

  group('manual session', () {
    test('start sets isActive and resets counters', () async {
      await notifier().requestPermission();
      notifier().toggleTracking();

      await Future<void>.delayed(Duration.zero);

      final st = state();
      expect(st.isActive, isTrue);
      expect(st.currentStatus, SpeedStatus.safe);
      expect(st.currentDistanceMeters, 0.0);
      expect(st.violationSeconds, 0);
      expect(st.harshEventCount, 0);
    });

    test('stop deactivates; short session produces no prompt', () async {
      notifier()
        ..toggleTracking()
        ..toggleTracking();

      await Future<void>.delayed(Duration.zero);

      final st = state();
      expect(st.isActive, isFalse);
      expect(st.customEdsPrompt, isNull);
    });
  });

  group('ticks while active', () {
    test('distance accumulates from consecutive ticks', () async {
      await notifier().requestPermission();
      notifier().toggleTracking();

      fake.emit(
        tickAt(
          DateTime(2026, 1, 1, 10, 0, 0),
          38.0,
          38.0,
          heading: 90.0,
          speedKmh: 80,
        ),
      );
      fake.emit(
        tickAt(
          DateTime(2026, 1, 1, 10, 0, 10),
          38.0,
          38.0009, // ~80 m east
          heading: 90.0,
          speedKmh: 80,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final st = state();
      expect(st.currentDistanceMeters, inInclusiveRange(60, 100));
      expect(st.trackingStartTime, DateTime(2026, 1, 1, 10, 0, 0));
      expect(st.lastSpeedData, isNotNull);
    });

    test('huge tick distance drives average speed to violation', () async {
      await notifier().requestPermission();
      notifier().toggleTracking();

      final t0 = DateTime(2026, 1, 1, 10, 0, 0);
      fake.emit(tickAt(t0, 38.0, 38.0, speedKmh: 80));
      // 60 s later, 20 km east → avg ≈ 1200 km/h → violation.
      fake.emit(
        tickAt(
          t0.add(const Duration(seconds: 60)),
          38.0,
          40.18, // ≈ 20 km at this latitude
          speedKmh: 80,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(state().currentStatus, SpeedStatus.violation);
      await Future<void>.delayed(Duration.zero);

      // One more minute in violation → violation seconds counted.
      fake.emit(
        tickAt(t0.add(const Duration(seconds: 120)), 38.0, 40.18, speedKmh: 80),
      );

      await Future<void>.delayed(Duration.zero);

      final st = state();
      expect(st.currentStatus, SpeedStatus.violation);
      expect(st.violationSeconds, inInclusiveRange(50, 70));
    });

    test('harsh event counted when speed jumps more than 15 km/h', () async {
      await notifier().requestPermission();
      notifier().toggleTracking();

      final t0 = DateTime(2026, 1, 1, 10, 0, 0);
      fake.emit(tickAt(t0, 38.0, 38.0, speedKmh: 50));
      fake.emit(
        tickAt(
          t0.add(const Duration(seconds: 2)),
          38.0,
          38.0,
          speedKmh: 90, // +40 km/h jump
        ),
      );

      await Future<void>.delayed(Duration.zero);

      expect(state().harshEventCount, 1);
    });

    test(
      'null heading ticks do not crash; far ticks never auto-start',
      () async {
        await notifier().requestPermission();
        notifier().toggleTracking();

        fake.emit(
          tickAt(
            DateTime(2026, 1, 1, 10, 0, 0),
            38.0,
            38.0,
            heading: null,
            speedKmh: 80,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        final st = state();
        expect(st.isActive, isTrue); // manual session
        expect(st.activeEdsPoint, isNull); // no geofence match
      },
    );
  });

  group('automatic start/stop (geofence)', () {
    test('auto start fires at corridor start with corridor bearing', () async {
      await notifier().requestPermission();
      final startBearing = Geolocator.bearingBetween(
        corridor.startLatitude,
        corridor.startLongitude,
        corridor.endLatitude,
        corridor.endLongitude,
      );
      final heading = (startBearing + 360) % 360;

      fake.emit(
        tickAt(
          DateTime(2026, 1, 1, 10, 0, 0),
          corridor.startLatitude,
          corridor.startLongitude,
          heading: heading,
          speedKmh: 80,
        ),
      );

      await Future<void>.delayed(Duration.zero);

      final st = state();
      expect(st.isActive, isTrue);
      expect(st.activeEdsPoint?.id, corridor.id);
      expect(st.targetSpeed, corridor.speedLimit);
      expect(st.event, TrackingUiEvent.enteredEds);
    });

    test('null heading cannot trigger auto start', () async {
      await notifier().requestPermission();
      fake.emit(
        tickAt(
          DateTime(2026, 1, 1, 10, 0, 0),
          corridor.startLatitude,
          corridor.startLongitude,
          heading: null,
          speedKmh: 80,
        ),
      );

      expect(state().isActive, isFalse);
      expect(state().event, TrackingUiEvent.none);
    });

    test(
      'auto stop jumps past 500 m near corridor end; session ends',
      () async {
        await notifier().requestPermission();
        final startBearing = Geolocator.bearingBetween(
          corridor.startLatitude,
          corridor.startLongitude,
          corridor.endLatitude,
          corridor.endLongitude,
        );
        final heading = (startBearing + 360) % 360;

        fake.emit(
          tickAt(
            DateTime(2026, 1, 1, 10, 0, 0),
            corridor.startLatitude,
            corridor.startLongitude,
            heading: heading,
            speedKmh: 80,
          ),
        );
        await Future<void>.delayed(Duration.zero);
        expect(state().isActive, isTrue);

        // Jump: start → end in 60 s; distance delta ≈ corridor length ≥ 500 m,
        // position within 100 m of end → auto stop + session end.
        fake.emit(
          tickAt(
            DateTime(2026, 1, 1, 10, 1, 0),
            corridor.endLatitude,
            corridor.endLongitude,
            heading: heading,
            speedKmh: 80,
          ),
        );

        await Future<void>.delayed(Duration.zero);

        final st = state();
        expect(st.isActive, isFalse);
        expect(st.event, TrackingUiEvent.exitedEds);
        // Score was produced (session well over 30 s of wall-clock is not
        // guaranteed in tests; session length uses real now(), min 30 s is
        // satisfied because the twe ticks are 60 s apart from the same clock.
        expect(st.violationSeconds, 0);
        expect(st.currentDistanceMeters, 0.0);
      },
    );
  });
}
