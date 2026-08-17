import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driving_score.dart';
import '../services/driving_score_service.dart';
import 'subscription_provider.dart';

class DrivingScoreNotifier extends StateNotifier<List<DrivingScore>> {
  DrivingScoreNotifier() : super([]) {
    _loadScores();
  }

  Future<void> _loadScores() async {
    state = await DrivingScoreService().loadScores();
  }

  Future<void> addScore(DrivingScore score) async {
    await DrivingScoreService().saveScore(score);
    await _loadScores();
  }
}

final drivingScoreListProvider =
    StateNotifierProvider<DrivingScoreNotifier, List<DrivingScore>>((ref) {
  return DrivingScoreNotifier();
});

final lastScoreProvider = Provider<DrivingScore?>((ref) {
  final scores = ref.watch(drivingScoreListProvider);
  return DrivingScoreService().getLastScore(scores);
});

final averageScoreProvider = Provider<double>((ref) {
  final scores = ref.watch(drivingScoreListProvider);
  return DrivingScoreService().getAverageScore(scores);
});

/// Pro gate: Bileşen bazlı detaylı skor analizi sadece Pro kullanıcılara açık.
/// Widget'lar bu provider'ı ref.watch ile tüketerek detay gösterimini kontrol eder.
final detailedScoreAnalysisProvider = Provider<bool>((ref) {
  return ref.watch(isProProvider);
});
