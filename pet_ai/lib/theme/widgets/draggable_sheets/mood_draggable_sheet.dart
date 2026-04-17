import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/chart_placeholder.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/models/history.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';

class MoodDraggableSheet extends StatefulWidget {
  final PetProfile profile;

  const MoodDraggableSheet({super.key, required this.profile});

  @override
  State<MoodDraggableSheet> createState() => _MoodDraggableSheetState();
}

class _MoodDraggableSheetState extends State<MoodDraggableSheet> {
  HistoryPeriod period = HistoryPeriod.month;

  bool change = false;

  late MoodHistory history;
  PetMood? selectedMood;
  DayPart selectedDayPart = DayPartX.now();

  @override
  void initState() {
    super.initState();
    history = widget.profile.moodHistory;
  }

  List<FlSpot> buildSpots(List<MoodEntry> entries) {
    return List.generate(entries.length, (i) {
      return FlSpot(i.toDouble(), entries[i].mood.value.toDouble());
    });
  }

  void save() async {
    if (selectedMood != null) {
      final entry = MoodEntry(
        date: DateTime.now(),
        mood: selectedMood!,
        dayPart: selectedDayPart,
      );

      // Если за сегодня уже есть запись с таким же настроением и другим
      // временем суток — объединяем (не дублируем).
      final now = DateTime.now();
      final existingIdx = history.entries.indexWhere((e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day &&
          e.dayPart == selectedDayPart);

      if (existingIdx >= 0) {
        // Заменяем запись за это время суток
        history.entries[existingIdx] = entry;
      } else {
        history.entries.add(entry);
      }

      await ProfileService().updateMoodHistory(
        widget.profile.id,
        entry,
      );
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
      title: "История настроения",
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(false),
      initialSize: 0.75,
      minSize: 0.5,
      maxSize: 0.95,
      actions: [
        IconButton(
          icon: const Icon(Icons.save),
          color: Theme.of(context).dividerColor,
          onPressed: change ? save : null,
        ),
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

          if (entries.isEmpty)
            const ChartPlaceholder(message: "История настроения пуста")
          else if (entries.length <= 3)
            const ChartPlaceholder(message: "Слишком мало записей для графика")
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
              child: SizedBox(
                height: 200,
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
                              value.toInt().toString(),
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    minY: 1,
                    maxY: 5,
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

          const SizedBox(height: 8),

          // ─── Время суток ───────────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: DayPart.values.map((part) {
              final selected = selectedDayPart == part;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: ChoiceChip(
                  avatar: Icon(part.icon, size: 16,
                    color: selected ? Colors.white : ThemeColors.primary),
                  label: Text(part.label),
                  selected: selected,
                  selectedColor: ThemeColors.primary,
                  labelStyle: TextStyle(
                    color: selected ? Colors.white : ThemeColors.textPrimary,
                  ),
                  onSelected: (_) => setState(() {
                    selectedDayPart = part;
                    change = selectedMood != null;
                  }),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 12),

          // ─── Выбор настроения ──────────────────────────────────────────
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: PetMood.values.map((mood) {
              final isSelected = selectedMood == mood;

              return GestureDetector(
                onTap: () {
                  setState(() {
                    selectedMood = mood;
                    change = true;
                  });
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 65,
                  height: 65,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isSelected
                        ? ThemeColors.primary
                        : ThemeColors.primary.withValues(alpha: 0.1),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        mood.icon,
                        size: 26,
                        color: isSelected
                            ? ThemeColors.background
                            : ThemeColors.border,
                      ),
                      Text(
                        mood.label,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          inherit: true,
                          fontSize: 8,
                          color: isSelected
                              ? ThemeColors.background
                              : ThemeColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}
