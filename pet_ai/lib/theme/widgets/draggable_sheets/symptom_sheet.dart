import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/grouped_history_list.dart';
import 'package:pet_satellite/theme/widgets/hold_to_talk_mic.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/symptom_chart.dart';
import 'package:provider/provider.dart';

// ─── Диалог новой записи симптома (макет 2f) ─────────────────────────────────

class SymptomDialog extends StatefulWidget {
  final Pet profile;

  /// Предвыбранный симптом (когда запись заводится из активной вкладки трекера).
  final SymptomTag? initialTag;

  const SymptomDialog({super.key, required this.profile, this.initialTag});

  @override
  State<SymptomDialog> createState() => _SymptomDialogState();
}

class _SymptomDialogState extends State<SymptomDialog> {
  final TextEditingController _noteCtrl = TextEditingController();
  SymptomTag? _selected;
  SymptomSeverity _severity = SymptomSeverity.moderate;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialTag;
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  void _onVoiceText(String words) {
    setState(() {
      _noteCtrl.text = words;
      _noteCtrl.selection = TextSelection.fromPosition(
        TextPosition(offset: _noteCtrl.text.length),
      );
    });
  }

  Future<void> _save() async {
    final tag = _selected;
    if (tag == null) return;

    final text = _noteCtrl.text.trim();
    final noteText = text.isNotEmpty ? text : tag.label;
    setState(() => _isSaving = true);

    bool error = false;
    try {
      await PetProfileService().addNote(
        widget.profile.id,
        noteText,
        symptomId: tag.id,
        severity: _severity,
      );
    } catch (_) {
      error = true;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (!error) Navigator.of(context).pop(tag);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _selected == null || _isSaving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('Сохранить'),
        ),
      ],
      title: Text(
        'Новая запись',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _isSaving,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Симптом ─────────────────────────────────────────────────
                Text('Симптом', style: Theme.of(context).textTheme.bodySmall),
                const SizedBox(height: 10),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: SymptomTags.all.map((tag) {
                    return SoftGlassBadge(
                      color: tag.color,
                      icon: tag.icon,
                      label: tag.label,
                      size: 12,
                      selected: _selected == tag,
                      onChanged: (isSelected) {
                        setState(() => _selected = isSelected ? tag : null);
                      },
                    );
                  }).toList(),
                ),

                const SizedBox(height: 16),

