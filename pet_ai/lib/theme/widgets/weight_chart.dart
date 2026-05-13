import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/weight.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/chart_placeholder.dart';

/// Reusable weight line chart.
/// Pass a pre-filtered [entries] list; the widget handles rendering.
class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final double height;

  const WeightChart({
    super.key,
    required this.entries,
    this.height = 200,
  });

  List<FlSpot> _buildSpots() {
    return List.generate(
      entries.length,
      (i) => FlSpot(i.toDouble(), entries[i].weight),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) {
      return const ChartPlaceholder(message: 'История веса пока пуста');
    }
    if (entries.length <= 3) {
      return const ChartPlaceholder(message: 'Слишком мало записей для графика');
    }

    final spots = _buildSpots();

    final minW = entries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
    final maxW = entries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
    final range = maxW - minW;
    final yInterval =
        range > 0 ? (range / 5).ceilToDouble().clamp(0.5, 100.0) : 1.0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
      child: SizedBox(
        height: height,
        child: LineChart(
          LineChartData(
            gridData: FlGridData(
              show: true,
              drawVerticalLine: false,
              horizontalInterval: yInterval,
              getDrawingHorizontalLine: (_) => const FlLine(
                color: ThemeColors.primary,
                strokeWidth: 0.5,
              ),
            ),
            borderData: FlBorderData(
              show: true,
              border: Border.all(color: ThemeColors.border),
            ),
            titlesData: FlTitlesData(
              show: true,
              rightTitles: const AxisTitles(),
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  reservedSize: 30,
                  showTitles: true,
                  interval:
                      (entries.length / 5).ceilToDouble().clamp(1, 9999),
                  getTitlesWidget: (value, meta) {
                    final index = value.toInt();
                    if (index >= entries.length) return const SizedBox();
                    return Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        DateFormat('dd.MM').format(entries[index].date),
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    );
                  },
                ),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  reservedSize: 46,
                  showTitles: true,
                  interval: yInterval,
                  getTitlesWidget: (value, meta) => Text(
                    value.toStringAsFixed(1),
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
              ),
            ),
            minY: minW * 0.975,
            lineBarsData: [
              LineChartBarData(
                spots: spots,
                isCurved: true,
                barWidth: 3,
                gradient: const LinearGradient(
                  colors: ThemeColors.gradientColors,
                ),
                dotData: FlDotData(show: entries.length <= 20),
                belowBarData: BarAreaData(
                  show: true,
                  gradient: LinearGradient(
                    colors: ThemeColors.gradientColors
                        .map((c) => c.withValues(alpha: 0.3))
                        .toList(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
