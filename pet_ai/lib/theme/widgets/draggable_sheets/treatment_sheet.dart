import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/treatment_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

// ─── Sheet: добавление + история всех обработок ──────────────────────────────

class TreatmentSheet extends StatefulWidget {
  final Pet profile;
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
        const SnackBar(content: Text('Введите Название')),
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

    // Stay in sheet — reload list and reset form
    final fresh = await PetService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() {
        widget.profile.treatmentHistory.entries
          ..clear()
          ..addAll(fresh.treatmentHistory.entries);
        _nameCtrl.clear();
        _date = DateTime.now();
        _nextDate = _date.add(_kind.defaultInterval);
        _remindBeforeDays = 7;
        _saving = false;
      });
    } else {
      if (mounted) setState(() => _saving = false);
    }
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
      onBack: () => Navigator.of(context).pop(true),
      initialSize: 0.85,
      minSize: 0.4,
      maxSize: 1.0,
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
                    decoration: baseInputDecoration('Название'),
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
                        backgroundColor: context
                            .watch<AppearanceController>()
                            .primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                    ),
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

class TreatmentDetailSheet extends StatefulWidget {
  final Pet profile;
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

  @override
  State<TreatmentDetailSheet> createState() => _TreatmentDetailSheetState();
}

class _TreatmentDetailSheetState extends State<TreatmentDetailSheet> {
  // ── Mutable list so we can remove entries inline ──────────────────────────
  late List<TreatmentEntry> _entries;

  // ── Edit mode ─────────────────────────────────────────────────────────────
  TreatmentEntry? _editingEntry; // which entry is being edited
  final _nameCtrl = TextEditingController();
  DateTime _editDate = DateTime.now();
  DateTime _editNextDate = DateTime.now().add(const Duration(days: 365));
  int _editRemindDays = 7;
  bool _editSaving = false;

