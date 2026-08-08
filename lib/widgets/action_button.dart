import 'package:flutter/material.dart';
import '../theme/design_tokens.dart';

class ActionButton extends StatelessWidget {
  final bool isActive;
  final SpeedStatus status;
  final VoidCallback onTap;

  const ActionButton({
    super.key,
    required this.isActive,
    required this.status,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final Color backgroundColor = isActive 
        ? DesignTokens.getStatusColor(status) 
        : DesignTokens.textDark;
        
    final Color textColor = DesignTokens.cardSurface;

    final String buttonText = isActive ? 'BİTİR / SIFIRLA' : 'BAÅLAT';
    final height = MediaQuery.of(context).size.height * 0.13;
    final clampedHeight = height < 64.0 ? 64.0 : height;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Ink(
          decoration: BoxDecoration(
            color: backgroundColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: backgroundColor.withValues(alpha: 0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Container(
            width: double.infinity,
            height: clampedHeight,
            alignment: Alignment.center,
            child: Text(
              buttonText,
              style: DesignTokens.labelLarge.copyWith(
                color: textColor,
                letterSpacing: 1.5,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
