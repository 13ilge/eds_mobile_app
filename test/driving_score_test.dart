import 'package:flutter_test/flutter_test.dart';

import 'package:eds_mobile_app/models/driving_score.dart';
import 'package:eds_mobile_app/services/driving_score_service.dart';

DrivingScore makeScore(int score) {
  return DrivingScore(
    id: 's$score',
    sessionDate: DateTime(2026, 1, 1, 12, 0, 0),
    score: score,
    complianceRatio: 1.0,
    speedAccuracy: 1.0,
    smoothness: 1.0,
    durationSeconds: 600,
    distanceKm: 10.0,
    averageSpeed: 80,
    targetSpeed: 82,
  );
}

void main() {
  group('calculateScore', () {
    test('perfect session scores 100', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      expect(score, 100);
    });

    test('all violations clamp compliance ratio at 0 (not negative)', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 900,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      // complianceRatio clamps to 0 → score = 0.30 (speed) + 0.20 (smooth)
      expect(score, 50);
    });

    test('zero session duration scores 0', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 0,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      expect(score, 0);
    });

    test('zero target speed scores 0 (guards division by zero)', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 0,
        harshEventCount: 0,
      );
      expect(score, 0);
    });

    test('speed overshoot penalizes as much as undershoot', () {
      final overshoot = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 102,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      final undershoot = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 62,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      expect(overshoot, undershoot);
      // 20 km/h over an 82 target: 1 - 20/82 ≈ 0.756 → 0.7*100 + ... ≈ 95
      expect(overshoot, inInclusiveRange(90, 100));
    });

    test('harsh events reduce smoothness linearly', () {
      final clean = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 0,
      );
      final withEvents = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 5,
      );
      expect(clean, 100);
      // 5 events of expected 10 → smoothness 0.5 → 0.20 weight → -10 points
      expect(withEvents, 90);
    });

    test('events beyond expectation clamp smoothness at 0', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 600,
        violationSeconds: 0,
        averageSpeed: 82,
        targetSpeed: 82,
        harshEventCount: 50,
      );
      // smoothness clamps to 0 → 0.8 * 100 = 80
      expect(score, 80);
    });

    test('weights always sum within [0, 100]', () {
      final score = DrivingScoreService.calculateScore(
        totalSessionSeconds: 100,
        violationSeconds: 60,
        averageSpeed: 40,
        targetSpeed: 82,
        harshEventCount: 3,
      );
      expect(score, inInclusiveRange(0, 100));
    });
  });

  group('score aggregation', () {
    late DrivingScoreService service;

    setUp(() {
      service = DrivingScoreService();
    });

    test('getLastScore returns null for empty list', () {
      expect(service.getLastScore([]), isNull);
    });

    test('getLastScore returns first element', () {
      final scores = [makeScore(90), makeScore(70)];
      expect(service.getLastScore(scores)?.id, 's90');
    });

    test('getAverageScore handles empty and mixed lists', () {
      expect(service.getAverageScore([]), 0.0);
      expect(service.getAverageScore([makeScore(80), makeScore(60)]), 70.0);
    });
  });

  group('DrivingScore JSON', () {
    test('round-trips to an equivalent record', () {
      final original = DrivingScore(
        id: 'abc',
        sessionDate: DateTime(2026, 3, 14, 9, 30, 0),
        score: 93,
        complianceRatio: 0.95,
        speedAccuracy: 0.9,
        smoothness: 0.8,
        durationSeconds: 1234,
        distanceKm: 42.5,
        averageSpeed: 78,
        targetSpeed: 82,
        edsPointName: 'Malatya - Elazığ Karayolu',
      );

      final restored = DrivingScore.fromJson(original.toJson());

      expect(restored.id, 'abc');
      expect(restored.sessionDate, original.sessionDate);
      expect(restored.score, 93);
      expect(restored.complianceRatio, 0.95);
      expect(restored.speedAccuracy, 0.9);
      expect(restored.smoothness, 0.8);
      expect(restored.durationSeconds, 1234);
      expect(restored.distanceKm, 42.5);
      expect(restored.averageSpeed, 78);
      expect(restored.targetSpeed, 82);
      expect(restored.edsPointName, 'Malatya - Elazığ Karayolu');
    });

    test('edsPointName may be null', () {
      final original = DrivingScore(
        id: 'x',
        sessionDate: DateTime(2026),
        score: 50,
        complianceRatio: 0.5,
        speedAccuracy: 0.5,
        smoothness: 0.5,
        durationSeconds: 100,
        distanceKm: 1.0,
        averageSpeed: 70,
        targetSpeed: 82,
      );

      final restored = DrivingScore.fromJson(original.toJson());

      expect(restored.edsPointName, isNull);
    });
  });
}