                // ── Тяжесть ─────────────────────────────────────────────────
                Text(
                  'Насколько выражен',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                _SeveritySelector(
                  value: _severity,
                  onChanged: (s) => setState(() => _severity = s),
                ),

                const SizedBox(height: 16),

                // ── Заметка + голосовой ввод ────────────────────────────────
                TextField(
                  controller: _noteCtrl,
                  maxLines: 4,
                  minLines: 3,
                  keyboardType: TextInputType.multiline,
                  decoration: baseInputDecoration(context, hint: 'Своя заметка'),
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: HoldToTalkMic(
                    onText: _onVoiceText,
                    activeColor: ThemeColors.dangerZone,
                    idleColor: context
                        .watch<AppearanceController>()
                        .secondaryColor,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Сегмент-выбор тяжести (Лёгкий / Средний / Сильный) — три пилюли в ряд.
class _SeveritySelector extends StatelessWidget {
  final SymptomSeverity value;
  final ValueChanged<SymptomSeverity> onChanged;

  const _SeveritySelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    return Row(
      children: SymptomSeverity.values.map((s) {
        final selected = s == value;
        return Expanded(
          child: Pressable(
            haptic: HapticStrength.selection,
            scale: 0.95,
            onTap: () => onChanged(s),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(999),
                color: selected ? accent.withAlpha(200) : accent.withAlpha(20),
                border: Border.all(
                  color: selected ? accent : accent.withAlpha(60),
                ),
              ),
              child: Text(
                s.label,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  color: selected ? Colors.white : accent,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Лист «Симптомы» (макет 2e) ──────────────────────────────────────────────

class SymptomSheet extends StatefulWidget {
  final Pet profile;

  const SymptomSheet({super.key, required this.profile});

  @override
  State<SymptomSheet> createState() => _SymptomSheetState();
}

class _SymptomSheetState extends State<SymptomSheet> {
  late NoteHistory _history;
  SymptomTag? _activeTag;
  HistoryPeriod _period = HistoryPeriod.month;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.noteHistory;
    final tabs = _history.activeSymptomTags();
    _activeTag = tabs.isEmpty ? null : tabs.first;
  }

  Future<void> _reload({SymptomTag? select}) async {
    final fresh = await PetProfileService().loadProfile(widget.profile.id);
    if (fresh == null || !mounted) return;
    setState(() {
      _history = fresh.noteHistory;
      final tabs = _history.activeSymptomTags();
      // Приоритет: явно выбранный (только что добавленный) → текущий, если ещё
      // есть записи → первый доступный.
      final fallback = tabs.contains(_activeTag)
          ? _activeTag
          : (tabs.isEmpty ? null : tabs.first);
      _activeTag = select ?? fallback;
    });
  }

  Future<void> _showAddDialog({SymptomTag? tag}) async {
    final saved = await showDialog<SymptomTag>(
      context: context,
      builder: (_) => SymptomDialog(profile: widget.profile, initialTag: tag),
    );
    if (saved != null) await _reload(select: saved);
  }

  Future<void> _delete(NoteEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить запись?');
    if (!confirmed) return;
    await PetProfileService().deleteNoteEntry(widget.profile.id, entry.id);
    // Без select: _reload сам оставит текущую вкладку, если по ней ещё есть
    // записи, иначе переключится на первую доступную.
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final secondary = context.watch<AppearanceController>().secondaryColor;
    final hasSymptoms = _history.symptomEntries.isNotEmpty;

    return DraggableSheet(
      title: 'Симптомы',
      centerTitle: true,
      initialSize: null,
      maxSize: 0.85,
      onBack: () => Navigator.of(context).pop(true),
      body: hasSymptoms
          ? _buildContent(context, accent, secondary)
          : _buildEmpty(context, accent, secondary),
    );
  }

  Widget _buildEmpty(BuildContext context, Color accent, Color secondary) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      mainAxisSize: MainAxisSize.max,
      children: [
        Icon(Icons.monitor_heart_outlined, size: 72, color: accent.withAlpha(192)),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Симптомов нет.',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                inherit: true,
                color: secondary.withAlpha(60),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: const EdgeInsets.all(5)),
              onPressed: () => _showAddDialog(),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Отметить',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
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
    );
  }

  Widget _buildContent(BuildContext context, Color accent, Color secondary) {
    final tabs = _history.activeSymptomTags();
    final active = _activeTag;
    final List<NoteEntry> episodes =
        active != null ? _history.entriesForSymptom(active.id) : <NoteEntry>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Вкладки по симптомам (записи за последний месяц) + «Ещё» ─────────
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final tag in tabs)
              SoftGlassBadge(
                color: tag.color,
                icon: tag.icon,
                label: tag.label,
                size: 12,
                selected: active == tag,
                onChanged: (_) => setState(() => _activeTag = tag),
              ),
            SoftGlassBadge(
              color: secondary,
              icon: Icons.add,
              label: 'Ещё',
              size: 12,
              onChanged: (_) => _showAddDialog(),
            ),
          ],
        ),

        const SizedBox(height: 12),

        if (active != null) ...[
          // ── Статус-карточка ───────────────────────────────────────────────
          _StatusCard(status: _history.symptomStatus(active.id)),

          const SizedBox(height: 8),
          // ── Кнопка добавления записи по выбранному симптому ────────────────
          SoftGlassButton(
            icon: active.icon,
            title: 'Добавить запись',
            subtitle: 'Отметьте эпизод «${active.label.toLowerCase()}»',
            onTap: () => _showAddDialog(tag: active),
          ),

          const SizedBox(height: 16),
          Text('История', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),

          // ── Переключатель периода ─────────────────────────────────────────
          SegmentedButton<HistoryPeriod>(
            style: SegmentedButton.styleFrom(
              side: BorderSide(color: secondary, width: 2),
              foregroundColor: secondary,
              selectedBackgroundColor: secondary,
              selectedForegroundColor: Theme.of(context).colorScheme.surface,
            ),
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: HistoryPeriod.month, label: Text('Месяц')),
              ButtonSegment(value: HistoryPeriod.all, label: Text('Всё')),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),

          const SizedBox(height: 12),
          _buildChart(active),

          const SizedBox(height: 8),
          Text('Список', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          GroupedHistoryList<NoteEntry>(
            entries: episodes,
            sortWithinGroup: (a, b) => b.date.compareTo(a.date),
            itemBuilder: (context, e) =>
                _SymptomEntryCard(entry: e, onDelete: () => _delete(e)),
          ),
        ],
      ],
    );
  }

  Widget _buildChart(SymptomTag active) {
    if (_period == HistoryPeriod.month) {
      final bars = _history.severityDailyBars(active.id, days: 14);
      return SymptomChart(
        bars: bars,
        startLabel: formatSmartDate(bars.first.date, pattern: 'd MMMM'),
        endLabel: 'Сегодня',
      );
    }
    return SymptomChart(bars: _history.severityMonthlyBars(active.id));
  }
}

// ─── Статус-карточка симптома ─────────────────────────────────────────────────

class _StatusCard extends StatelessWidget {
  final SymptomStatus status;

  const _StatusCard({required this.status});

  ({String title, IconData icon, Color color}) _style() {
    switch (status.trend) {
      case SymptomTrend.improving:
        return (
          title: 'Идёт на поправку',
          icon: Icons.trending_down,
          color: ThemeColors.positiveDynamics,
        );
      case SymptomTrend.worsening:
        return (
          title: 'Симптом усиливается',
          icon: Icons.trending_up,
          color: ThemeColors.negativeDynamics,
        );
      case SymptomTrend.steady:
        return (
          title: 'Без изменений',
          icon: Icons.trending_flat,
          color: ThemeColors.neutralDynamics,
        );
      case SymptomTrend.dormant:
        return (
          title: 'Пока спокойно',
          icon: Icons.check_circle_outline,
          color: ThemeColors.positiveDynamics,
        );
    }
  }

  String _subtitle() {
    if (status.lastDate == null) return 'Пока нет записей';
    final last = formatSmartDate(status.lastDate!, pattern: 'd MMMM');
    final days = status.daysSinceLast;
    if (days <= 0) return 'Есть запись сегодня · эпизодов: ${status.episodeCount}';
    return '$days ${dayDeclension(days)} без записей · последний эпизод $last';
  }

  @override
  Widget build(BuildContext context) {
    final s = _style();
    return SoftGlassPlate(
      color: s.color.withAlpha(128),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: ThemeColors.white,
              ),
              child: Icon(s.icon, size: 24, color: s.color),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.title,
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: context.titleColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(_subtitle(), style: context.subtitleStyle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Карточка эпизода в списке ────────────────────────────────────────────────

class _SymptomEntryCard extends StatelessWidget {
  final NoteEntry entry;
  final VoidCallback onDelete;

  const _SymptomEntryCard({required this.entry, required this.onDelete});

  static String _time(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final secondary = context.watch<AppearanceController>().secondaryColor;

    // Тяжесть у записи-симптома всегда есть (см. NoteHistory.symptomEntries).
    final severity = entry.severity!;
    final note = entry.note.trim();
    // Подпись = заметка, если она несёт больше, чем название симптома; иначе время.
    final extra = (note.isNotEmpty && note != entry.symptomTag?.label)
        ? note
        : _time(entry.date);

    return GlassPlate(
      useShadow: false,
      child: ListTile(
        title: Text(
          severity.label,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: secondary,
            fontWeight: FontWeight.w700,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            extra,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.subtitleStyle,
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
