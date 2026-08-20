import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../models/driving_score.dart';
import '../services/driving_score_service.dart';
import 'subscription_provider.dart';

import '../services/badge_service.dart';
import 'auth_provider.dart';

class DrivingScoreNotifier extends StateNotifier<List<DrivingScore>> {
  final Ref ref;
  DrivingScoreNotifier(this.ref) : super([]) {
    _loadScores();
  }

  Future<void> _loadScores() async {
    state = await DrivingScoreService().loadScores();
  }

  Future<void> addScore(DrivingScore score) async {
    await DrivingScoreService().saveScore(score);
    await _loadScores();
    
    // Phase 3: Gamification Sync
    final avgScore = DrivingScoreService().getAverageScore(state);
    final earnedBadges = BadgeService.evaluateBadges(state);
    final totalSessions = state.length;
    
    try {
      await ref.read(authServiceProvider).updateGamification(avgScore, totalSessions, earnedBadges);
    } catch (e) {
      debugPrint('Failed to sync gamification: $e');
    }
  }
}

final drivingScoreListProvider =
    StateNotifierProvider<DrivingScoreNotifier, List<DrivingScore>>((ref) {
  return DrivingScoreNotifier(ref);
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
