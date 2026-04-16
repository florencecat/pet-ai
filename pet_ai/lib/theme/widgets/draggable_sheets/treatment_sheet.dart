import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/services/treatment_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

/// Шит для добавления и просмотра мед. мероприятий.
class TreatmentSheet extends StatefulWidget {
  final PetProfile profile;

  const TreatmentSheet({super.key, required this.profile});

  @override
  State<TreatmentSheet> createState() =>
      _TreatmentSheetState();
}

class _TreatmentSheetState extends State<TreatmentSheet> {
  TreatmentKind _kind = TreatmentKind.rabies;
  final _nameCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  late DateTime _nextDate;
  int _remindBeforeDays = 7;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nextDate = _date.add(_kind.defaultInterval);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _setKind(TreatmentKind k) {
    setState(() {
      _kind = k;
      // Пересчитываем nextDate относительно текущей date
      _nextDate = _date.add(k.defaultInterval);
    });
  }

  Future<void> _pickDate({required bool isNext}) async {
    final initial = isNext ? _nextDate : _date;
    final firstDate = isNext
        ? DateTime.now().subtract(const Duration(days: 30))
        : DateTime.now().subtract(const Duration(days: 365 * 5));
    final lastDate = DateTime.now().add(const Duration(days: 365 * 5));

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: firstDate,
      lastDate: lastDate,
      locale: const Locale('ru'),
    );
    if (picked == null) return;

    setState(() {
      if (isNext) {
        _nextDate = picked;
      } else {
        _date = picked;
        // Обновляем nextDate, если он меньше date
        if (_nextDate.isBefore(_date)) {
          _nextDate = _date.add(_kind.defaultInterval);
        }
      }
    });
  }

  Future<void> _save() async {
    if (_kind == TreatmentKind.vaccine && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Введите название прививки')),
      );
      return;
    }

    setState(() => _saving = true);
    await TreatmentService().addTreatment(
      petId: widget.profile.id,
      kind: _kind,
      date: _date,
      nextDate: _nextDate,
      name: _nameCtrl.text.trim(),
      remindBeforeDays: _remindBeforeDays,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  Future<void> _delete(TreatmentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text(
          'Запись будет удалена. Связанное напоминание тоже будет отменено.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style:
                FilledButton.styleFrom(backgroundColor: ThemeColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TreatmentService().deleteTreatment(widget.profile.id, entry);
    if (!mounted) return;
    setState(() {
      widget.profile.treatmentHistory.entries.removeWhere(
        (e) => e.date == entry.date && e.kind == entry.kind && e.name == entry.name,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final history = widget.profile.treatmentHistory;
    final entries = List.of(history.entries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return DraggableSheet(
      title: 'Прививки и обработки',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(false),
      initialSize: 0.85,
      minSize: 0.4,
      maxSize: 1.0,
      actions: [
        IconButton(
          icon: const Icon(Icons.check),
          color: ThemeColors.primary,
          onPressed: _saving ? null : _save,
        ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ─── Форма добавления ──────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Тип мероприятия',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TreatmentKind.values.map((k) {
                      final selected = _kind == k;
                      return ChoiceChip(
                        label: Text(k.shortLabel),
                        avatar: Icon(k.icon, size: 16,
                          color: selected ? Colors.white : k.color,
                        ),
                        selected: selected,
                        selectedColor: k.color,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : ThemeColors.textPrimary,
                        ),
                        onSelected: (_) => _setKind(k),
                      );
                    }).toList(),
                  ),

                  if (_kind == TreatmentKind.vaccine) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Название прививки',
                        hintText: 'Напр. DHPPi+L, бордетеллёз...',
                        border: InputBorder.none,
                      ),
                    ),
                  ],

                  const SizedBox(height: 12),

                  // Date row
                  Row(
                    children: [
                      Expanded(
                        child: _DateField(
                          label: 'Когда сделано',
                          icon: Icons.event,
                          date: _date,
                          onTap: () => _pickDate(isNext: false),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _DateField(
                          label: 'Следующее',
                          icon: Icons.notifications_active_outlined,
                          date: _nextDate,
                          onTap: () => _pickDate(isNext: true),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 12),

                  // Remind before
                  Row(
                    children: [
                      const Icon(Icons.alarm,
                          size: 18, color: ThemeColors.primary),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Напомнить за (дн.):',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color: ThemeColors.primary,
                        onPressed: _remindBeforeDays > 0
                            ? () => setState(() => _remindBeforeDays -= 1)
                            : null,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$_remindBeforeDays',
                          textAlign: TextAlign.center,
                          style: Theme.of(context)
                              .textTheme
                              .bodyLarge!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color: ThemeColors.primary,
                        onPressed: _remindBeforeDays < 60
                            ? () => setState(() => _remindBeforeDays += 1)
                            : null,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ─── История ────────────────────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Записей пока нет',
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
                'История',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...entries.map((entry) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GlassPlate(
                child: ListTile(
                  leading: Icon(entry.kind.icon, color: entry.kind.color),
                  title: Text(entry.displayName),
                  subtitle: Text(
                    'Сделано: ${DateFormat('dd.MM.yyyy').format(entry.date)} • '
                    'Следующее: ${DateFormat('dd.MM.yyyy').format(entry.nextDate)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline,
                        color: ThemeColors.danger),
                    onPressed: () => _delete(entry),
                  ),
                ),
              ),
            )),
          ],
        ],
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final String label;
  final IconData icon;
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.icon,
    required this.date,
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
                Icon(icon, size: 16, color: ThemeColors.primary),
                const SizedBox(width: 6),
                Text(DateFormat('dd.MM.yyyy').format(date)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
