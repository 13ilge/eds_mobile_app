import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:eds_mobile_app/models/driving_score.dart';
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
    distanceKm: 12.0,
    averageSpeed: 80,
    targetSpeed: 82,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  test('loads empty list when nothing stored', () async {
    final service = DrivingScoreService();
    expect(await service.loadScores(), isEmpty);
  });

  test('saved score is persisted as the most recent (first) entry', () async {
    final service = DrivingScoreService();
    await service.saveScore(makeScore('a', score: 70));
    await service.saveScore(makeScore('b', score: 90));

    final scores = await service.loadScores();
    expect(scores, hasLength(2));
    expect(scores.first.id, 'b');
    expect(scores.last.id, 'a');
  });

  test('caps stored scores at 50, dropping the oldest', () async {
    final service = DrivingScoreService();
    for (var i = 0; i < 55; i++) {
      await service.saveScore(makeScore('s$i'));
    }

    final scores = await service.loadScores();
    expect(scores, hasLength(50));
    expect(scores.first.id, 's54');
    expect(scores.any((s) => s.id == 's0'), isFalse);
  });

  test('invalid stored JSON degrades to empty list', () async {
    final service = DrivingScoreService();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('driving_scores_guest', 'not-json{{');

    expect(await service.loadScores(), isEmpty);
  });
}
