import '../models/driving_score.dart';
import '../models/badge_model.dart';

class BadgeService {
  static const int bronzeThreshold = 5;
  static const int silverThreshold = 15;
  static const int goldThreshold = 30;

  static Map<String, String> evaluateBadges(List<DrivingScore> recentScores) {
    int complianceCount = recentScores.where((s) => s.complianceRatio >= 0.90).length;
    int accuracyCount = recentScores.where((s) => s.speedAccuracy >= 0.90).length;
    int smoothnessCount = recentScores.where((s) => s.smoothness >= 0.90).length;
    int masterCount = recentScores.where((s) => s.score >= 90).length;

    final Map<String, String> badges = {};

    _assignTier(badges, BadgeType.compliance.name, complianceCount);
    _assignTier(badges, BadgeType.accuracy.name, accuracyCount);
    _assignTier(badges, BadgeType.smoothness.name, smoothnessCount);
    _assignTier(badges, BadgeType.master.name, masterCount);

    return badges;
  }

  static void _assignTier(Map<String, String> badges, String badgeId, int count) {
    if (count >= goldThreshold) {
      badges[badgeId] = 'gold';
    } else if (count >= silverThreshold) {
      badges[badgeId] = 'silver';
    } else if (count >= bronzeThreshold) {
      badges[badgeId] = 'bronze';
    }
  }
}
