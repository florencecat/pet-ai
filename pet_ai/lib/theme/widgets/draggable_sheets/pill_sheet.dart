import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pill_reminder_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pill_icon.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

// ─── Shared form state ────────────────────────────────────────────────────────

/// Holds mutable form state for create / edit.
class _PillFormState {
  final TextEditingController nameCtrl;
  final TextEditingController doseAmountCtrl;
  PillKind? kind;
  int? color;
  DoseUnit doseUnit;
  // Пользователь вручную менял единицу → не переопределять её при смене вида.
  bool doseUnitTouched;
  PillFrequencyType frequency;
  Set<int> weekdays;
  List<TimeOfDay> schedules;
  DateTime startDate;
  bool hasEndDate;
  DateTime endDate;

  _PillFormState({
    String name = '',
    this.kind,
    this.color,
    String doseAmount = '',
    DoseUnit? doseUnit,
    this.doseUnitTouched = false,
    this.frequency = PillFrequencyType.daily,
    Set<int>? weekdays,
    List<TimeOfDay>? schedules,
    DateTime? startDate,
    this.hasEndDate = false,
    DateTime? endDate,
  }) : nameCtrl = TextEditingController(text: name),
       doseAmountCtrl = TextEditingController(text: doseAmount),
       doseUnit = doseUnit ?? DoseUnit.forKind(kind).first,
       weekdays = weekdays ?? {1, 2, 3, 4, 5},
       schedules = schedules ?? [const TimeOfDay(hour: 9, minute: 0)],
       startDate = startDate ?? DateTime.now(),
       endDate = endDate ?? DateTime.now().add(const Duration(days: 30));

  factory _PillFormState.fromReminder(Pill r) => _PillFormState(
    name: r.name,
    kind: r.kind,
    color: r.color,
    doseAmount: r.doseValue == 0 ? '' : r.doseValue.toString(),
    doseUnit: r.doseUnit,
    // Если у препарата уже задана единица — считаем её выбранной пользователем,
    // чтобы не сбросить при смене вида.
    doseUnitTouched: r.doseUnit.id != 'none',
    frequency: r.frequencyType,
    weekdays: Set.of(r.weekdays),
    schedules: r.schedules.map((s) => s.toTimeOfDay()).toList(),
    startDate: r.startDate,
    hasEndDate: r.endDate != null,
    endDate: r.endDate ?? DateTime.now().add(const Duration(days: 30)),
  );

  int get doseValue => int.tryParse(doseAmountCtrl.text.trim()) ?? 0;

  void dispose() {
    nameCtrl.dispose();
    doseAmountCtrl.dispose();
  }
}

// ─── Sheet: список + создание напоминаний ────────────────────────────────────

class PillReminderSheet extends StatefulWidget {
  final Pet profile;
  const PillReminderSheet({super.key, required this.profile});

  @override
  State<PillReminderSheet> createState() => _PillReminderSheetState();
}

class _PillReminderSheetState extends State<PillReminderSheet> {
  late _PillFormState _form;
  bool _saving = false;
  bool _actualRemindersExpanded = true;
  bool _archiveRemindersExpanded = false;

  @override
  void initState() {
    super.initState();
    _form = _PillFormState();
  }

  @override
  void dispose() {
    _form.dispose();
    super.dispose();
  }

