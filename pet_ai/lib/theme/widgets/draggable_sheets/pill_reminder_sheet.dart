import 'package:flutter/material.dart';
import 'package:pet_ai/models/pill_reminder.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/pill_reminder_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/base_widgets.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

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
  final Set<int> _weekdays = {1, 2, 3, 4, 5}; // Пн–Пт by default
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
    final picked = await showTimePicker(
      context: context,
      initialTime: _time,
    );
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
    Navigator.of(context).pop(true);
  }

  Future<void> _delete(PillReminder reminder) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить напоминание?'),
        content: const Text(
          'Напоминание будет удалено. Связанное уведомление тоже отменится.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeColors.dangerZone,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    await PillReminderService().delete(
      petId: widget.profile.id,
      reminder: reminder,
    );
    if (!mounted) return;
    setState(() {
      widget.profile.pillReminders.removeWhere((r) => r.id == reminder.id);
    });
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final reminders = List.of(widget.profile.pillReminders)
      ..sort((a, b) => a.name.compareTo(b.name));

    return DraggableSheet(
      title: 'Препараты',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(false),
      initialSize: 0.9,
      minSize: 0.5,
      maxSize: 1.0,
      actions: [
        IconButton(
          icon: const Icon(Icons.check),
          color: accent,
          onPressed: _saving ? null : _save,
        ),
      ],
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
                  Text(
                    'Периодичность',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                    Text(
                      'Дни недели',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    _WeekdayPicker(
                      selected: _weekdays,
                      accent: accent,
                      onChanged: (days) => setState(() {
                        _weekdays
                          ..clear()
                          ..addAll(days);
                      }),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Time + Start date row
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

                  // End date toggle
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
                style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                  color: ThemeColors.border,
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(
                'Активные напоминания',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...reminders.map(
              (r) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GlassPlate(
                  child: ListTile(
                    leading: Icon(
                      Icons.medication_outlined,
                      color: accent,
                    ),
                    title: Text(r.name),
                    subtitle: Text(
                      [
                        if (r.dose.isNotEmpty) r.dose,
                        r.frequencyLabel,
                        r.timeLabel,
                      ].join(' · '),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    trailing: IconButton(
                      icon: const Icon(
                        Icons.delete_outline,
                        color: ThemeColors.dangerZone,
                      ),
                      onPressed: () => _delete(r),
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
