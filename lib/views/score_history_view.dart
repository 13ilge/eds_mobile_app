import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../models/driving_score.dart';
import '../providers/driving_score_provider.dart';
import '../theme/design_tokens.dart';
import 'paywall_view.dart';

class ScoreHistoryView extends ConsumerWidget {
  const ScoreHistoryView({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scores = ref.watch(drivingScoreListProvider);
    final isPro = ref.watch(detailedScoreAnalysisProvider);
    final averageScore = ref.watch(averageScoreProvider);
    return Scaffold(
      backgroundColor: DesignTokens.surface,
      appBar: AppBar(
        title: const Text(
          'Sürüş Geçmişim',
          style: TextStyle(
            color: DesignTokens.textDark,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: DesignTokens.surface,
        elevation: 0,
        iconTheme: const IconThemeData(color: DesignTokens.textDark),
      ),
      body: scores.isEmpty
          ? _buildEmptyState()
          : _buildContent(context, scores, averageScore, isPro),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_rounded,
              size: 80,
              color: DesignTokens.textGrey.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 24),
            const Text(
              'Henüz Sürüş Kaydınız Yok',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: DesignTokens.textDark,
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Sürüş yaptıkça performans geçmişinizi ve gelişiminizi buradan takip edebilirsiniz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16, color: DesignTokens.textGrey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    List<DrivingScore> scores,
    double averageScore,
    bool isPro,
  ) {
    // Son 10 sürüşü grafikte göstermek için alıp ters çeviriyoruz (kronolojik)
    final chartScores = scores.take(10).toList().reversed.toList();
    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildSummaryCard(averageScore, scores.length),
                const SizedBox(height: 24),
                const Text(
                  'Performans Trendi (Son Seanslar)',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.textDark,
                  ),
                ),
                const SizedBox(height: 16),
                _buildTrendChart(chartScores),
                const SizedBox(height: 32),
                const Text(
                  'Geçmiş Sürüşler',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: DesignTokens.textDark,
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
        SliverList(
          delegate: SliverChildBuilderDelegate((context, index) {
            final score = scores[index];
            return _buildScoreListItem(context, score, isPro);
          }, childCount: scores.length),
        ),
        const SliverPadding(padding: EdgeInsets.only(bottom: 40)),
      ],
    );
  }

  Widget _buildSummaryCard(double average, int totalSessions) {
    final color = DesignTokens.getScoreColor(average.round());
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: DesignTokens.cardDecoration,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Genel Ortalama',
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    average.toStringAsFixed(1),
                    style: TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.bold,
                      color: color,
                      height: 1,
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6.0, left: 4.0),
                    child: Text(
                      '/ 100',
                      style: TextStyle(
                        fontSize: 16,
                        color: DesignTokens.textGrey,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Container(width: 1, height: 60, color: DesignTokens.cardBorder),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              const Text(
                'Toplam Sürüş',
                style: TextStyle(
                  fontSize: 14,
                  color: DesignTokens.textGrey,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                totalSessions.toString(),
                style: const TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: DesignTokens.textDark,
                  height: 1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTrendChart(List<DrivingScore> scores) {
    if (scores.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 220,
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
      decoration: DesignTokens.cardDecoration,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: 100,
          minY: 0,
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              tooltipPadding: const EdgeInsets.all(8),
              tooltipMargin: 8,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  '${rod.toY.round()}',
                  const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < scores.length) {
                    final date = scores[value.toInt()].sessionDate;
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        DateFormat('d MMM').format(date),
                        style: const TextStyle(
                          color: DesignTokens.textGrey,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
            leftTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
          ),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 25,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: DesignTokens.textGrey.withValues(alpha: 0.1),
                strokeWidth: 1,
                dashArray: [5, 5],
              );
            },
          ),
          borderData: FlBorderData(show: false),
          barGroups: scores.asMap().entries.map((entry) {
            final index = entry.key;
            final score = entry.value;
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: score.score.toDouble(),
                  color: DesignTokens.getScoreColor(score.score),
                  width: 16,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(4),
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildScoreListItem(
    BuildContext context,
    DrivingScore score,
    bool isPro,
  ) {
    final color = DesignTokens.getScoreColor(score.score);
    final dateStr = DateFormat('dd MMM yyyy, HH:mm').format(score.sessionDate);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: DesignTokens.cardDecoration,
      clipBehavior: Clip.hardEdge,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Score Circle
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      score.score.toString(),
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                // Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        score.edsPointName ?? 'Serbest Sürüş',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: DesignTokens.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        dateStr,
                        style: const TextStyle(
                          fontSize: 13,
                          color: DesignTokens.textGrey,
                        ),
                      ),
                    ],
                  ),
                ),
                // Meta
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '${score.distanceKm.toStringAsFixed(1)} km',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: DesignTokens.textDark,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${score.durationSeconds ~/ 60}dk ${score.durationSeconds % 60}sn',
                      style: const TextStyle(
                        fontSize: 13,
                        color: DesignTokens.textGrey,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(
            height: 1,
            thickness: 1,
            color: DesignTokens.cardBorder,
          ),

          // Component Breakdown Area
          SizedBox(
            height: 70,
            child: Stack(
              children: [
                // Components
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0),
                  child: Row(
                    children: [
                      Expanded(
                        child: _buildMiniComponent(
                          'Uyum',
                          score.complianceRatio,
                          Icons.check_circle_outline,
                        ),
                      ),
                      Container(width: 1, color: DesignTokens.cardBorder),
                      Expanded(
                        child: _buildMiniComponent(
                          'Doğruluk',
                          score.speedAccuracy,
                          Icons.speed,
                        ),
                      ),
                      Container(width: 1, color: DesignTokens.cardBorder),
                      Expanded(
                        child: _buildMiniComponent(
                          'Pürüzsüzlük',
                          score.smoothness,
                          Icons.waves,
                        ),
                      ),
                    ],
                  ),
                ),

                // Pro Gate Overlay
                if (!isPro)
                  Positioned.fill(
                    child: Container(
                      decoration: BoxDecoration(
                        color: DesignTokens.cardSurface.withValues(alpha: 1.0),
                      ),
                      child: InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const PaywallView(),
                            ),
                          );
                        },
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock,
                              size: 16,
                              color: DesignTokens.primaryBlue,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Detaylı analiz için Pro\'ya geçin',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                                color: DesignTokens.primaryBlue,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniComponent(String label, double ratio, IconData icon) {
    final percentage = (ratio * 100).round();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: DesignTokens.textGrey),
            const SizedBox(width: 4),
            Text(
              '%$percentage',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: DesignTokens.textDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: DesignTokens.textGrey),
        ),
      ],
    );
  }
}
