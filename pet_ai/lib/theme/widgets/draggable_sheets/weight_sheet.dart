import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/chart_placeholder.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:pet_ai/theme/widgets/pill_stepper.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/models/history.dart';
import 'package:pet_ai/models/weight.dart';

class WeightSheet extends StatefulWidget {
  final PetProfile profile;

  const WeightSheet({super.key, required this.profile});

  @override
  State<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<WeightSheet> {
  HistoryPeriod period = HistoryPeriod.month;

  bool change = false;
  late double weight;
  late WeightHistory history;

  @override
  void initState() {
    super.initState();
    weight = widget.profile.weightHistory.lastWeight ?? 0.0;
    history = widget.profile.weightHistory;
  }

  List<FlSpot> buildSpots(List<WeightEntry> entries) {
    return List.generate(entries.length, (i) {
      return FlSpot(i.toDouble(), entries[i].weight);
    });
  }

  void save() async {
    await ProfileService().updateWeightHistory(widget.profile.id, weight);
    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteEntry(WeightEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ProfileService().deleteWeightEntry(widget.profile.id, entry.date);
    if (mounted) setState(() => history.deleteEntry(entry.date));
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);
    final spots = buildSpots(entries);

    // Compute a sane Y interval to prevent label overlap
    double yInterval = 1.0;
    if (entries.length > 1) {
      final minW = entries.map((e) => e.weight).reduce((a, b) => a < b ? a : b);
      final maxW = entries.map((e) => e.weight).reduce((a, b) => a > b ? a : b);
      final range = maxW - minW;
      if (range > 0) yInterval = (range / 5).ceilToDouble().clamp(0.5, 100.0);
    }

    return DraggableSheet(
      onBack: () => Navigator.of(context).pop(false),
      title: "История веса",
      centerTitle: true,
      initialSize: 0.85,
      minSize: 0.4,
      maxSize: 1.0,
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          color: Theme.of(context).dividerColor,
          onPressed: change ? () async => save() : null,
        )
      ],
      body: Column(
        children: [
          SegmentedButton<HistoryPeriod>(
            style: SegmentedButton.styleFrom(
              side: BorderSide(color: Theme.of(context).dividerColor, width: 2),
              foregroundColor: Theme.of(context).dividerColor,
              selectedForegroundColor: Theme.of(context).colorScheme.surface,
            ),
            segments: const [
              ButtonSegment(value: HistoryPeriod.month, label: Text("Месяц")),
              ButtonSegment(value: HistoryPeriod.year, label: Text("Год")),
              ButtonSegment(value: HistoryPeriod.all, label: Text("Все")),
            ],
            selected: {period},
            onSelectionChanged: (value) {
              setState(() {
                period = value.first;
              });
            },
          ),

          const SizedBox(height: 16),

          // ── Chart ─────────────────────────────────────────────────────────
          if (entries.isEmpty)
            const ChartPlaceholder(message: "История веса пока пуста")
          else if (entries.length <= 3)
            const ChartPlaceholder(
              message: "Слишком мало записей для графика",
            )
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
              child: SizedBox(
                height: 200,
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
                          interval: (entries.length / 5).ceilToDouble().clamp(1, 9999),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= entries.length) return const SizedBox();
                            final date = entries[index].date;
                            return Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: Text(
                                DateFormat('dd.MM').format(date),
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
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    minY: entries
                            .map((e) => e.weight)
                            .reduce((a, b) => a < b ? a : b) *
                        0.975,
                    lineBarsData: [
                      LineChartBarData(
                        spots: spots,
                        isCurved: true,
                        barWidth: 3,
                        gradient: LinearGradient(
                          colors: ThemeColors.gradientColors,
                        ),
                        dotData: FlDotData(show: true),
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
            ),

          // ── New-weight stepper ────────────────────────────────────────────
          Center(
            child: PillStepper(
              value: weight,
              onChanged: (value) {
                setState(() {
                  change = true;
                  weight = value;
                });
              },
            ),
          ),

          // ── History list ──────────────────────────────────────────────────
          if (history.entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'История',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...List.from(history.entries.reversed).map<Widget>(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WeightEntryCard(
                  entry: e as WeightEntry,
                  onDelete: () => _deleteEntry(e),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightEntryCard extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onDelete;

  const _WeightEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.monitor_weight_outlined,
                color: ThemeColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.weight.toStringAsFixed(1)} кг',
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: ThemeColors.textPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  Text(
                    DateFormat('d MMMM yyyy', 'ru_RU').format(entry.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: ThemeColors.danger.withAlpha(180),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
