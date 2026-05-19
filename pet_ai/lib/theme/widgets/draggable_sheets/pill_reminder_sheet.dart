import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/pill_reminder.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/pill_reminder_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/base_widgets.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

// ─── Sheet: список + создание напоминаний ────────────────────────────────────

class PillReminderSheet extends StatefulWidget {
  final PetProfile profile;

  const PillReminderSheet({super.key, required this.profile});

  @override
  State<PillReminderSheet> createState() => _PillReminderSheetState();
}

class _PillReminderSheetState extends State<PillReminderSheet> {
  final _nameCtrl = TextEditingController();
  final _doseCtrl = TextEditingController();

  PillFrequencyType _frequency = PillFrequencyType.daily;
  final Set<int> _weekdays = {1, 2, 3, 4, 5};
  TimeOfDay _time = const TimeOfDay(hour: 9, minute: 0);
  DateTime _startDate = DateTime.now();
  bool _hasEndDate = false;
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _saving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _doseCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  Future<void> _pickDate({required bool isEnd}) async {
    final initial = isEnd ? _endDate : _startDate;
    final first = DateTime.now().subtract(const Duration(days: 30));
    final last = DateTime.now().add(const Duration(days: 365 * 5));
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: first,
      lastDate: last,
      locale: const Locale('ru'),
    );
    if (picked == null) return;
    setState(() {
      if (isEnd) {
        _endDate = picked;
      } else {
        _startDate = picked;
        if (_hasEndDate && _endDate.isBefore(_startDate)) {
          _endDate = _startDate.add(const Duration(days: 30));
        }
      }
    });
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название препарата')),
      );
      return;
    }
    if (_frequency == PillFrequencyType.weekdays && _weekdays.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Выберите хотя бы один день')),
      );
      return;
    }

    setState(() => _saving = true);

    final reminder = PillReminder(
      id: UniqueKey().toString(),
      name: name,
      dose: _doseCtrl.text.trim(),
      frequencyType: _frequency,
      weekdays: _frequency == PillFrequencyType.weekdays
          ? (List.of(_weekdays)..sort())
          : [],
      hour: _time.hour,
      minute: _time.minute,
      startDate: _startDate,
      endDate: _hasEndDate ? _endDate : null,
      takenDates: const [],
    );

    await PillReminderService().add(
      petId: widget.profile.id,
      reminder: reminder,
    );
    if (!mounted) return;

    // Stay in sheet — reload list and clear form
    final fresh = await ProfileService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() {
        widget.profile.pillReminders
          ..clear()
          ..addAll(fresh.pillReminders);
        _nameCtrl.clear();
        _doseCtrl.clear();
        _frequency = PillFrequencyType.daily;
        _weekdays
          ..clear()
          ..addAll({1, 2, 3, 4, 5});
        _time = const TimeOfDay(hour: 9, minute: 0);
        _startDate = DateTime.now();
        _hasEndDate = false;
        _endDate = DateTime.now().add(const Duration(days: 30));
        _saving = false;
      });
    } else {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _openDetail(PillReminder reminder) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PillDetailSheet(
        profile: widget.profile,
        reminder: reminder,
      ),
    );
    if (updated == true && mounted) {
      // Refresh local list if the reminder was deleted inside
      final fresh = await ProfileService().loadProfile(widget.profile.id);
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
          // ─── Форма ──────────────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _nameCtrl,
                    decoration: baseInputDecoration('Название препарата'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _doseCtrl,
                    decoration: baseInputDecoration('Доза (необязательно)'),
                    textCapitalization: TextCapitalization.sentences,
                  ),
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
                        selected: _frequency == f,
                        onChanged: (_) => setState(() => _frequency = f),
                      );
                    }).toList(),
                  ),
                  if (_frequency == PillFrequencyType.weekdays) ...[
                    const SizedBox(height: 10),
                    Text('Дни недели', style: Theme.of(context).textTheme.bodySmall),
                    const SizedBox(height: 6),
                    _WeekdayPicker(
                      selected: _weekdays,
                      accent: accent,
                      onChanged: (days) => setState(() {
                        _weekdays..clear()..addAll(days);
                      }),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _FieldButton(
                          label: 'Время',
                          icon: Icons.access_time,
                          value: _time.format(context),
                          onTap: _pickTime,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _FieldButton(
                          label: 'С даты',
                          icon: Icons.event,
                          value: formatSmartDate(_startDate),
                          onTap: () => _pickDate(isEnd: false),
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
                        child: Text('Дата окончания',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      Switch(
                        value: _hasEndDate,
                        onChanged: (v) => setState(() => _hasEndDate = v),
                        activeThumbColor: accent,
                      ),
                    ],
                  ),
                  if (_hasEndDate) ...[
                    const SizedBox(height: 6),
                    _FieldButton(
                      label: 'По дату',
                      icon: Icons.event_available,
                      value: formatSmartDate(_endDate),
                      onTap: () => _pickDate(isEnd: true),
                    ),
                  ],
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),
                      style: FilledButton.styleFrom(
                        backgroundColor: accent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── Список существующих напоминаний ────────────────────────────
          if (reminders.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Напоминаний пока нет',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: ThemeColors.border),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text('Активные напоминания',
                  style: Theme.of(context).textTheme.titleMedium),
            ),
            ...reminders.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GlassPlate(
                  padding: 0,
                  child: InkWell(
                    onTap: () => _openDetail(r),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          vertical: 12, horizontal: 16),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: accent.withAlpha(20),
                            ),
                            child: Icon(Icons.medication_outlined,
                                color: accent, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(r.name,
                                    style: Theme.of(context).textTheme.titleSmall),
                                Text(
                                  [
                                    if (r.dose.isNotEmpty) r.dose,
                                    r.frequencyLabel,
                                    r.timeLabel,
                                  ].join(' · '),
                                  style: Theme.of(context).textTheme.bodySmall,
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.chevron_right,
                              color: ThemeColors.border, size: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Sheet: детали конкретного препарата ─────────────────────────────────────

class PillDetailSheet extends StatefulWidget {
  final PetProfile profile;
  final PillReminder reminder;

  const PillDetailSheet({
    super.key,
    required this.profile,
    required this.reminder,
  });

  @override
  State<PillDetailSheet> createState() => _PillDetailSheetState();
}

class _PillDetailSheetState extends State<PillDetailSheet> {
  late PillReminder _reminder;

  @override
  void initState() {
    super.initState();
    _reminder = widget.reminder;
  }

  Future<void> _toggleToday() async {
    final today = DateTime.now();
    final taken = _reminder.isTakenOnDay(today);
    if (taken) {
      await PillReminderService().markUntaken(
        petId: widget.profile.id,
        reminderId: _reminder.id,
        date: today,
      );
    } else {
      await PillReminderService().markTaken(
        petId: widget.profile.id,
        reminderId: _reminder.id,
        date: today,
      );
    }
    // Reload reminder state
    final fresh = await ProfileService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      final updated = fresh.pillReminders.firstWhere(
        (r) => r.id == _reminder.id,
        orElse: () => _reminder,
      );
      setState(() => _reminder = updated);
    }
  }

  Future<void> _delete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text('Всё история приёмов тоже будет удалена.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.dangerZone),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await PillReminderService().delete(
      petId: widget.profile.id,
      reminder: _reminder,
    );
    if (mounted) Navigator.of(context).pop(true);
  }

  /// Last [days] days where the reminder was scheduled, newest first.
  List<DateTime> _scheduledDays(int days) {
    final today = DateTime.now();
    final result = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(today.year, today.month, today.day)
          .subtract(Duration(days: i));
      if (_reminder.isScheduledForDay(d)) result.add(d);
    }
    return result;
  }

  /// Returns only days in [_scheduledDays] where the pill was NOT taken (missed).
  List<DateTime> _missedDays(int days) {
    return _scheduledDays(days)
        .where((d) => !_reminder.isTakenOnDay(d))
        .toList();
  }

  Future<void> _markTaken(DateTime day) async {
    await PillReminderService().markTaken(
      petId: widget.profile.id,
      reminderId: _reminder.id,
      date: day,
    );
    final fresh = await ProfileService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      final updated = fresh.pillReminders.firstWhere(
        (r) => r.id == _reminder.id,
        orElse: () => _reminder,
      );
      setState(() => _reminder = updated);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final today = DateTime.now();
    final isTakenToday = _reminder.isTakenOnDay(today);
    final scheduledToday = _reminder.isScheduledForDay(today);
    final missedDays = _missedDays(30);

    return DraggableSheet(
      title: 'Препарат',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(false),
      initialSize: 0.75,
      minSize: 0.5,
      maxSize: 0.95,
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          color: ThemeColors.dangerZone,
          onPressed: _delete,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ──────────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: accent.withAlpha(20),
                    border: Border.all(color: accent.withAlpha(60), width: 1.5),
                  ),
                  child: Icon(Icons.medication_outlined, color: accent, size: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  _reminder.name,
                  style: Theme.of(context).textTheme.headlineSmall!
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                if (_reminder.dose.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    _reminder.dose,
                    style: Theme.of(context).textTheme.bodyMedium!
                        .copyWith(color: ThemeColors.border),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Расписание ────────────────────────────────────────────────────
          GlassPlate(
            padding: 0,
            child: Column(
              children: [
                _DetailRow(
                  icon: Icons.repeat,
                  iconColor: accent,
                  label: _reminder.frequencyLabel,
                ),
                Divider(height: 1, indent: 46, color: ThemeColors.border.withAlpha(60)),
                _DetailRow(
                  icon: Icons.access_time,
                  iconColor: accent,
                  label: _reminder.timeLabel,
                ),
                Divider(height: 1, indent: 46, color: ThemeColors.border.withAlpha(60)),
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

          // ── Сегодня ───────────────────────────────────────────────────────
          if (scheduledToday) ...[
            Text('Сегодня', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _TodayToggle(
              isTaken: isTakenToday,
              time: _reminder.timeLabel,
              accent: accent,
              onTap: _toggleToday,
            ),
            const SizedBox(height: 12),
          ],

          // ── Пропущенные (30 дней) ────────────────────────────────────────
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
                            // Day label
                            SizedBox(
                              width: 80,
                              child: Text(
                                _dayLabel(day),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
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
                              color: ThemeColors.warning.mainColor
                                  .withAlpha(200),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Пропущено',
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall!
                                    .copyWith(
                                      color: ThemeColors.warning.mainColor,
                                    ),
                              ),
                            ),
                            // Mark as taken button
                            GestureDetector(
                              onTap: () => _markTaken(day),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: ThemeColors.ok.mainColor
                                      .withAlpha(20),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: ThemeColors.ok.mainColor
                                        .withAlpha(80),
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
          ] else ...[
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
        ],
      ),
    );
  }

  String _dayLabel(DateTime d) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final day = DateTime(d.year, d.month, d.day);
    final diff = today.difference(day).inDays;
    if (diff == 0) return 'Сегодня';
    if (diff == 1) return 'Вчера';
    return DateFormat('d MMM', 'ru').format(d);
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
                    color:
                        isTaken ? Colors.white : accent,
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
                    style: Theme.of(context).textTheme.bodySmall!
                        .copyWith(color: ThemeColors.border),
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

// ─── Выбор дней недели ────────────────────────────────────────────────────────

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
    (1, 'Пн'), (2, 'Вт'), (3, 'Ср'), (4, 'Чт'),
    (5, 'Пт'), (6, 'Сб'), (7, 'Вс'),
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

// ─── Кнопка-поле ─────────────────────────────────────────────────────────────

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