  Future<void> _addSchedule() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _form.schedules.add(picked));
  }

  Future<void> _editSchedule(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _form.schedules[index],
    );
    if (picked != null) setState(() => _form.schedules[index] = picked);
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd ? _form.endDate : _form.startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _form.endDate = picked;
      } else {
        _form.startDate = picked;
        if (_form.hasEndDate && _form.endDate.isBefore(_form.startDate)) {
          _form.endDate = _form.startDate.add(const Duration(days: 30));
        }
      }
    });
  }

  Future<void> _save() async {
    final name = _form.nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название препарата')),
      );
      return;
    }
    if (_form.frequency == PillFrequencyType.weekdays &&
        _form.weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день')),
      );
      return;
    }
    if (_form.frequency != PillFrequencyType.onDemand &&
        _form.schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно время приёма')),
      );
      return;
    }

    setState(() => _saving = true);

    final sortedSchedules = List.of(_form.schedules)
      ..sort(
        (a, b) => a.hour != b.hour
            ? a.hour.compareTo(b.hour)
            : a.minute.compareTo(b.minute),
      );

    final reminder = Pill(
      id: generateId(),
      name: name,
      kind: _form.kind,
      color: _form.color,
      doseValue: _form.doseValue,
      doseUnit: _form.doseUnit,
      frequencyType: _form.frequency,
      weekdays: _form.frequency == PillFrequencyType.weekdays
          ? (List.of(_form.weekdays)..sort())
          : [],
      schedules: sortedSchedules
          .map((t) => PillSchedule.fromTimeOfDay(t))
          .toList(),
      startDate: _form.startDate,
      endDate: _form.hasEndDate ? _form.endDate : null,
      takenDates: const [],
    );

    await PillReminderService().add(
      petId: widget.profile.id,
      reminder: reminder,
    );
    if (!mounted) return;

    // Stay in sheet — reload list and reset form
    final fresh = await PetService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() {
        widget.profile.pillReminders
          ..clear()
          ..addAll(fresh.pillReminders);
        _form.dispose();
        _form = _PillFormState();
        _saving = false;
      });
    } else {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDetail(Pill reminder) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          PillDetailSheet(profile: widget.profile, reminder: reminder),
    );
    if (updated == true && mounted) {
      final fresh = await PetService().loadProfile(widget.profile.id);
      if (fresh != null && mounted) {
        setState(() {
          widget.profile.pillReminders
            ..clear()
            ..addAll(fresh.pillReminders);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final reminders = List.of(widget.profile.pillReminders)
      ..sort((a, b) => a.name.compareTo(b.name));
    final actualReminders = reminders.where(
      (r) =>
          r.endDate == null ||
          r.endDate!.isAfter(DateTime.now()) ||
          r.endDate!.isAtSameMomentAs(DateTime.now()),
    );
    final archiveReminders = reminders.where(
      (r) => r.endDate != null && r.endDate!.isBefore(DateTime.now()),
    );

    return DraggableSheet(
      title: 'Препараты',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(true),
      initialSize: 0.9,
      minSize: 0.5,
      maxSize: 1.0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Create form ─────────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: _PillForm(
                form: _form,
                accent: accent,
                saving: _saving,
                onAddSchedule: _addSchedule,
                onEditSchedule: _editSchedule,
                onPickDate: _pickDate,
                onSave: _save,
                onChanged: () => setState(() {}),
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── Existing reminders list ──────────────────────────────────────
          if (actualReminders.isEmpty && archiveReminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Напоминаний пока нет',
                textAlign: TextAlign.center,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium!.copyWith(color: ThemeColors.border),
              ),
            ),

          if (actualReminders.isNotEmpty)
            CollapsibleSection(
              expanded: _actualRemindersExpanded,
              onToggle: () => setState(
                () => _actualRemindersExpanded = !_actualRemindersExpanded,
              ),
              titleContent: Row(
                spacing: 4,
                children: [
                  Text(
                    'Активные курсы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!_actualRemindersExpanded)
                    Text(
                      '( ${archiveReminders.length.toString()} )',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor
                            .withAlpha(192),
                      ),
                    ),
                ],
              ),

              body: Column(
                children: [
                  ...actualReminders.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _ReminderListTile(
                        reminder: r,
                        accent: accent,
                        onTap: () => _openDetail(r),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          if (archiveReminders.isNotEmpty)
            CollapsibleSection(
              expanded: _archiveRemindersExpanded,
              onToggle: () => setState(
                () => _archiveRemindersExpanded = !_archiveRemindersExpanded,
              ),
              titleContent: Row(
                spacing: 4,
                children: [
                  Text(
                    'Законченные курсы',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  if (!_archiveRemindersExpanded)
                    Text(
                      '( ${archiveReminders.length.toString()} )',
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor
                            .withAlpha(192),
                      ),
                    ),
                ],
              ),
              body: Column(
                children: [
                  ...archiveReminders.map(
                    (r) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: _ReminderListTile(
                        reminder: r,
                        accent: accent,
                        onTap: () => _openDetail(r),
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
}

// ─── Shared form widget ───────────────────────────────────────────────────────

class _PillForm extends StatelessWidget {
  final _PillFormState form;
  final Color accent;
  final bool saving;
  final VoidCallback onAddSchedule;
  final void Function(int index) onEditSchedule;
  final Future<void> Function({required bool isEnd}) onPickDate;
  final VoidCallback onSave;
  final VoidCallback onChanged;
  final String saveLabel;

  const _PillForm({
    required this.form,
    required this.accent,
    required this.saving,
    required this.onAddSchedule,
    required this.onEditSchedule,
    required this.onPickDate,
    required this.onSave,
    required this.onChanged,
    this.saveLabel = 'Добавить',
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _IconPickerTile(
          kind: form.kind,
          color: form.color,
          accent: accent,
          onTap: () async {
            final result = await showPillIconPicker(
              context,
              initialKind: form.kind,
              initialColor: form.color,
              accent: accent,
            );
            if (result != null) {
              form.kind = result.kind;
              form.color = result.color;
              // Единицы дозы зависят от вида: если пользователь не выбирал
              // единицу вручную — подставляем подходящую по умолчанию.
              if (!form.doseUnitTouched) {
                form.doseUnit = DoseUnit.forKind(form.kind).first;
              }
              onChanged();
            }
          },
        ),
        const SizedBox(height: 10),
        TextField(
          controller: form.nameCtrl,
          decoration: baseInputDecoration('Название препарата'),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 10),
        _DoseField(form: form, accent: accent, onChanged: onChanged),

        const SizedBox(height: 12),
        Text('Периодичность', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          children: PillFrequencyType.values.map((f) {
            return SoftGlassBadge(
              color: accent,
              icon: f.icon,
              label: f.label,
              selected: form.frequency == f,
              onChanged: (_) {
                form.frequency = f;
                onChanged();
              },
            );
          }).toList(),
        ),

        if (form.frequency == PillFrequencyType.weekdays) ...[
          const SizedBox(height: 10),
          Text('Дни недели', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          _WeekdayPicker(
            selected: form.weekdays,
            accent: accent,
            onChanged: (days) {
              form.weekdays
                ..clear()
                ..addAll(days);
              onChanged();
            },
          ),
        ],

        // ── Times ────────────────────────────────────────────────────────
        // Для «по требованию» нет фиксированного времени приёма — пользователь
        // отмечает каждый приём вручную.
        if (form.frequency != PillFrequencyType.onDemand) ...[
          const SizedBox(height: 12),
          Text('Время приёма', style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...form.schedules.asMap().entries.map((entry) {
                final i = entry.key;
                final t = entry.value;
                final label =
                    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
                return InkWell(
                  onTap: () => onEditSchedule(i),
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: accent.withAlpha(80)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.access_time, size: 14, color: accent),
                        const SizedBox(width: 5),
                        Text(
                          label,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: accent,
                          ),
                        ),
                        if (form.schedules.length > 1) ...[
                          const SizedBox(width: 6),
                          GestureDetector(
                            onTap: () {
                              form.schedules.removeAt(i);
                              onChanged();
                            },
                            child: Icon(
                              Icons.close,
                              size: 14,
                              color: accent.withAlpha(180),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              }),
              // "+" chip to add another time
              InkWell(
                onTap: onAddSchedule,
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(160),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: accent.withAlpha(60)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.add, size: 14, color: accent),
                      const SizedBox(width: 4),
                      Text(
                        'Добавить',
                        style: TextStyle(
                          fontSize: 13,
                          color: accent,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],

        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: _FieldButton(
                label: 'С даты',
                icon: Icons.event,
                value: formatSmartDate(form.startDate),
                onTap: () => onPickDate(isEnd: false),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),
        Row(
          children: [
            Icon(Icons.event_busy, size: 18, color: accent),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Дата окончания',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ),
            Switch(
              value: form.hasEndDate,
              activeThumbColor: accent,
              onChanged: (v) {
                form.hasEndDate = v;
                onChanged();
              },
            ),
          ],
        ),
        if (form.hasEndDate) ...[
          const SizedBox(height: 6),
          _FieldButton(
            label: 'По дату',
            icon: Icons.event_available,
            value: formatSmartDate(form.endDate),
            onTap: () => onPickDate(isEnd: true),
          ),
        ],

        const SizedBox(height: 12),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.check, size: 18),
            label: Text(saveLabel),
            style: FilledButton.styleFrom(
              backgroundColor: accent,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Dose field (numeric input + unit dropdown, units depend on kind) ─────────

/// Builds the unit list for [kind], guaranteeing [selected] is present so the
/// dropdown never asserts on a value outside its items.
List<DoseUnit> _doseUnitsFor(PillKind? kind, DoseUnit selected) {
  final list = List<DoseUnit>.from(DoseUnit.forKind(kind));
  if (!list.contains(selected)) list.insert(0, selected);
  return list;
}

class _DoseField extends StatelessWidget {
  final _PillFormState form;
  final Color accent;
  final VoidCallback onChanged;

  const _DoseField({
    required this.form,
    required this.accent,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: form.doseAmountCtrl,
            keyboardType: TextInputType.number,
            // Перерисовываем, чтобы склонение единицы в дропдауне отражало
            // введённое количество (напр. «1 впрыск» → «3 впрыска»).
            onChanged: (_) => onChanged(),
            decoration: baseInputDecoration('Доза'),
          ),
        ),
        const SizedBox(width: 8),
        _DoseUnitDropdown(
          units: _doseUnitsFor(form.kind, form.doseUnit),
          value: form.doseUnit,
          count: form.doseValue,
          accent: accent,
          onChanged: (u) {
            form.doseUnit = u;
            form.doseUnitTouched = true;
            onChanged();
          },
        ),
      ],
    );
  }
}

/// Dropdown styled to match [baseInputDecoration] — used in the form and in the
/// on-demand intake dialog.
class _DoseUnitDropdown extends StatelessWidget {
  final List<DoseUnit> units;
  final DoseUnit value;
  final int count; // для корректного склонения единицы
  final Color accent;
  final ValueChanged<DoseUnit> onChanged;

  const _DoseUnitDropdown({
    required this.units,
    required this.value,
    required this.count,
    required this.accent,
    required this.onChanged,
  });

  static String _menuLabel(DoseUnit u, int count) =>
      u.id == 'none' ? 'другое' : DoseUnit.declensionByUnit(count, u);
  static String _fieldLabel(DoseUnit u, int count) =>
      u.id == 'none' ? 'ед.' : DoseUnit.declensionByUnit(count, u);

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<DoseUnit>(
      initialValue: value,
      onSelected: onChanged,
      enableFeedback: true,
      itemBuilder: (_) => units
          .map((u) => PopupMenuItem(value: u, child: Text(_menuLabel(u, count))))
          .toList(),
      child: Container(
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              _fieldLabel(value, count),
              style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                color: value.id == 'none'
                    ? ThemeColors.textPrimary.withAlpha(128)
                    : ThemeColors.textPrimary,
              ),
            ),
            Icon(Icons.expand_more, size: 22, color: accent),
          ],
        ),
      ),
    );
  }
}

// ─── Icon picker tile (opens iOS-style shape + colour picker) ─────────────────

class _IconPickerTile extends StatelessWidget {
  final PillKind? kind;
  final int? color;
  final Color accent;
  final VoidCallback onTap;

  const _IconPickerTile({
    required this.kind,
    required this.color,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final hasKind = kind != null && kind!.id.isNotEmpty;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: ThemeColors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            PillIcon(kind: kind, colorValue: color, fallback: accent, size: 44),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Иконка и вид',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: ThemeColors.textPrimary.withAlpha(128),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    hasKind ? kind!.name : 'Выберите форму и цвет',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            const Icon(
              Icons.chevron_right,
              color: ThemeColors.border,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Compact list tile for reminder in create sheet ───────────────────────────

class _ReminderListTile extends StatelessWidget {
  final Pill reminder;
  final Color accent;
  final VoidCallback onTap;

  const _ReminderListTile({
    required this.reminder,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          child: Row(
            children: [
              PillIcon(
                kind: reminder.kind,
                colorValue: reminder.color,
                fallback: accent,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.name,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                    Text(
                      [
                        if (reminder.doseLabel.isNotEmpty) reminder.doseLabel,
                        reminder.frequencyLabel,
                        if (reminder.frequencyType !=
                            PillFrequencyType.onDemand)
                          reminder.timeLabel,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: ThemeColors.border,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Sheet: детали конкретного препарата ─────────────────────────────────────

class PillDetailSheet extends StatefulWidget {
  final Pet profile;
  final Pill reminder;

  const PillDetailSheet({
    super.key,
    required this.profile,
    required this.reminder,
  });

  @override
  State<PillDetailSheet> createState() => _PillDetailSheetState();
}

class _PillDetailSheetState extends State<PillDetailSheet> {
  late Pill _reminder;
  bool _editing = false;
  bool _saving = false;

  // Edit form state (initialised lazily when edit mode is entered)
  _PillFormState? _form;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
  }

  @override
  void dispose() {
    _form?.dispose();
    super.dispose();
  }

  // ── View mode actions ────────────────────────────────────────────────────

  /// Логирует приём «по требованию»: спрашиваем дозу и время, затем добавляем
  /// запись в журнал.
  Future<void> _logOnDemandIntake() async {
    final result = await showOnDemandIntakeDialog(
      context,
      kind: _reminder.kind,
      defaultDoseValue: _reminder.doseValue,
      defaultDoseUnit: _reminder.doseUnit,
    );
    if (result == null) return;
    await PillReminderService().addOnDemandIntake(
      petId: widget.profile.id,
      reminderId: _reminder.id,
      time: result.time,
      doseValue: result.doseValue,
      doseUnit: result.doseUnit,
    );
    await _reloadReminder();
  }

  Future<void> _removeIntake(PillIntake intake) async {
    await PillReminderService().removeOnDemandIntake(
      petId: widget.profile.id,
      reminderId: _reminder.id,
      time: intake.time,
    );
    await _reloadReminder();
  }

  Future<void> _toggleSchedule(int scheduleIndex) async {
    final today = DateTime.now();
    final isTaken = _reminder.isScheduleTakenOnDay(today, scheduleIndex);
    if (isTaken) {
      await PillReminderService().markScheduleUntaken(
        petId: widget.profile.id,
        reminderId: _reminder.id,
        date: today,
        scheduleIndex: scheduleIndex,
      );
    } else {
      await PillReminderService().markScheduleTaken(
        petId: widget.profile.id,
        reminderId: _reminder.id,
        date: today,
        scheduleIndex: scheduleIndex,
      );
    }
    await _reloadReminder();
  }

  Future<void> _delete() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить напоминание?',
      message: 'Вся история приёмов тоже будет удалена.',
    );
    if (!confirmed) return;
    await PillReminderService().delete(
      petId: widget.profile.id,
      reminder: _reminder,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _markTaken(DateTime day) async {
    await PillReminderService().markTaken(
      petId: widget.profile.id,
      reminderId: _reminder.id,
      date: day,
    );
    await _reloadReminder();
  }

  Future<void> _reloadReminder() async {
    final fresh = await PetService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      final updated = fresh.pillReminders.firstWhere(
        (r) => r.id == _reminder.id,
        orElse: () => _reminder,
      );
      setState(() => _reminder = updated);
    }
  }

  // ── Edit mode ────────────────────────────────────────────────────────────

  void _enterEdit() {
    _form?.dispose();
    setState(() {
      _form = _PillFormState.fromReminder(_reminder);
      _editing = true;
    });
  }

  void _cancelEdit() {
    setState(() {
      _form?.dispose();
      _form = null;
      _editing = false;
    });
  }

  Future<void> _saveEdit() async {
    final form = _form!;
    final name = form.nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название препарата')),
      );
      return;
    }
    if (form.frequency == PillFrequencyType.weekdays && form.weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день')),
      );
      return;
    }
    if (form.schedules.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Добавьте хотя бы одно время приёма')),
      );
      return;
    }

    setState(() => _saving = true);

    final sortedSchedules = List.of(form.schedules)
      ..sort(
        (a, b) => a.hour != b.hour
            ? a.hour.compareTo(b.hour)
            : a.minute.compareTo(b.minute),
      );

    final updated = _reminder.copyWith(
      name: name,
      kind: form.kind,
      color: form.color,
      doseValue: form.doseValue,
      doseUnit: form.doseUnit,
      frequencyType: form.frequency,
      weekdays: form.frequency == PillFrequencyType.weekdays
          ? (List.of(form.weekdays)..sort())
          : [],
      schedules: sortedSchedules
          .map((t) => PillSchedule.fromTimeOfDay(t))
          .toList(),
      startDate: form.startDate,
      endDate: form.hasEndDate ? form.endDate : null,
      clearEndDate: !form.hasEndDate,
    );

    await PillReminderService().update(
      petId: widget.profile.id,
      updated: updated,
    );

    if (!mounted) return;
    setState(() {
      _reminder = updated;
      _editing = false;
      _form?.dispose();
      _form = null;
      _saving = false;
    });
  }

  Future<void> _addSchedule() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 9, minute: 0),
    );
    if (picked != null) setState(() => _form!.schedules.add(picked));
  }

  Future<void> _editSchedule(int index) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _form!.schedules[index],
    );
    if (picked != null) setState(() => _form!.schedules[index] = picked);
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final form = _form!;
    final initial = isEnd ? form.endDate : form.startDate;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        form.endDate = picked;
      } else {
        form.startDate = picked;
        if (form.hasEndDate && form.endDate.isBefore(form.startDate)) {
          form.endDate = form.startDate.add(const Duration(days: 30));
        }
      }
    });
  }

  // ── Helpers ──────────────────────────────────────────────────────────────

  List<DateTime> _scheduledDays(int days) {
    final today = DateTime.now();
    final result = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      if (_reminder.isScheduledForDay(d)) result.add(d);
    }
    return result;
  }

  List<DateTime> _missedDays(int days) =>
      _scheduledDays(days).where((d) => !_reminder.isTakenOnDay(d)).toList();

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return DateFormat('d MMM', 'ru').format(d);
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: _editing ? 'Редактирование' : 'Препарат',
      centerTitle: true,
      onBack: _editing ? _cancelEdit : () => Navigator.of(context).pop(false),
      initialSize: 0.75,
      minSize: 0.5,
      maxSize: 1.0,
      actions: _editing
          ? null
          : [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                color: accent,
                onPressed: _enterEdit,
                tooltip: 'Редактировать',
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline),
                color: ThemeColors.dangerZone,
                onPressed: _delete,
              ),
            ],
      body: _editing ? _buildEditBody(accent) : _buildViewBody(accent),
    );
  }

  // ── View body ────────────────────────────────────────────────────────────

  Widget _buildViewBody(Color accent) {
    final today = DateTime.now();
    final scheduledToday = _reminder.isScheduledForDay(today);
    final isOnDemand = _reminder.frequencyType == PillFrequencyType.onDemand;
    // «По требованию» нельзя пропустить — раздел пропусков не показываем.
    final missedDays = isOnDemand ? <DateTime>[] : _missedDays(30);
    final todayIntakes = isOnDemand
        ? _reminder.intakesOnDay(today)
        : <PillIntake>[];
    final journalIntakes = isOnDemand ? _recentIntakes(today) : <PillIntake>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero ────────────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              PillIcon(
                kind: _reminder.kind,
                colorValue: _reminder.color,
                fallback: accent,
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                _reminder.name,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (_reminder.doseLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  _reminder.doseLabel,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium!.copyWith(color: ThemeColors.border),
                ),
              ],
            ],
          ),
        ),

        const SizedBox(height: 20),

        // ── Schedule info ────────────────────────────────────────────────────
        GlassPlate(
          padding: 0,
          child: Column(
            children: [
              if (_reminder.kind != null) ...[
                _DetailRow(
                  icon: _reminder.kind!.icon,
                  iconColor: _reminder.color != null
                      ? Color(_reminder.color!)
                      : accent,
                  label: _reminder.kind!.name,
                ),
                Divider(
                  height: 1,
                  indent: 46,
                  color: ThemeColors.border.withAlpha(60),
                ),
              ],
              _DetailRow(
                icon: Icons.repeat,
                iconColor: accent,
                label: _reminder.frequencyLabel,
              ),
              Divider(
                height: 1,
                indent: 46,
                color: ThemeColors.border.withAlpha(60),
              ),
              // Show each time as a separate row (skip for on-demand — no schedule).
              if (!isOnDemand) ...[
                ..._reminder.schedules.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final isLast = i == _reminder.schedules.length - 1;
                  return Column(
                    children: [
                      _DetailRow(
                        icon: Icons.access_time,
                        iconColor: accent,
                        label: s.label,
                      ),
                      if (!isLast)
                        Divider(
                          height: 1,
                          indent: 46,
                          color: ThemeColors.border.withAlpha(60),
                        ),
                    ],
                  );
                }),
                Divider(
                  height: 1,
                  indent: 46,
                  color: ThemeColors.border.withAlpha(60),
                ),
              ],
              _DetailRow(
                icon: Icons.event,
                iconColor: accent,
                label: 'С ${formatSmartDate(_reminder.startDate)}',
                sublabel: _reminder.endDate != null
                    ? 'по ${formatSmartDate(_reminder.endDate!)}'
                    : null,
              ),
            ],
          ),
        ),

        const SizedBox(height: 12),

        // ── Today ────────────────────────────────────────────────────────────
        if (scheduledToday) ...[
          Text('Сегодня', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (isOnDemand) ...[
            // «По требованию» — журнал приёмов: каждая отметка со временем и
            // дозой, можно добавить несколько за день.
            _AddIntakeButton(accent: accent, onTap: _logOnDemandIntake),
            if (todayIntakes.isNotEmpty) ...[
              const SizedBox(height: 8),
              _IntakeList(
                intakes: todayIntakes,
                accent: accent,
                onRemove: _removeIntake,
              ),
            ],
          ] else
            // One toggle per schedule — each is toggled independently.
            ..._reminder.schedules.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final taken = _reminder.isScheduleTakenOnDay(today, i);
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _TodayToggle(
                  isTaken: taken,
                  time: s.label,
                  accent: accent,
                  onTap: () => _toggleSchedule(i),
                ),
              );
            }),
          const SizedBox(height: 4),
        ],

        // ── Missed (30 days) ─────────────────────────────────────────────────
        if (missedDays.isNotEmpty) ...[
          Text(
            'Пропущено (30 дней)',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          GlassPlate(
            padding: 0,
            child: Column(
              children: missedDays.asMap().entries.map((entry) {
                final i = entry.key;
                final day = entry.value;
                final isFirst = i == 0;
                return Column(
                  children: [
                    if (!isFirst)
                      Divider(
                        height: 1,
                        indent: 16,
                        color: ThemeColors.border.withAlpha(60),
                      ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 80,
                            child: Text(
                              _dayLabel(day),
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color: isFirst
                                        ? ThemeColors.textPrimary
                                        : ThemeColors.border,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: ThemeColors.warning.mainColor.withAlpha(200),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Пропущено',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color: ThemeColors.warning.mainColor,
                                  ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () => _markTaken(day),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColors.ok.mainColor.withAlpha(20),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: ThemeColors.ok.mainColor.withAlpha(80),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.check,
                                    size: 14,
                                    color: ThemeColors.ok.mainColor,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Принято',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: ThemeColors.ok.mainColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),
        ] else if (!isOnDemand) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.check_circle_outline,
                  color: ThemeColors.ok.mainColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Нет пропусков за последние 30 дней',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: ThemeColors.ok.mainColor,
                  ),
                ),
              ],
            ),
          ),
        ],

        // ── Журнал приёмов «по требованию» (последние 30 дней) ───────────────
        if (isOnDemand && journalIntakes.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            'Журнал приёмов',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _IntakeList(
            intakes: journalIntakes,
            accent: accent,
            onRemove: _removeIntake,
            showDay: true,
          ),
        ],
      ],
    );
  }

  /// On-demand intakes from the last 30 days, excluding today, newest first.
  List<PillIntake> _recentIntakes(DateTime today) {
    final t0 = DateTime(today.year, today.month, today.day);
    final start = t0.subtract(const Duration(days: 30));
    return _reminder.intakes
        .where((i) => i.time.isAfter(start) && i.time.isBefore(t0))
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
  }

  // ── Edit body ────────────────────────────────────────────────────────────

  Widget _buildEditBody(Color accent) {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: _PillForm(
          form: _form!,
          accent: accent,
          saving: _saving,
          onAddSchedule: _addSchedule,
          onEditSchedule: _editSchedule,
          onPickDate: _pickDate,
          onSave: _saveEdit,
          onChanged: () => setState(() {}),
          saveLabel: 'Сохранить',
        ),
      ),
    );
  }
}

