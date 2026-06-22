import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../theme/colors.dart';

/// Compact week-of-bookings bar chart used in the barber stats screen.
/// Pass 7 day-of-week counts ordered Mon → Sun.
class WeeklyBookingsBarChart extends StatelessWidget {
  const WeeklyBookingsBarChart({
    super.key,
    required this.counts,
    this.height = 180,
    this.dayLabels,
  });
  final List<int> counts;
  final double height;

  /// 7 weekday abbreviations Mon→Sun. Pass localized labels from the caller;
  /// falls back to Uzbek if null so the widget stays usable standalone.
  final List<String>? dayLabels;

  static const _daysFallback = ['Du', 'Se', 'Ch', 'Pa', 'Ju', 'Sh', 'Ya'];

  @override
  Widget build(BuildContext context) {
    if (counts.isEmpty) return const SizedBox.shrink();
    final maxY = counts.fold<int>(0, (a, b) => a > b ? a : b).toDouble();
    final double niceMax = maxY == 0 ? 4.0 : (maxY + 1).ceilToDouble();
    return SizedBox(
      height: height,
      child: BarChart(
        BarChartData(
          maxY: niceMax,
          minY: 0,
          alignment: BarChartAlignment.spaceAround,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (niceMax / 4).clamp(1, double.infinity),
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text((dayLabels ?? _daysFallback)[v.toInt() % 7],
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          barGroups: List.generate(counts.length, (i) => BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[i].toDouble(),
                    width: 14,
                    borderRadius: BorderRadius.circular(4),
                    gradient: const LinearGradient(
                      colors: [AppColors.primary, AppColors.primaryDark],
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    ),
                  ),
                ],
              )),
        ),
      ),
    );
  }
}

/// Smooth line chart for revenue (or any 1-D series). The points list values
/// map to indices 0..N-1; labels under the X axis are positional (e.g. 1..N).
class RevenueLineChart extends StatelessWidget {
  const RevenueLineChart({super.key, required this.points, this.height = 180});
  final List<double> points;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) return const SizedBox.shrink();
    final maxY = points.fold<double>(0, (a, b) => a > b ? a : b);
    final niceMax = maxY == 0 ? 100.0 : (maxY * 1.2);
    return SizedBox(
      height: height,
      child: LineChart(
        LineChartData(
          minY: 0, maxY: niceMax,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: niceMax / 4,
            getDrawingHorizontalLine: (_) => const FlLine(color: AppColors.border, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (points.length / 6).ceilToDouble().clamp(1, double.infinity),
                getTitlesWidget: (v, _) => Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text("${v.toInt() + 1}",
                      style: const TextStyle(color: AppColors.textMuted, fontSize: 10, fontWeight: FontWeight.w600)),
                ),
              ),
            ),
          ),
          lineBarsData: [
            LineChartBarData(
              spots: [for (var i = 0; i < points.length; i++) FlSpot(i.toDouble(), points[i])],
              isCurved: true,
              barWidth: 2.5,
              color: AppColors.primary,
              dotData: const FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  colors: [
                    AppColors.primary.withValues(alpha: 0.35),
                    AppColors.primary.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
