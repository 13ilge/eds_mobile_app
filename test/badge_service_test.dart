import 'package:flutter_test/flutter_test.dart';

import 'package:eds_mobile_app/models/badge_model.dart';
import 'package:eds_mobile_app/models/driving_score.dart';
import 'package:eds_mobile_app/services/badge_service.dart';

DrivingScore makeScore({
  double compliance = 0.95,
  double accuracy = 0.95,
  double smoothness = 0.95,
  int score = 95,
}) {
  return DrivingScore(
    id: 's',
    sessionDate: DateTime(2026),
    score: score,
    complianceRatio: compliance,
    speedAccuracy: accuracy,
    smoothness: smoothness,
    durationSeconds: 600,
    distanceKm: 10.0,
    averageSpeed: 80,
    targetSpeed: 82,
  );
}

void main() {
  group('BadgeService.evaluateBadges', () {
    test('empty list earns no badges', () {
      expect(BadgeService.evaluateBadges([]), isEmpty);
    });

    test('below bronze threshold earns no badges', () {
      final badges = BadgeService.evaluateBadges(List.filled(4, makeScore()));
      expect(badges, isEmpty);
    });

    test('bronze tier at 5 qualified sessions', () {
      final badges = BadgeService.evaluateBadges(List.filled(5, makeScore()));
      expect(badges.values, everyElement('bronze'));
      expect(
        badges.keys,
        containsAll([
          BadgeType.compliance.name,
          BadgeType.accuracy.name,
          BadgeType.smoothness.name,
          BadgeType.master.name,
        ]),
      );
    });

    test('silver tier at 15 qualified sessions', () {
      final badges = BadgeService.evaluateBadges(List.filled(15, makeScore()));
      expect(badges.values, everyElement('silver'));
    });

    test('gold tier at 30 qualified sessions', () {
      final badges = BadgeService.evaluateBadges(List.filled(30, makeScore()));
      expect(badges.values, everyElement('gold'));
    });

    test('tiers are independent per component', () {
      // 6 compliant sessions (smoothness low) + 2 smooth sessions (compliance low).
      final scores = [
        ...List.filled(6, makeScore(smoothness: 0.3)),
        ...List.filled(2, makeScore(compliance: 0.3)),
      ];
      final badges = BadgeService.evaluateBadges(scores);
      expect(badges[BadgeType.compliance.name], 'bronze');
      expect(badges.containsKey(BadgeType.smoothness.name), isFalse);
    });

    test('score below 90 never counts toward master tier', () {
      final badges = BadgeService.evaluateBadges(
        List.filled(5, makeScore(score: 89)),
      );
      expect(badges.containsKey(BadgeType.master.name), isFalse);
      // Other components (all >= 0.90) should still qualify for bronze.
      expect(badges[BadgeType.compliance.name], 'bronze');
    });
  });
}
