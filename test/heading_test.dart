import 'package:flutter_test/flutter_test.dart';

import 'package:eds_mobile_app/services/location_service.dart';
import 'package:eds_mobile_app/models/speed_data.dart';

void main() {
  group('LocationService.mapHeading', () {
    test('negative raw value (unavailable) maps to null', () {
      expect(LocationService.mapHeading(-1.0), isNull);
      expect(LocationService.mapHeading(-104.6), isNull);
    });

    test('valid bearings pass through unchanged', () {
      expect(LocationService.mapHeading(0.0), 0.0);
      expect(LocationService.mapHeading(45.0), 45.0);
      expect(LocationService.mapHeading(359.9), 359.9);
    });
  });

  group('SpeedData', () {
    test('heading is optional and defaults to null', () {
      final data = SpeedData(
        currentSpeed: 50,
        timestamp: DateTime(2026),
        latitude: 38.0,
        longitude: 38.0,
      );
      expect(data.heading, isNull);
    });

    test('provided heading is kept', () {
      final data = SpeedData(
        currentSpeed: 50,
        timestamp: DateTime(2026),
        latitude: 38.0,
        longitude: 38.0,
        heading: 270.0,
      );
      expect(data.heading, 270.0);
    });
  });
}
