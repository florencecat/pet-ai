import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/chart_placeholder.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/pill_stepper.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/models/history.dart';
import 'package:pet_ai/models/weight.dart';

class WeightDraggableSheet extends StatefulWidget {
  final PetProfile profile;

  const WeightDraggableSheet({super.key, required this.profile});

  @override
  State<WeightDraggableSheet> createState() => _WeightDraggableSheetState();
}

class _WeightDraggableSheetState extends State<WeightDraggableSheet> {
  HistoryPeriod period = HistoryPeriod.month;

  final controller = TextEditingController();

  bool change = false;
  late double weight;
  late WeightHistory history;

  @override
  void initState() {
    super.initState();
    weight = widget.profile.weightHistory.lastWeight ?? 0.0;
    history = widget.profile.weightHistory;

    controller.text = weight.toString();
  }

  List<FlSpot> buildSpots(List<WeightEntry> entries) {
    return List.generate(entries.length, (i) {
      return FlSpot(i.toDouble(), entries[i].weight);
    });
  }

  void increase() {
    HapticFeedback.selectionClick();

    final current = double.tryParse(controller.text) ?? 0;
    final newValue = (current + 0.1).clamp(0, 999);

    setState(() {
      controller.text = newValue.toStringAsFixed(1);
    });
  }

  void decrease() {
    HapticFeedback.selectionClick();

    final current = double.tryParse(controller.text) ?? 0;
    final newValue = (current - 0.1).clamp(0, 999);

    setState(() {
      controller.text = newValue.toStringAsFixed(1);
    });
  }

  void save() async {
    final newWeight = double.tryParse(weight.toStringAsFixed(1));
    if (newWeight != null) {
      await ProfileService().updateWeightHistory(widget.profile.id, weight);
    }
    if (Navigator.of(context).mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);
    final spots = buildSpots(entries);

    return DraggableSheet(
      onBack: () => Navigator.of(context).pop(false),
      title: "История веса",
      centerTitle: true,
      initialSize: 0.675,
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
            segments: [
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

          if (entries.isEmpty)
            ChartPlaceholder(message: "История веса пока пуста")
          else if (entries.length <= 3)
            ChartPlaceholder(
              message: "В истории слишком мало записей для отображения",
            )
          else
            Padding(
              padding: EdgeInsetsGeometry.fromLTRB(5, 10, 10, 10),
              child: SizedBox(
                height: 250,
                child: LineChart(
                  LineChartData(
                    gridData: FlGridData(
                      show: true,
                      drawVerticalLine: true,
                      horizontalInterval: 1,
                      verticalInterval: 1,
                      getDrawingHorizontalLine: (value) {
                        return const FlLine(
                          color: ThemeColors.primary,
                          strokeWidth: 1,
                        );
                      },
                      getDrawingVerticalLine: (value) {
                        return const FlLine(
                          color: ThemeColors.primary,
                          strokeWidth: 1,
                        );
                      },
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
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();

                            if (index >= entries.length || index == 0) {
                              return const SizedBox();
                            }

                            final date = entries[index].date;

                            return Text(
                              "${date.day}.${date.month}",
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                      leftTitles: AxisTitles(
                        sideTitles: SideTitles(
                          reservedSize: 42,
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            return Text(
                              value.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    minY:
                        entries.reduce((min, entry) {
                          return entry.weight < min.weight ? entry : min;
                        }).weight *
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
                                .map((color) => color.withValues(alpha: 0.3))
                                .toList(),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
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
        ],
      ),
    );
  }
}
