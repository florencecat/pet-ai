import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/chart_placeholder.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/models/history.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

class MoodSheet extends StatefulWidget {
  final PetProfile profile;

  const MoodSheet({super.key, required this.profile});

  @override
  State<MoodSheet> createState() => _MoodSheetState();
}

class _MoodSheetState extends State<MoodSheet> {
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
      final existingIdx = history.entries.indexWhere(
        (e) =>
            e.date.year == now.year &&
            e.date.month == now.month &&
            e.date.day == now.day &&
            e.dayPart == selectedDayPart,
      );

      if (existingIdx >= 0) {
        // Заменяем запись за это время суток
        history.entries[existingIdx] = entry;
      } else {
        history.entries.add(entry);
      }

      await ProfileService().updateMoodHistory(widget.profile.id, entry);
    }

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop(true);
    }
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
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
    await ProfileService().deleteMoodEntry(widget.profile.id, entry.date);
    if (mounted) setState(() => history.deleteEntry(entry.date));
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

          // ── Chart ─────────────────────────────────────────────────────────
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
                      drawVerticalLine: false,
                      horizontalInterval: 1,
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
                          interval: (entries.length / 5).ceilToDouble().clamp(
                            1,
                            9999,
                          ),
                          getTitlesWidget: (value, meta) {
                            final index = value.toInt();
                            if (index >= entries.length)
                              return const SizedBox();
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
                          reservedSize: 30,
                          showTitles: true,
                          interval: 1,
                          getTitlesWidget: (value, meta) {
                            final v = value.toInt();
                            // Only show integers in the 1-4 range (mood values)
                            if (v < 1 || v > 4) return const SizedBox();
                            return Text(
                              '$v',
                              style: Theme.of(context).textTheme.titleSmall,
                            );
                          },
                        ),
                      ),
                    ),
                    minY: 1,
                    maxY: 4,
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

          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                spacing: 16,
                children: [
                  Row(
                    children: DayPart.values.map((mt) {
                      final selected = selectedDayPart == mt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => selectedDayPart = mt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selected
                                  ? ThemeColors.primary.withAlpha(200)
                                  : ThemeColors.primary.withAlpha(20),
                              border: Border.all(
                                color: selected
                                    ? ThemeColors.primary
                                    : ThemeColors.primary.withAlpha(60),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mt.icon,
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : ThemeColors.primary,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mt.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : ThemeColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
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
                                style: Theme.of(context).textTheme.titleSmall!
                                    .copyWith(
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
            ),
          ),

          // ─── Время суток ───────────────────────────────────────────────
          // Row(
          //   mainAxisAlignment: MainAxisAlignment.center,
          //   children: DayPart.values.map((part) {
          //     final selected = selectedDayPart == part;
          //     return Padding(
          //       padding: const EdgeInsets.symmetric(horizontal: 4),
          //       child: ChoiceChip(
          //         avatar: Icon(part.icon, size: 16,
          //           color: selected ? Colors.white : ThemeColors.primary),
          //         label: Text(part.label),
          //         selected: selected,
          //         selectedColor: ThemeColors.primary,
          //         labelStyle: TextStyle(
          //           color: selected ? Colors.white : ThemeColors.textPrimary,
          //         ),
          //         onSelected: (_) => setState(() {
          //           selectedDayPart = part;
          //           change = selectedMood != null;
          //         }),
          //       ),
          //     );
          //   }).toList(),
          // ),
          const SizedBox(height: 12),

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
                child: _MoodEntryCard(
                  entry: e as MoodEntry,
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

class _MoodEntryCard extends StatelessWidget {
  final MoodEntry entry;
  final VoidCallback onDelete;

  const _MoodEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(entry.mood.icon, color: ThemeColors.primary, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.mood.label,
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
