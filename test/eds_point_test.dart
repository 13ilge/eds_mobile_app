import 'package:flutter_test/flutter_test.dart';

import 'package:eds_mobile_app/models/eds_point.dart';

void main() {
  group('EdsPoint JSON', () {
    test('round-trips to an equivalent point', () {
      final point = EdsPoint(
        id: 'test_1',
        name: 'Test Koridoru',
        startLatitude: 38.3512,
        startLongitude: 38.3845,
        endLatitude: 38.4408,
        endLongitude: 38.8189,
        isBidirectional: true,
        speedLimit: 90,
      );

      final restored = EdsPoint.fromJson(point.toJson());

      expect(restored.id, point.id);
      expect(restored.name, point.name);
      expect(restored.startLatitude, point.startLatitude);
      expect(restored.startLongitude, point.startLongitude);
      expect(restored.endLatitude, point.endLatitude);
      expect(restored.endLongitude, point.endLongitude);
      expect(restored.isBidirectional, point.isBidirectional);
      expect(restored.speedLimit, point.speedLimit);
    });

    test('defaults: isBidirectional true and speedLimit 82', () {
      final point = EdsPoint(
        id: 'a',
        name: 'b',
        startLatitude: 1,
        startLongitude: 2,
        endLatitude: 3,
        endLongitude: 4,
      );

      expect(point.isBidirectional, isTrue);
      expect(point.speedLimit, 82);

      final restored = EdsPoint.fromJson(point.toJson());
      expect(restored.isBidirectional, isTrue);
      expect(restored.speedLimit, 82);
    });

    test('fromJson tolerates missing optional fields', () {
      final point = EdsPoint.fromJson({
        'id': 'a',
        'name': 'b',
        'startLatitude': 1.0,
        'startLongitude': 2.0,
        'endLatitude': 3.0,
        'endLongitude': 4.0,
      });

      expect(point.isBidirectional, isTrue);
      expect(point.speedLimit, 82);
    });

    test('hasSameCoordinates uses epsilon tolerance', () {
      final a = EdsPoint(
        id: 'a',
        name: 'a',
        startLatitude: 38.3512,
        startLongitude: 38.3845,
        endLatitude: 38.4408,
        endLongitude: 38.8189,
      );
      final b = EdsPoint(
        id: 'b',
        name: 'b',
        startLatitude: a.startLatitude + 0.000005,
        startLongitude: a.startLongitude,
        endLatitude: a.endLatitude,
        endLongitude: a.endLongitude + 0.000004,
      );
      final c = EdsPoint(
        id: 'c',
        name: 'c',
        startLatitude: a.startLatitude + 0.0001,
        startLongitude: a.startLongitude,
        endLatitude: a.endLatitude,
        endLongitude: a.endLongitude,
      );

      expect(a.hasSameCoordinates(b), isTrue);
      expect(a.hasSameCoordinates(c), isFalse);
    });
  });

  group('EdsPoint copyWith and equality', () {
    final a = EdsPoint(
      id: 'a',
      name: 'Koridor',
      startLatitude: 38.3512,
      startLongitude: 38.3845,
      endLatitude: 38.4408,
      endLongitude: 38.8189,
      isBidirectional: true,
      speedLimit: 82,
    );

    test('copyWith keeps all fields unless overridden', () {
      final b = a.copyWith(speedLimit: 50);
      expect(b.speedLimit, 50);
      expect(b.id, a.id);
      expect(b.name, a.name);
      expect(b.startLatitude, a.startLatitude);
      expect(b.startLongitude, a.startLongitude);
      expect(b.endLatitude, a.endLatitude);
      expect(b.endLongitude, a.endLongitude);
      expect(b.isBidirectional, a.isBidirectional);
    });

    test('copyWith can change every field', () {
      final b = a.copyWith(
        id: 'b',
        name: 'Yeni',
        startLatitude: 1,
        startLongitude: 2,
        endLatitude: 3,
        endLongitude: 4,
        isBidirectional: false,
      );
      expect(b.id, 'b');
      expect(b.name, 'Yeni');
      expect(b.startLatitude, 1);
      expect(b.startLongitude, 2);
      expect(b.endLatitude, 3);
      expect(b.endLongitude, 4);
      expect(b.isBidirectional, isFalse);
    });

    test('== compares by field values, not identity', () {
      final b = a.copyWith();
      expect(b, isNot(same(a)));
      expect(b, equals(a));
    });

    test('equal points share hashCode; unequal do not crash sets', () {
      expect(a.hashCode, equals(a.copyWith().hashCode));
      final set = {a, a.copyWith()};
      expect(set, hasLength(1));
      expect(set.contains(a.copyWith(speedLimit: 50)), isFalse);
    });
  });
}
