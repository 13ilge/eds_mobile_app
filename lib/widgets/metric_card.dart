import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class MetricCard extends StatelessWidget {
  final String label;
  final String valueText;
  final String unit;

  const MetricCard({
    super.key,
    required this.label,
    required this.valueText,
    this.unit = 'km/s',
  });

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.of(context).size.height * 0.19;

    return Container(
      height: height,
      decoration: DesignTokens.cardDecoration,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: DesignTokens.labelSmall,
          ),
          const Spacer(),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                valueText,
                style: const TextStyle(
                  fontSize: 44,
                  fontWeight: FontWeight.w600,
                  color: DesignTokens.textDark,
                  letterSpacing: -1.0,
                ),
              ),
              if (unit.isNotEmpty) ...[
                const SizedBox(width: 4),
                Text(
                  unit,
                  style: DesignTokens.labelSmall.copyWith(
                    color: DesignTokens.textDark.withValues(alpha: 0.5),
                    fontWeight: FontWeight.normal,
                  ),
                ),
              ]
            ],
          ),
        ],
      ),
    );
  }
}
