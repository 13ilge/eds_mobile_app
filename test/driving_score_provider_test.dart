import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eds_mobile_app/models/driving_score.dart';
import 'package:eds_mobile_app/providers/driving_score_provider.dart';
import 'package:eds_mobile_app/services/driving_score_service.dart';

DrivingScore makeScore(String id, {int score = 80}) {
  return DrivingScore(
    id: id,
    sessionDate: DateTime(2026, 1, 1, 12),
    score: score,
    complianceRatio: 0.95,
    speedAccuracy: 0.9,
    smoothness: 0.9,
    durationSeconds: 600,
    distanceKm: 10.0,
    averageSpeed: 80,
    targetSpeed: 82,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test(
    'lastScoreProvider and averageScoreProvider derive from stored list',
    () async {
      final service = DrivingScoreService();
      await service.saveScore(makeScore('a', score: 60));
      await service.saveScore(makeScore('b', score: 100));

      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Allow the notifier's async initial load to complete.
      DrivingScore? last;
      for (var i = 0; i < 50 && last == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
        last = container.read(lastScoreProvider);
      }
      expect(last?.id, 'b'); // most recent score first

      final average = container.read(averageScoreProvider);
      expect(average, 80.0);
    },
  );

  test('averageScoreProvider is 0.0 with no scores', () {
    final container = ProviderContainer();
    addTearDown(container.dispose);

    expect(container.read(averageScoreProvider), 0.0);
    expect(container.read(lastScoreProvider), isNull);
  });
}
