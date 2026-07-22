import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/walk.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/grouped_history_list.dart';
import 'package:pet_satellite/theme/widgets/pill_stepper.dart';
import 'package:pet_satellite/theme/widgets/walk_chart.dart';
import 'package:provider/provider.dart';

// ─── Диалог новой/редактируемой прогулки (макет 2b) ──────────────────────────

class WalkDialog extends StatefulWidget {
  final Pet profile;
  final WalkEntry? editEntry;

  const WalkDialog({super.key, required this.profile, this.editEntry});

  @override
  State<WalkDialog> createState() => _WalkDialogState();
}

class _WalkDialogState extends State<WalkDialog> {
  int _minutes = 45;
  WalkTime _walkTime = WalkTimeX.now();
  final Set<WalkActivity> _activities = {};
  bool _isSaving = false;

  bool get _isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.editEntry;
    if (entry != null) {
      _minutes = entry.durationMinutes;
      _walkTime = entry.walkTime;
      _activities.addAll(entry.activities);
    }
  }

  Future<void> _save() async {
    setState(() => _isSaving = true);
    bool error = false;
    try {
      final entry = WalkEntry(
        id: widget.editEntry?.id,
        date: widget.editEntry?.date ?? DateTime.now(),
        durationMinutes: _minutes,
        walkTime: _walkTime,
        // Порядок меток фиксирован объявлением enum — стабильная подпись.
        activities: WalkActivity.values.where(_activities.contains).toList(),
      );
      await PetProfileService().updateWalkHistory(widget.profile.id, entry);
    } catch (_) {
      error = true;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (!error) Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(_isEditing ? 'Сохранить' : 'Добавить'),
        ),
      ],
      title: Text(
        _isEditing ? 'Редактирование' : 'Новая запись',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _isSaving,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Длительность (степпер, без быстрых кнопок) ──────────────────
              Text(
                'Длительность',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 8),
              PillStepper(
                value: _minutes.toDouble(),
                unit: 'мин',
                decimals: 0,
                step: 5,
                min: 0,
                max: 600,
                onChanged: (v) => setState(() => _minutes = v.round()),
              ),

              const SizedBox(height: 16),

              // ── Время суток ─────────────────────────────────────────────────
              Text('Время суток', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Row(
                children: WalkTime.values.map((wt) {
                  final selected = _walkTime == wt;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () {
                        HapticFeedback.selectionClick();
                        setState(() => _walkTime = wt);
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(12),
                          color: selected
                              ? accent.withAlpha(200)
                              : accent.withAlpha(20),
                          border: Border.all(
                            color: selected ? accent : accent.withAlpha(60),
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              wt.icon,
                              size: 18,
                              color: selected ? Colors.white : accent,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              wt.label,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: selected ? Colors.white : accent,
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

              // ── Как прошла (мультивыбор меток) ──────────────────────────────
              Text('Как прошла', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: WalkActivity.values.map((a) {
                  final selected = _activities.contains(a);
                  return SoftGlassBadge(
                    color: selected ? accent : context.subtitleColor,
                    label: a.label,
                    icon: a.icon,
                    size: 12,
                    selected: selected,
                    onChanged: (v) {
                      HapticFeedback.selectionClick();
                      setState(() {
                        if (selected) {
                          _activities.remove(a);
                        } else {
                          _activities.add(a);
                        }
                      });
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivityChip extends StatelessWidget {
  final WalkActivity activity;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  const _ActivityChip({
    required this.activity,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = context.watch<AppearanceController>().secondaryColor;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          color: selected ? accent.withAlpha(38) : secondary.withAlpha(12),
          border: Border.all(
            color: selected ? accent : secondary.withAlpha(50),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              activity.icon,
              size: 15,
              color: selected ? accent : secondary.withAlpha(160),
            ),
            const SizedBox(width: 6),
            Text(
              activity.label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w700,
                color: selected ? accent : secondary.withAlpha(200),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Лист «Дневник прогулок» (макет 2a) ──────────────────────────────────────

class WalkSheet extends StatefulWidget {
  final Pet profile;

  const WalkSheet({super.key, required this.profile});

  @override
  State<WalkSheet> createState() => _WalkSheetState();
}

class _WalkSheetState extends State<WalkSheet> {
  late WalkHistory _history;
  HistoryPeriod _period = HistoryPeriod.week;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.walkHistory;
  }

  Future<void> _showAddDialog({WalkEntry? editEntry}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => WalkDialog(profile: widget.profile, editEntry: editEntry),
    );
    if (saved == true) await _reload();
  }

  Future<void> _reload() async {
    final fresh = await PetProfileService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() => _history = fresh.walkHistory);
    }
  }

  Future<void> _delete(WalkEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить прогулку?');
    if (!confirmed) return;
    await PetProfileService().deleteWalkEntryById(widget.profile.id, entry.id);
    if (mounted) setState(() => _history.deleteById(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _history.entries;
    final accent = context.watch<AppearanceController>().primaryColor;
    final secondary = context.watch<AppearanceController>().secondaryColor;
    final name = widget.profile.name.trim();

    return DraggableSheet(
      title: 'Дневник прогулок',
      centerTitle: true,
      initialSize: null,
      maxSize: 0.75,
      onBack: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  Icons.directions_walk,
                  size: 72,
                  color: accent.withAlpha(192),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Дневник пуст.',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        inherit: true,
                        color: secondary.withAlpha(60),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(5),
                      ),
                      onPressed: () => _showAddDialog(),
                      child: Row(
                        spacing: 1,
                        children: [
                          Text(
                            'Добавить',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  inherit: true,
                                  color: accent.withAlpha(192),
                                ),
                          ),
                          const Icon(Icons.chevron_right_rounded, size: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            // ── Кнопка «Добавить» (переиспользуемый SoftGlassButton) ──────────
            SoftGlassButton(
              icon: Icons.directions_walk,
              title: 'Добавить запись',
              subtitle: name.isNotEmpty
                  ? 'Записывайте прогулки $name'
                  : 'Ведите дневник прогулок',
              onTap: () => _showAddDialog(),
            ),

            const SizedBox(height: 16),
            Text('История', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),

            // ── Переключатель периода (разделённая кнопка) ────────────────────
            SegmentedButton<HistoryPeriod>(
              style: SegmentedButton.styleFrom(
                side: BorderSide(color: secondary, width: 2),
                foregroundColor: secondary,
                selectedBackgroundColor: secondary,
                selectedForegroundColor: Theme.of(context).colorScheme.surface,
              ),
              showSelectedIcon: false,
              segments: const [
                ButtonSegment(value: HistoryPeriod.week, label: Text('Неделя')),
                ButtonSegment(value: HistoryPeriod.month, label: Text('Месяц')),
                ButtonSegment(value: HistoryPeriod.all, label: Text('Всё')),
              ],
              selected: {_period},
              onSelectionChanged: (v) => setState(() => _period = v.first),
            ),

            const SizedBox(height: 12),

            // ── График минут «в 3 цвета» ──────────────────────────────────────
            WalkChart(
              buckets: _history.buckets(_period),
              averagePerDay: _history.averageDailyMinutes(
                days: _period == HistoryPeriod.week ? 7 : 30,
              ),
            ),

            const SizedBox(height: 8),
            Text('Список', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GroupedHistoryList<WalkEntry>(
              entries: entries,
              // Внутри дня — от поздних к ранним по времени.
              sortWithinGroup: (a, b) => b.date.compareTo(a.date),
              itemBuilder: (context, e) => _WalkEntryCard(
                entry: e,
                onEdit: () => _showAddDialog(editEntry: e),
                onDelete: () => _delete(e),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WalkEntryCard extends StatelessWidget {
  final WalkEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _WalkEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  static const _walkGreen = Color(0xFF3FAE8F);

  @override
  Widget build(BuildContext context) {
    final secondary = context.watch<AppearanceController>().secondaryColor;
    final activities = entry.activitiesLabel;

    return GlassPlate(
      useShadow: false,
      child: ListTile(
        onTap: onEdit,
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _walkGreen.withAlpha(38),
          ),
          child: const Icon(Icons.directions_walk, color: _walkGreen, size: 22),
        ),
        title: Text(
          '${entry.durationMinutes} мин',
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Row(
            children: [
              Icon(
                entry.walkTime.icon,
                size: 13,
                color: secondary.withAlpha(160),
              ),
              const SizedBox(width: 4),
              Text(entry.walkTime.label, style: context.subtitleStyle),
              if (activities.isNotEmpty) ...[
                Text('  ·  ', style: context.subtitleStyle),
                Expanded(
                  child: Text(
                    activities,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.subtitleStyle,
                  ),
                ),
              ],
            ],
          ),
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
