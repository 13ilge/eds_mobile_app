import 'dart:convert';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/driving_score.dart';

class DrivingScoreService {
  static final DrivingScoreService _instance = DrivingScoreService._internal();
  factory DrivingScoreService() => _instance;
  DrivingScoreService._internal();

  SharedPreferences? _prefs;

  static const int _maxStoredScores = 50;
  static const int defaultExpectedMaxEvents = 10;

  String get _storageKey {
    final uid = FirebaseAuth.instance.currentUser?.uid ?? 'guest';
    return 'driving_scores_$uid';
  }

  Future<SharedPreferences> get _preferences async {
    return _prefs ??= await SharedPreferences.getInstance();
  }

  static int calculateScore({
    required int totalSessionSeconds,
    required int violationSeconds,
    required int averageSpeed,
    required int targetSpeed,
    required int harshEventCount,
    int expectedMaxEvents = defaultExpectedMaxEvents,
  }) {
    if (totalSessionSeconds <= 0) return 0;
    if (targetSpeed <= 0) return 0;

    // Bileşen 1: Kurallara uyum oranı (w=0.50)
    final double complianceRatio =
        (1.0 - (violationSeconds / totalSessionSeconds)).clamp(0.0, 1.0);

    // Bileşen 2: Hız doğruluğu (w=0.30)
    final double speedAccuracy = max(
      0.0,
      1.0 - ((averageSpeed - targetSpeed).abs() / targetSpeed),
    );

    // Bileşen 3: Sürüş pürüzsüzlüğü (w=0.20)
    final double smoothness = expectedMaxEvents > 0
        ? max(0.0, 1.0 - (harshEventCount / expectedMaxEvents))
        : 1.0;

    final double rawScore =
        (0.50 * complianceRatio) + (0.30 * speedAccuracy) + (0.20 * smoothness);

    return (rawScore * 100).round().clamp(0, 100);
  }

  DrivingScore? getLastScore(List<DrivingScore> scores) {
    if (scores.isEmpty) return null;
    return scores.first;
  }

  double getAverageScore(List<DrivingScore> scores) {
    if (scores.isEmpty) return 0.0;
    final total = scores.fold<int>(0, (sum, s) => sum + s.score);
    return total / scores.length;
  }

  // ---- Persistence ----

  Future<void> saveScore(DrivingScore score) async {
    try {
      final scores = await loadScores();
      scores.insert(0, score);

      final trimmed = scores.length > _maxStoredScores
          ? scores.sublist(0, _maxStoredScores)
          : scores;

      await _persistScores(trimmed);
    } catch (e) {
      debugPrint('DrivingScoreService saveScore failed: $e');
    }
  }

  Future<List<DrivingScore>> loadScores() async {
    try {
      final prefs = await _preferences;
      final String? jsonString = prefs.getString(_storageKey);

      if (jsonString == null) return [];

      final List<dynamic> jsonList = jsonDecode(jsonString);
      return jsonList.map((json) => DrivingScore.fromJson(json)).toList();
    } catch (e) {
      debugPrint('DrivingScoreService loadScores failed: $e');
      return [];
    }
  }

  Future<void> _persistScores(List<DrivingScore> scores) async {
    final prefs = await _preferences;
    final String jsonString = jsonEncode(
      scores.map((s) => s.toJson()).toList(),
    );
    await prefs.setString(_storageKey, jsonString);
  }
}
