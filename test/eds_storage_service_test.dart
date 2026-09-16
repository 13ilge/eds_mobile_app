import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eds_mobile_app/models/eds_point.dart';
import 'package:eds_mobile_app/models/speed_data.dart';
import 'package:eds_mobile_app/services/eds_geofence_service.dart';
import 'package:eds_mobile_app/services/eds_storage_service.dart';

EdsPoint makePoint(String id) {
  return EdsPoint(
    id: id,
    name: 'Test Koridoru $id',
    startLatitude: 38.3 + 0.001 * id.length,
    startLongitude: 38.3,
    endLatitude: 38.4,
    endLongitude: 38.4,
    speedLimit: 82,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late EdsStorageService storage;

  setUpAll(() {
    storage = EdsStorageService();
  });

  test('empty storage loads empty list', () async {
    final points = await storage.loadCustomPoints();
    expect(points, isEmpty);
  });

  test('save then load returns the custom point', () async {
    final point = makePoint('pt1');
    await storage.saveCustomPoint(point);

    final points = await storage.loadCustomPoints();
    expect(points, hasLength(1));
    expect(points.first.id, 'pt1');
  });

  test('saving with existing id updates instead of duplicating', () async {
    await storage.saveCustomPoint(makePoint('pt1'));
    final updated = EdsPoint(
      id: 'pt1',
      name: 'Güncellenmiş',
      startLatitude: 38.0,
      startLongitude: 38.0,
      endLatitude: 38.1,
      endLongitude: 38.1,
      speedLimit: 50,
    );
    await storage.saveCustomPoint(updated);

    final points = await storage.loadCustomPoints();
    expect(points, hasLength(1));
    expect(points.first.name, 'Güncellenmiş');
    expect(points.first.speedLimit, 50);
  });

  test('delete removes the point', () async {
    await storage.saveCustomPoint(makePoint('pt2'));
    await storage.deleteCustomPoint('pt2');

    final points = await storage.loadCustomPoints();
    expect(points.any((p) => p.id == 'pt2'), isFalse);
  });

  test('loadCustomPoints returns a defensive copy (cache not leaky)', () async {
    await storage.saveCustomPoint(makePoint('pt_copy'));
    final first = await storage.loadCustomPoints();
    first.clear();

    final second = await storage.loadCustomPoints();
    expect(second.any((p) => p.id == 'pt_copy'), isTrue);
  });

  test('reloaded geofence service sees saved custom point', () async {
    // Dedicated, unique location far from other fixtures so no other point's
    // bounding box overlaps the trigger radius.
    final point = EdsPoint(
      id: 'pt_custom',
      name: 'Uzak Koridor',
      startLatitude: 37.90,
      startLongitude: 38.90,
      endLatitude: 37.95,
      endLongitude: 38.95,
      speedLimit: 82,
    );
    await storage.saveCustomPoint(point);

    final geofence = EdsGeofenceService();
    await geofence.reloadPoints();

    final result = geofence.checkAutomaticStart(
      SpeedData(
        currentSpeed: 90,
        timestamp: DateTime.now(),
        latitude: point.startLatitude,
        longitude: point.startLongitude,
        heading: 45.0,
      ),
    );
    expect(result?.id, 'pt_custom');
  });
}
