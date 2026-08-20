import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

enum BadgeType {
  compliance,
  accuracy,
  smoothness,
  master
}

enum BadgeTier {
  none,
  bronze,
  silver,
  gold
}

class BadgeModel {
  final String id; // e.g. "compliance"
  final String name;
  final BadgeType type;
  final BadgeTier tier;

  const BadgeModel({
    required this.id,
    required this.name,
    required this.type,
    required this.tier,
  });

  Color get tierColor {
    switch (tier) {
      case BadgeTier.bronze:
        return const Color(0xFFCD7F32); // Bronze
      case BadgeTier.silver:
        return const Color(0xFFC0C0C0); // Silver
      case BadgeTier.gold:
        return const Color(0xFFFFD700); // Gold
      default:
        return DesignTokens.textGrey;
    }
  }

  IconData get icon {
    switch (type) {
      case BadgeType.compliance:
        return Icons.verified_user_rounded; // Shield
      case BadgeType.accuracy:
        return Icons.radar_rounded; // Radar/Speedometer
      case BadgeType.smoothness:
        return Icons.eco_rounded; // Eco/Leaf
      case BadgeType.master:
        return Icons.workspace_premium_rounded; // Star/Premium
    }
  }

  static String getTierName(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze: return 'Bronz';
      case BadgeTier.silver: return 'Gümüş';
      case BadgeTier.gold: return 'Altın';
      default: return '';
    }
  }

  static String getBadgeName(BadgeType type) {
    switch (type) {
      case BadgeType.compliance: return 'Uyum Rozeti';
      case BadgeType.accuracy: return 'Doğruluk Rozeti';
      case BadgeType.smoothness: return 'Pürüzsüzlük Rozeti';
      case BadgeType.master: return 'Mükemmel Sürücü';
    }
  }

  static BadgeTier getTierFromString(String tierStr) {
    switch (tierStr) {
      case 'bronze': return BadgeTier.bronze;
      case 'silver': return BadgeTier.silver;
      case 'gold': return BadgeTier.gold;
      default: return BadgeTier.none;
    }
  }

  static String getStringFromTier(BadgeTier tier) {
    switch (tier) {
      case BadgeTier.bronze: return 'bronze';
      case BadgeTier.silver: return 'silver';
      case BadgeTier.gold: return 'gold';
      default: return 'none';
    }
  }
}