// ─── Today toggle ─────────────────────────────────────────────────────────────

class _TodayToggle extends StatelessWidget {
  final bool isTaken;
  final String time;
  final Color accent;
  final VoidCallback onTap;

  const _TodayToggle({
    required this.isTaken,
    required this.time,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isTaken ? ThemeColors.ok.mainColor : Colors.white,
        border: Border.all(
          color: isTaken
              ? ThemeColors.ok.mainColor
              : ThemeColors.border.withAlpha(100),
        ),
        boxShadow: isTaken
            ? [
                BoxShadow(
                  color: ThemeColors.ok.mainColor.withAlpha(60),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ]
            : [],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
            child: Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 18,
                  color: isTaken ? Colors.white : ThemeColors.border,
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: isTaken ? Colors.white : ThemeColors.textPrimary,
                  ),
                ),
                const Spacer(),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isTaken
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    key: ValueKey(isTaken),
                    color: isTaken ? Colors.white : accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  isTaken ? 'Принято' : 'Отметить',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: isTaken ? Colors.white : ThemeColors.textPrimary,
                    fontWeight: FontWeight.w600,
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

// ─── On-demand intake log ─────────────────────────────────────────────────────

String _intakeDayLabel(DateTime d) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(d.year, d.month, d.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Сегодня';
  if (diff == 1) return 'Вчера';
  return DateFormat('d MMM', 'ru').format(d);
}

class _AddIntakeButton extends StatelessWidget {
  final Color accent;
  final VoidCallback onTap;

  const _AddIntakeButton({required this.accent, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onTap,
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Дать препарат'),
        style: FilledButton.styleFrom(
          backgroundColor: accent,
          padding: const EdgeInsets.symmetric(vertical: 14),
        ),
      ),
    );
  }
}

class _IntakeList extends StatelessWidget {
  final List<PillIntake> intakes;
  final Color accent;
  final ValueChanged<PillIntake> onRemove;
  final bool showDay;

