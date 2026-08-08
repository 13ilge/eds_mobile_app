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
