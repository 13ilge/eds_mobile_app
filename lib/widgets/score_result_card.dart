import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/driving_score.dart';
import '../providers/driving_score_provider.dart';
import '../theme/design_tokens.dart';
import '../views/paywall_view.dart';

class ScoreResultCard extends ConsumerWidget {
  final DrivingScore score;
  final VoidCallback onDismiss;

  const ScoreResultCard({
    super.key,
    required this.score,
    required this.onDismiss,
  });

  String _getScoreMessage(int score) {
    if (score >= 90) return 'Mükemmel bir sürüş yaptınız!';
    if (score >= 70) return 'İyi bir sürüş yaptınız.';
    if (score >= 50) return 'Hızınıza biraz daha dikkat edin.';
    return 'Lütfen hız limitine uyun.';
  }

  String _getScoreEmoji(int score) {
    if (score >= 90) return '🏆';
    if (score >= 70) return '👍';
    if (score >= 50) return '⚠️';
    return '🚨';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    final secs = seconds % 60;
    if (minutes > 0) {
      return '${minutes}dk ${secs}sn';
    }
    return '${secs}sn';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showDetails = ref.watch(detailedScoreAnalysisProvider);
    final scoreColor = DesignTokens.getScoreColor(score.score);

    return Container(
      decoration: const BoxDecoration(
        color: DesignTokens.cardSurface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: DesignTokens.textGrey.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),

          // Başlık
          Text(
            score.edsPointName != null
                ? '${score.edsPointName} Sonucu'
                : 'Sürüş Sonucu',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textDark,
            ),
          ),
          const SizedBox(height: 24),

          // Animasyonlu dairesel skor göstergesi
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: score.score.toDouble()),
            duration: const Duration(milliseconds: 1500),
            curve: Curves.easeOutCubic,
            builder: (context, animatedScore, child) {
              return SizedBox(
                width: 160,
                height: 160,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: animatedScore / 100.0,
                    color: scoreColor,
                    backgroundColor: DesignTokens.background,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          animatedScore.round().toString(),
                          style: TextStyle(
                            fontSize: 48,
                            fontWeight: FontWeight.w800,
                            color: scoreColor,
                            height: 1.0,
                          ),
                        ),
                        const Text(
                          '/ 100',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: DesignTokens.textGrey,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),

          // Skor mesajı
          Text(
            '${_getScoreEmoji(score.score)} ${_getScoreMessage(score.score)}',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: scoreColor,
            ),
          ),
          const SizedBox(height: 24),

          // Bileşen detayları (Pro gate)
          if (showDetails) ...[
            _buildComponentRow(context),
            const SizedBox(height: 20),
          ] else ...[
            _buildProGate(context),
            const SizedBox(height: 20),
          ],

          // Meta bilgiler
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: DesignTokens.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMetaItem('Süre', _formatDuration(score.durationSeconds)),
                Container(
                  width: 1,
                  height: 32,
                  color: DesignTokens.textGrey.withValues(alpha: 0.2),
                ),
                _buildMetaItem(
                  'Mesafe',
                  '${score.distanceKm.toStringAsFixed(1)} km',
                ),
                Container(
                  width: 1,
                  height: 32,
                  color: DesignTokens.textGrey.withValues(alpha: 0.2),
                ),
                _buildMetaItem('Ort. Hız', '${score.averageSpeed} km/h'),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // TAMAM butonu
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onDismiss,
              style: ElevatedButton.styleFrom(
                backgroundColor: scoreColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: const Text(
                'TAMAM',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Pro kullanıcılar için 3 bileşen puanını gösteren satır.
  Widget _buildComponentRow(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _buildComponentItem(
            'Uyum',
            score.complianceRatio,
            Icons.check_circle_outline,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildComponentItem(
            'Doğruluk',
            score.speedAccuracy,
            Icons.speed,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildComponentItem(
            'Pürüzsüzlük',
            score.smoothness,
            Icons.waves,
          ),
        ),
      ],
    );
  }

  Widget _buildComponentItem(String label, double ratio, IconData icon) {
    final percentage = (ratio * 100).round();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: DesignTokens.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: DesignTokens.textGrey),
          const SizedBox(height: 6),
          Text(
            '%$percentage',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: DesignTokens.textDark,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: DesignTokens.textGrey,
            ),
          ),
        ],
      ),
    );
  }

  /// Free kullanıcılar için Pro yükseltme CTA'sı.
  Widget _buildProGate(BuildContext context) {
    return InkWell(
      onTap: () {
        Navigator.pop(context); // Bottom sheet'i kapat
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const PaywallView()),
        );
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: DesignTokens.primaryBlue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: DesignTokens.primaryBlue.withValues(alpha: 0.2),
          ),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.workspace_premium,
              color: DesignTokens.primaryBlue,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Detaylı Sürüş Analizi',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: DesignTokens.primaryBlue,
                    ),
                  ),
                  SizedBox(height: 2),
                  Text(
                    'Bileşen bazlı analiz için Pro\'ya geçin',
                    style: TextStyle(
                      fontSize: 12,
                      color: DesignTokens.textGrey,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              color: DesignTokens.primaryBlue,
              size: 16,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetaItem(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: DesignTokens.textDark,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: DesignTokens.textGrey,
          ),
        ),
      ],
    );
  }
}

/// Dairesel skor halkası çizen CustomPainter.
class _ScoreRingPainter extends CustomPainter {
  final double progress; // 0.0 - 1.0
  final Color color;
  final Color backgroundColor;

  _ScoreRingPainter({
    required this.progress,
    required this.color,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 12;
    const strokeWidth = 10.0;

    // Arka plan halkası
    final bgPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, bgPaint);

    // İlerleme halkası
    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * pi * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2, // 12 o'clock'tan başla
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(_ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