  const _IntakeList({
    required this.intakes,
    required this.accent,
    required this.onRemove,
    this.showDay = false,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 0,
      child: Column(
        children: [
          for (var i = 0; i < intakes.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                indent: 16,
                color: ThemeColors.border.withAlpha(60),
              ),
            _IntakeRow(
              intake: intakes[i],
              showDay: showDay,
              onRemove: () => onRemove(intakes[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _IntakeRow extends StatelessWidget {
  final PillIntake intake;
  final bool showDay;
  final VoidCallback onRemove;

  const _IntakeRow({
    required this.intake,
    required this.showDay,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = showDay
        ? '${_intakeDayLabel(intake.time)}, ${intake.timeLabel}'
        : intake.timeLabel;
    return ListTile(
      leading: Icon(
        Icons.check_circle,
        size: 18,
        color: ThemeColors.ok.mainColor,
      ),
      title: Row(
        spacing: 6,
        children: [
          Text(title, style: Theme.of(context).textTheme.bodyMedium),
          if (intake.doseLabel.isNotEmpty)
            Text(
              '(${intake.doseLabel})',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium!.copyWith(color: ThemeColors.border),
            ),
        ],
      ),

      trailing: IconButton(
        constraints: BoxConstraints(maxWidth: 36, maxHeight: 36),
        onPressed: onRemove,
        icon: Icon(Icons.close, size: 12, color: ThemeColors.border),
      ),
    );

    //   Row(
    //     children: [
    //       Icon(Icons.check_circle, size: 18, color: ThemeColors.ok.mainColor),
    //       const SizedBox(width: 12),
    //       Expanded(
    //         child: Column(
    //           crossAxisAlignment: CrossAxisAlignment.start,
    //           children: [
    //             Text(title, style: Theme.of(context).textTheme.bodyMedium),
    //             if (intake.dose.isNotEmpty) ...[
    //               const SizedBox(height: 2),
    //               Text(
    //                 intake.dose,
    //                 style: Theme.of(
    //                   context,
    //                 ).textTheme.bodySmall!.copyWith(color: ThemeColors.border),
    //               ),
    //             ],
    //           ],
    //         ),
    //       ),
    //       GestureDetector(
    //         onTap: onRemove,
    //         behavior: HitTestBehavior.opaque,
    //         child: const Padding(
    //           padding: EdgeInsets.all(4),
    //           child: Icon(Icons.close, size: 18, color: ThemeColors.border),
    //         ),
    //       ),
    //     ],
    //   ),
    // );
  }
}

// ─── On-demand intake dialog (asks dose + time on each intake) ────────────────

Future<({DateTime time, int doseValue, DoseUnit doseUnit})?>
showOnDemandIntakeDialog(
  BuildContext context, {
  required PillKind? kind,
  required int defaultDoseValue,
  required DoseUnit defaultDoseUnit,
}) {
  return showDialog<({DateTime time, int doseValue, DoseUnit doseUnit})>(
    context: context,
    builder: (_) => _OnDemandIntakeDialog(
      kind: kind,
      defaultDoseValue: defaultDoseValue,
      defaultDoseUnit: defaultDoseUnit,
    ),
  );
}

class _OnDemandIntakeDialog extends StatefulWidget {
  final PillKind? kind;
  final int defaultDoseValue;
  final DoseUnit defaultDoseUnit;

  const _OnDemandIntakeDialog({
    required this.kind,
    required this.defaultDoseValue,
    required this.defaultDoseUnit,
  });

  @override
  State<_OnDemandIntakeDialog> createState() => _OnDemandIntakeDialogState();
}

class _OnDemandIntakeDialogState extends State<_OnDemandIntakeDialog> {
  late final TextEditingController _amountCtrl;
  late DoseUnit _unit;
  late TimeOfDay _time;

  int get _value => int.tryParse(_amountCtrl.text.trim()) ?? 0;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(
      text: widget.defaultDoseValue == 0
          ? ''
          : widget.defaultDoseValue.toString(),
    );
    _unit = widget.defaultDoseUnit.id == 'none'
        ? DoseUnit.forKind(widget.kind).first
        : widget.defaultDoseUnit;
    _time = TimeOfDay.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final now = DateTime.now();
    final time = DateTime(
      now.year,
      now.month,
      now.day,
      _time.hour,
      _time.minute,
    );
    Navigator.of(
      context,
    ).pop((time: time, doseValue: _value, doseUnit: _unit));
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    return AlertDialog(
      title: const Text('Отметить приём'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GlassPlate(
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountCtrl,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    onChanged: (_) => setState(() {}),
                    decoration: baseInputDecoration('Доза'),
                  ),
                ),
                const SizedBox(width: 8),
                _DoseUnitDropdown(
                  units: _doseUnitsFor(widget.kind, _unit),
                  value: _unit,
                  count: _value,
                  accent: accent,
                  onChanged: (u) => setState(() => _unit = u),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          GlassCard(
            callback: _pickTime,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.access_time, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text('Время', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    _time.format(context),
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _save,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: const Text('Сохранить'),
        ),
      ],
    );
  }
}

// ─── Detail row ───────────────────────────────────────────────────────────────

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;

  const _DetailRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, size: 18, color: iconColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodyMedium),
                if (sublabel != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    sublabel!,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall!.copyWith(color: ThemeColors.border),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Weekday picker ───────────────────────────────────────────────────────────

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final Color accent;
  final ValueChanged<Set<int>> onChanged;

  const _WeekdayPicker({
    required this.selected,
    required this.accent,
    required this.onChanged,
  });

  static const _days = [
    (1, 'Пн'),
    (2, 'Вт'),
    (3, 'Ср'),
    (4, 'Чт'),
    (5, 'Пт'),
    (6, 'Сб'),
    (7, 'Вс'),
  ];

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: _days.map((d) {
        final (num, label) = d;
        final isSelected = selected.contains(num);
        return SoftGlassBadge(
          color: accent,
          label: label,
          selected: isSelected,
          onChanged: (_) {
            final next = Set<int>.from(selected);
            if (isSelected) {
              next.remove(num);
            } else {
              next.add(num);
            }
            onChanged(next);
          },
        );
      }).toList(),
    );
  }
}

// ─── Field button ─────────────────────────────────────────────────────────────

class _FieldButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final String value;
  final VoidCallback onTap;

  const _FieldButton({
    required this.label,
    required this.icon,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(180),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withAlpha(220)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: context.watch<AppearanceController>().primaryColor,
                ),
                const SizedBox(width: 6),
                Text(value),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
