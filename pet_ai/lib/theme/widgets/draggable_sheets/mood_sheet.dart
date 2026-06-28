import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/widgets/chart_placeholder.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/grouped_history_list.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:provider/provider.dart';

import '../../../services/appearance_controller.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class MoodSheet extends StatefulWidget {
  final Pet profile;

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

  void save() async {
    if (selectedMood == null) return;

    final entry = MoodEntry(
      date: DateTime.now(),
      mood: selectedMood!,
      dayPart: selectedDayPart,
    );

    // Запись за тот же день и время суток перезаписывается (см. addOrReplace).
    await PetService().updateMoodHistory(widget.profile.id, entry);

    // Stay in sheet — reload history and reset selection
    final fresh = await PetService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() {
        history = fresh.moodHistory;
        selectedMood = null;
        change = false;
      });
    }
  }

  Future<void> _deleteEntry(MoodEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить запись?');
    if (!confirmed) return;
    await PetService().deleteMoodEntry(widget.profile.id, entry.date);
    if (mounted) setState(() => history.deleteEntry(entry.date));
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);

    return DraggableSheet(
      title: "История настроения",
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(true),
      initialSize: 0.85,
      maxSize: 0.85,
      body: Column(
        children: [
          SegmentedButton<HistoryPeriod>(
            style: SegmentedButton.styleFrom(
              side: BorderSide(
                color: context.watch<AppearanceController>().secondaryColor,
                width: 2,
              ),
              foregroundColor: context
                  .watch<AppearanceController>()
                  .secondaryColor,
              selectedBackgroundColor: context
                  .watch<AppearanceController>()
                  .secondaryColor,
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
          else
            Padding(
              padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
              child: _MoodFrequencyChart(entries: entries),
            ),

          const SizedBox(height: 8),

          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Новая запись',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text('Время суток', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Row(
                    children: DayPart.values.map((mt) {
                      final selected = selectedDayPart == mt;
                      return Expanded(
                        child: Pressable(
                          haptic: HapticStrength.selection,
                          scale: 0.93,
                          onTap: () => setState(() => selectedDayPart = mt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selected
                                  ? context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(200)
                                  : context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(20),
                              border: Border.all(
                                color: selected
                                    ? context
                                          .watch<AppearanceController>()
                                          .primaryColor
                                    : context
                                          .watch<AppearanceController>()
                                          .primaryColor
                                          .withAlpha(60),
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
                                      : context
                                            .watch<AppearanceController>()
                                            .primaryColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mt.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : context
                                              .watch<AppearanceController>()
                                              .primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  Text('Настроение', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children: PetMood.values.map((mood) {
                      final isSelected = selectedMood == mood;

                      return Pressable(
                        haptic: HapticStrength.selection,
                        scale: 0.9,
                        onTap: () {
                          setState(() {
                            selectedMood = mood;
                            change = true;
                          });
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isSelected
                                ? context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                : context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                      .withValues(alpha: 0.1),
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                mood.icon,
                                size: 26,
                                color: isSelected
                                    ? ThemeColors.background
                                    : context
                                          .watch<AppearanceController>()
                                          .secondaryColor,
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
                                          : context
                                                .watch<AppearanceController>()
                                                .secondaryColor,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),

                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: change
                          ? () {
                        triggerHaptic(HapticStrength.medium);
                        save();
                      }
                          : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),
                    ),
                  ),
                ],
              ),
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
            GroupedHistoryList<MoodEntry>(
              entries: history.entries,
              // Внутри даты: утро → день → вечер, затем по времени.
              sortWithinGroup: (a, b) {
                final byPart = b.dayPart.index.compareTo(a.dayPart.index);
                if (byPart != 0) return byPart;
                return a.date.compareTo(b.date);
              },
              itemBuilder: (context, e) =>
                  _MoodEntryCard(entry: e, onDelete: () => _deleteEntry(e)),
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
      useShadow: false,
      child: ListTile(
        leading: Icon(
          entry.mood.icon,
          color: context.watch<AppearanceController>().primaryColor,
          size: 26,
        ),
        title: Text(
          entry.mood.label,
          style: Theme.of(
            context,
          ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Row(
          spacing: 4,
          children: [
            Icon(
              entry.dayPart.icon,
              size: 14,
              color: context.watch<AppearanceController>().primaryColor,
            ),
            Text(entry.dayPart.label, style: Theme.of(
              context,
            ).textTheme.bodySmall),
          ],
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: ThemeColors.dangerZone.withAlpha(180),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

/// Гистограмма частоты видов настроения за выбранный период.
/// По оси X — типы настроения (от «Болеет» к «Счастлив»), по Y — число записей.
class _MoodFrequencyChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const _MoodFrequencyChart({required this.entries});

  /// Порядок столбцов: от худшего настроения к лучшему.
  static const _order = [
    PetMood.sick,
    PetMood.calm,
    PetMood.playful,
    PetMood.happy,
  ];

  static Color _colorFor(PetMood mood) {
    switch (mood) {
      case PetMood.sick:
        return const Color(0xFFEF5350);
      case PetMood.calm:
        return const Color(0xFFFFC107);
      case PetMood.playful:
        return const Color(0xFF42A5F5);
      case PetMood.happy:
        return const Color(0xFF66BB6A);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Считаем частоту каждого настроения.
    final counts = {for (final m in _order) m: 0};
    for (final e in entries) {
      counts[e.mood] = (counts[e.mood] ?? 0) + 1;
    }
    final maxCount = counts.values.fold<int>(0, (a, b) => a > b ? a : b);
    // Округляем верх до удобного значения, чтобы подписи оси были целыми.
    final maxY = (maxCount + 1).toDouble();

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: maxY,
          minY: 0,
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (_) =>
                const FlLine(color: ThemeColors.primary, strokeWidth: 0.5),
          ),
          borderData: FlBorderData(
            show: true,
            border: Border.all(color: ThemeColors.border),
          ),
          barTouchData: BarTouchData(
            enabled: true,
            touchTooltipData: BarTouchTooltipData(
              fitInsideHorizontally: true,
              fitInsideVertically: true,
              tooltipBorderRadius: BorderRadius.circular(12),
              tooltipPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 8,
              ),
              tooltipMargin: 12,
              tooltipBorder: const BorderSide(
                color: ThemeColors.primary,
                width: 1,
              ),
              getTooltipColor: (_) => ThemeColors.white,
              getTooltipItem: (group, _, rod, _) {
                final mood = _order[group.x];
                return BarTooltipItem(
                  '${rod.toY.toInt()}',
                  Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: ThemeColors.textPrimary,
                    fontWeight: FontWeight.bold,
                  ),
                  children: [
                    TextSpan(
                      text: '\n${mood.label}',
                      style: Theme.of(context).textTheme.bodySmall!.copyWith(
                        color: ThemeColors.secondary,
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final i = value.toInt();
                  if (i < 0 || i >= _order.length) return const SizedBox();
                  final mood = _order[i];
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Icon(
                      mood.icon,
                      size: 20,
                      color: _colorFor(mood),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  if (value != value.roundToDouble()) return const SizedBox();
                  return Text(
                    '${value.toInt()}',
                    style: Theme.of(context).textTheme.titleSmall,
                  );
                },
              ),
            ),
          ),
          barGroups: [
            for (var i = 0; i < _order.length; i++)
              BarChartGroupData(
                x: i,
                barRods: [
                  BarChartRodData(
                    toY: counts[_order[i]]!.toDouble(),
                    width: 26,
                    color: _colorFor(_order[i]),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(6),
                    ),
                    backDrawRodData: BackgroundBarChartRodData(
                      show: true,
                      toY: maxY,
                      color: _colorFor(_order[i]).withAlpha(20),
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}
