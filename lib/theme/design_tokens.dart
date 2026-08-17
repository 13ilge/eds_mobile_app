import 'package:flutter/material.dart';

enum SpeedStatus { safe, warning, violation }

class DesignTokens {
  static const Color background = Color(0xFFF4F6F8);
  static const Color cardSurface = Color(0xFFFFFFFF);
  static const Color textDark = Color(0xFF1A1D1F);
  static const Color textGrey = Color(0xFF6B7280);
  static const Color primaryBlue = Color(0xFF3B82F6);
  
  static const Color textPrimary = textDark;
  static const Color textSecondary = textGrey;
  static const Color surface = background;
  static const Color cardBackground = cardSurface;
  static const Color cardBorder = Color(0xFFE5E7EB);
  
  static const Color statusSafe = Color(0xFF10B981);
  static const Color statusWarning = Color(0xFFF59E0B);
  static const Color statusViolation = Color(0xFFEF4444);

  // Sürüş Skor Renkleri
  static const Color scoreExcellent = Color(0xFF10B981); // 90-100
  static const Color scoreGood     = Color(0xFF3B82F6); // 70-89
  static const Color scoreFair     = Color(0xFFF59E0B); // 50-69
  static const Color scorePoor     = Color(0xFFEF4444); // 0-49

  /// Skor değerine göre uygun rengi döndürür.
  static Color getScoreColor(int score) {
    if (score >= 90) return scoreExcellent;
    if (score >= 70) return scoreGood;
    if (score >= 50) return scoreFair;
    return scorePoor;
  }

  static Color getStatusColor(SpeedStatus status) {
    switch (status) {
      case SpeedStatus.safe:
        return statusSafe;
      case SpeedStatus.warning:
        return statusWarning;
      case SpeedStatus.violation:
        return statusViolation;
    }
  }

  static const TextStyle labelSmall = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
    color: textDark,
  );

  static const TextStyle labelLarge = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static const TextStyle metricLarge = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w600,
    color: textDark,
  );

  static const TextStyle metricMassive = TextStyle(
    fontSize: 72,
    fontWeight: FontWeight.bold,
    color: textDark,
  );

  static final BoxDecoration cardDecoration = BoxDecoration(
    color: cardSurface,
    borderRadius: BorderRadius.circular(16),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.04), // Fixed withOpacity deprecation
        blurRadius: 8,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
