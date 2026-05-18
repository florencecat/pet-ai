import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/services/treatment_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/base_widgets.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

// ─── Sheet: добавление + история всех обработок ──────────────────────────────

class TreatmentSheet extends StatefulWidget {
  final PetProfile profile;
  final TreatmentKind presetKind;

  const TreatmentSheet({
    super.key,
    required this.profile,
    this.presetKind = TreatmentKind.rabies,
  });

  @override
  State<TreatmentSheet> createState() => _TreatmentSheetState();
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
    _kind = widget.presetKind;
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
        _nextDate = picked.add(_kind.defaultInterval);
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

  void _openDetail(TreatmentEntry entry) async {
    // Collect all entries of the same kind (+name for vaccines)
    final related = widget.profile.treatmentHistory.entries
        .where((e) =>
            e.kind == entry.kind &&
            (entry.kind != TreatmentKind.vaccine || e.name == entry.name))
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentDetailSheet(
        profile: widget.profile,
        kind: entry.kind,
        vaccineName: entry.kind == TreatmentKind.vaccine ? entry.name : null,
        entries: related,
        onDeleted: (deleted) {
          setState(() {
            widget.profile.treatmentHistory.entries.removeWhere(
              (e) =>
                  e.date == deleted.date &&
                  e.kind == deleted.kind &&
                  e.name == deleted.name,
            );
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final entries = List.of(widget.profile.treatmentHistory.entries)
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
          color: context.watch<AppearanceController>().primaryColor,
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
                  Text('Тип мероприятия',
                      style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: TreatmentKind.values.map((k) {
                      return SoftGlassBadge(
                        color: k.color,
                        icon: k.icon,
                        label: k.shortLabel,
                        selected: _kind == k,
                        onChanged: (_) => _setKind(k),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _nameCtrl,
                    decoration: baseInputDecoration('Название прививки'),
                  ),
                  const SizedBox(height: 12),
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
                  Row(
                    children: [
                      Icon(
                        Icons.alarm,
                        size: 18,
                        color: context.watch<AppearanceController>().primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text('Напомнить за (дн.):',
                            style: Theme.of(context).textTheme.bodyMedium),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline),
                        color:
                            context.watch<AppearanceController>().primaryColor,
                        onPressed: _remindBeforeDays > 0
                            ? () => setState(() => _remindBeforeDays -= 1)
                            : null,
                      ),
                      SizedBox(
                        width: 32,
                        child: Text(
                          '$_remindBeforeDays',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge!
                              .copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.add_circle_outline),
                        color:
                            context.watch<AppearanceController>().primaryColor,
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
                style: Theme.of(context).textTheme.bodyMedium!
                    .copyWith(color: ThemeColors.border),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text('История', style: Theme.of(context).textTheme.titleMedium),
            ),
            ...entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: GlassPlate(
                  padding: 0,
                  child: InkWell(
                    onTap: () => _openDetail(entry),
                    borderRadius: BorderRadius.circular(16),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      child: Row(
                        children: [
                          Container(
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: entry.kind.color.withAlpha(20),
                            ),
                            child: Icon(entry.kind.icon,
                                color: entry.kind.color, size: 20),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(entry.displayName,
                                    style:
                                        Theme.of(context).textTheme.titleSmall),
                                Text(
                                  'Сделано: ${formatSmartDate(entry.date)}  •  '
                                  'Следующее: ${formatSmartDate(entry.nextDate)}',
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

// ─── Sheet: детали препарата / вакцины ───────────────────────────────────────

class TreatmentDetailSheet extends StatelessWidget {
  final PetProfile profile;
  final TreatmentKind kind;
  final String? vaccineName; // non-null only for TreatmentKind.vaccine
  final List<TreatmentEntry> entries; // newest first
  final ValueChanged<TreatmentEntry> onDeleted;

  const TreatmentDetailSheet({
    super.key,
    required this.profile,
    required this.kind,
    this.vaccineName,
    required this.entries,
    required this.onDeleted,
  });

  String get _title =>
      vaccineName != null && vaccineName!.isNotEmpty
          ? 'Прививка: $vaccineName'
          : kind.label;

  Future<void> _delete(BuildContext context, TreatmentEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить запись?'),
        content: const Text(
            'Запись и связанное напоминание будут удалены.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
                backgroundColor: ThemeColors.dangerZone),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await TreatmentService().deleteTreatment(profile.id, entry);
    onDeleted(entry);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final latest = entries.isNotEmpty ? entries.first : null;

    // Next date countdown
    String? countdownText;
    Color countdownColor = ThemeColors.border;
    if (latest != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final next = DateTime(
          latest.nextDate.year, latest.nextDate.month, latest.nextDate.day);
      final days = next.difference(today).inDays;
      if (days < 0) {
        countdownText = 'Просрочено на ${days.abs()} дн.';
        countdownColor = ThemeColors.dangerZone;
      } else if (days == 0) {
        countdownText = 'Сегодня';
        countdownColor = ThemeColors.warning.mainColor;
      } else if (days <= latest.remindBeforeDays) {
        countdownText = 'Через $days ${_daysWord(days)}';
        countdownColor = ThemeColors.warning.mainColor;
      } else {
        countdownText = 'Через $days ${_daysWord(days)}';
        countdownColor = ThemeColors.ok.mainColor;
      }
    }

    return DraggableSheet(
      title: 'История',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.75,
      minSize: 0.4,
      maxSize: 0.95,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ────────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                Container(
                  width: 72,
                  height: 72,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: kind.color.withAlpha(20),
                    border:
                        Border.all(color: kind.color.withAlpha(60), width: 1.5),
                  ),
                  child: Icon(kind.icon, color: kind.color, size: 34),
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: Theme.of(context).textTheme.headlineSmall!
                      .copyWith(fontWeight: FontWeight.w700),
                  textAlign: TextAlign.center,
                ),
                if (countdownText != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 4),
                    decoration: BoxDecoration(
                      color: countdownColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color: countdownColor.withAlpha(60)),
                    ),
                    child: Text(
                      countdownText,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: countdownColor,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: 20),

          // ── Следующая дата ───────────────────────────────────────────────
          if (latest != null) ...[
            GlassPlate(
              padding: 0,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.event_available,
                    iconColor: accent,
                    label: 'Следующее: ${DateFormat('d MMMM yyyy', 'ru').format(latest.nextDate)}',
                  ),
                  Divider(height: 1, indent: 46,
                      color: ThemeColors.border.withAlpha(60)),
                  _InfoRow(
                    icon: Icons.alarm,
                    iconColor: accent,
                    label: 'Напомнить за ${latest.remindBeforeDays} дн.',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── История записей ──────────────────────────────────────────────
          if (entries.isNotEmpty) ...[
            Text('Записи', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...entries.asMap().entries.map((mapEntry) {
              final i = mapEntry.key;
              final entry = mapEntry.value;
              final isLast = i == entries.length - 1;

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline column
                    SizedBox(
                      width: 32,
                      child: Column(
                        children: [
                          Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0 ? kind.color : ThemeColors.border,
                              border: Border.all(
                                color: (i == 0 ? kind.color : ThemeColors.border)
                                    .withAlpha(60),
                                width: 2,
                              ),
                            ),
                          ),
                          if (!isLast)
                            Expanded(
                              child: Center(
                                child: Container(
                                  width: 2,
                                  color: ThemeColors.border.withAlpha(80),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Card
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: GlassPlate(
                          padding: 0,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 12),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        DateFormat('d MMMM yyyy', 'ru')
                                            .format(entry.date),
                                        style: Theme.of(context)
                                            .textTheme
                                            .titleSmall!
                                            .copyWith(
                                              color: i == 0
                                                  ? kind.color
                                                  : null,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '→ ${DateFormat('d MMMM yyyy', 'ru').format(entry.nextDate)}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                                color: ThemeColors.border),
                                      ),
                                    ],
                                  ),
                                ),
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: ThemeColors.dangerZone,
                                  ),
                                  onPressed: () => _delete(context, entry),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                      minWidth: 32, minHeight: 32),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
          ],
        ],
      ),
    );
  }

  static String _daysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }
}

// ─── Helpers ─────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
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
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
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
                Icon(
                  icon,
                  size: 16,
                  color: context.watch<AppearanceController>().primaryColor,
                ),
                const SizedBox(width: 6),
                Text(formatSmartDate(date)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