  @override
  void initState() {
    super.initState();
    _entries = List.of(widget.entries);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  String get _title =>
      widget.vaccineName != null && widget.vaccineName!.isNotEmpty
          ? 'Прививка: ${widget.vaccineName}'
          : widget.kind.label;

  void _startEdit(TreatmentEntry entry) {
    setState(() {
      _editingEntry = entry;
      _nameCtrl.text = entry.name;
      _editDate = entry.date;
      _editNextDate = entry.nextDate;
      _editRemindDays = entry.remindBeforeDays;
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingEntry = null;
      _nameCtrl.clear();
    });
  }

  Future<void> _saveEdit() async {
    if (_editingEntry == null) return;
    setState(() => _editSaving = true);

    // Delete old, create new
    await TreatmentService().deleteTreatment(widget.profile.id, _editingEntry!);
    await TreatmentService().addTreatment(
      petId: widget.profile.id,
      kind: widget.kind,
      date: _editDate,
      nextDate: _editNextDate,
      name: _nameCtrl.text.trim(),
      remindBeforeDays: _editRemindDays,
    );

    // Reload entries
    final fresh = await PetService().loadProfile(widget.profile.id);
    if (!mounted) return;
    if (fresh != null) {
      final related = fresh.treatmentHistory.entries
          .where(
            (e) =>
                e.kind == widget.kind &&
                (widget.kind != TreatmentKind.vaccine ||
                    e.name ==
                        (_nameCtrl.text.trim().isNotEmpty
                            ? _nameCtrl.text.trim()
                            : widget.vaccineName)),
          )
          .toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      setState(() {
        _entries
          ..clear()
          ..addAll(related);
        _editingEntry = null;
        _editSaving = false;
        _nameCtrl.clear();
      });
    } else {
      setState(() => _editSaving = false);
    }
  }

  Future<void> _pickEditDate({required bool isNext}) async {
    final initial = isNext ? _editNextDate : _editDate;
    final firstDate = DateTime.now().subtract(const Duration(days: 365 * 5));
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
        _editNextDate = picked;
      } else {
        _editDate = picked;
        _editNextDate = picked.add(widget.kind.defaultInterval);
        if (_editNextDate.isBefore(_editDate)) {
          _editNextDate = _editDate.add(widget.kind.defaultInterval);
        }
      }
    });
  }

  Future<void> _delete(TreatmentEntry entry) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить запись?',
      message: 'Запись и связанное напоминание будут удалены.',
    );
    if (!confirmed) return;
    await TreatmentService().deleteTreatment(widget.profile.id, entry);
    widget.onDeleted(entry);
    if (mounted) {
      setState(() => _entries.removeWhere(
            (e) =>
                e.date == entry.date &&
                e.kind == entry.kind &&
                e.name == entry.name,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final latest = _entries.isNotEmpty ? _entries.first : null;

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
      onBack: () => Navigator.of(context).pop(true),
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
                    color: widget.kind.color.withAlpha(20),
                    border: Border.all(
                        color: widget.kind.color.withAlpha(60), width: 1.5),
                  ),
                  child:
                      Icon(widget.kind.icon, color: widget.kind.color, size: 34),
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
                      border: Border.all(color: countdownColor.withAlpha(60)),
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
          if (latest != null && _editingEntry == null) ...[
            GlassPlate(
              padding: 0,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.event_available,
                    iconColor: accent,
                    label:
                        'Следующее: ${DateFormat('d MMMM yyyy', 'ru').format(latest.nextDate)}',
                  ),
                  Divider(
                      height: 1,
                      indent: 46,
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

          // ── Форма редактирования ────────────────────────────────────────
          if (_editingEntry != null) ...[
            GlassPlate(
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Редактирование',
                            style: Theme.of(context).textTheme.titleSmall!
                                .copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, size: 20),
                          onPressed: _cancelEdit,
                          color: ThemeColors.border,
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (widget.kind == TreatmentKind.vaccine) ...[
                      TextField(
                        controller: _nameCtrl,
                        decoration: baseInputDecoration('Название'),
                      ),
                      const SizedBox(height: 10),
                    ],
                    Row(
                      children: [
                        Expanded(
                          child: _DateField(
                            label: 'Когда сделано',
                            icon: Icons.event,
                            date: _editDate,
                            onTap: () => _pickEditDate(isNext: false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _DateField(
                            label: 'Следующее',
                            icon: Icons.notifications_active_outlined,
                            date: _editNextDate,
                            onTap: () => _pickEditDate(isNext: true),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Icon(Icons.alarm, size: 18, color: accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text('Напомнить за (дн.):',
                              style: Theme.of(context).textTheme.bodyMedium),
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_circle_outline),
                          color: accent,
                          onPressed: _editRemindDays > 0
                              ? () =>
                                  setState(() => _editRemindDays -= 1)
                              : null,
                        ),
                        SizedBox(
                          width: 32,
                          child: Text(
                            '$_editRemindDays',
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge!
                                .copyWith(fontWeight: FontWeight.bold),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_circle_outline),
                          color: accent,
                          onPressed: _editRemindDays < 60
                              ? () =>
                                  setState(() => _editRemindDays += 1)
                              : null,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: _editSaving ? null : _saveEdit,
                        icon: _editSaving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.save_outlined, size: 18),
                        label: const Text('Сохранить'),
                        style: FilledButton.styleFrom(
                          backgroundColor: accent,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],

          // ── История записей ──────────────────────────────────────────────
          if (_entries.isNotEmpty) ...[
            Text('Записи', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._entries.asMap().entries.map((mapEntry) {
              final i = mapEntry.key;
              final entry = mapEntry.value;
              final isLast = i == _entries.length - 1;

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
                              color: i == 0
                                  ? widget.kind.color
                                  : ThemeColors.border,
                              border: Border.all(
                                color: (i == 0
                                        ? widget.kind.color
                                        : ThemeColors.border)
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
                                                  ? widget.kind.color
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
                                // Edit button
                                if (_editingEntry == null)
                                  IconButton(
                                    icon: Icon(
                                      Icons.edit_outlined,
                                      size: 18,
                                      color: accent.withAlpha(180),
                                    ),
                                    onPressed: () => _startEdit(entry),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(
                                        minWidth: 32, minHeight: 32),
                                  ),
                                // Delete button
                                IconButton(
                                  icon: const Icon(
                                    Icons.delete_outline,
                                    size: 18,
                                    color: ThemeColors.dangerZone,
                                  ),
                                  onPressed: () => _delete(entry),
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
