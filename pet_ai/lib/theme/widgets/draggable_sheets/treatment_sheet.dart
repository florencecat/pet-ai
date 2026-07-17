import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/remindable.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/treatment_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/remind_before_picker.dart';
import 'package:pet_satellite/theme/widgets/toast.dart';
import 'package:pet_satellite/theme/widgets/treatment_icon.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

enum TreatmentDialogPurpose { create, append, edit }

class CreateTreatmentDialog extends StatefulWidget {
  final Pet profile;
  final TreatmentDialogPurpose purpose;

  // append to category
  final TreatmentKind? kind;
  final Color? color;
  final String? name;

  // edit existing
  final TreatmentEntry? editingEntry;

  const CreateTreatmentDialog({super.key, required this.profile})
    : kind = null,
      color = null,
      name = null,
      editingEntry = null,
      purpose = TreatmentDialogPurpose.create;

  const CreateTreatmentDialog.append({
    super.key,
    required this.profile,
    required this.kind,
    required this.color,
    required this.name,
  }) : purpose = TreatmentDialogPurpose.append,
       editingEntry = null;

  const CreateTreatmentDialog.edit({
    super.key,
    required this.profile,
    required this.editingEntry,
  }) : kind = null,
       color = null,
       name = null,
       purpose = TreatmentDialogPurpose.edit;

  @override
  State<StatefulWidget> createState() => _CreateTreatmentState();
}

class _CreateTreatmentState extends State<CreateTreatmentDialog> {
  late TreatmentKind _kind = TreatmentKind.rabies;
  late int? _color;
  final _nameCtrl = TextEditingController();
  DateTime _date = DateTime.now();
  late DateTime _nextDate;
  int _remindBeforeValue = 7;
  RemindBeforeVariant _remindBeforeVariant = RemindBeforeVariant.days;
  bool _saving = false;

  late String _dialogTitle;

  Future<void> _openIconPicker() async {
    final accent = context.read<AppearanceController>().primaryColor;
    final result = await showTreatmentIconPicker(
      context,
      initialKind: _kind,
      initialColor: _color,
      accent: accent,
    );
    if (result != null) {
      setState(() {
        _color = result.color;
        if (result.kind != _kind) {
          _kind = result.kind;
          _nextDate = _date.add(_kind.defaultInterval);
        }
      });
    }
  }

  Future<void> _pickDate({required bool isNext}) async {
    final initial = isNext ? _nextDate : _date;

    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
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
      showAppToast(context, 'Введите название прививки');
      return;
    }

    setState(() => _saving = true);

    if (widget.purpose == TreatmentDialogPurpose.edit) {
      await TreatmentService().deleteTreatment(widget.profile.id, widget.editingEntry!.id);
    }

    await TreatmentService().addTreatment(
      petId: widget.profile.id,
      kind: _kind,
      date: _date,
      nextDate: _nextDate,
      name: _nameCtrl.text.trim(),
      remindBeforeValue: _remindBeforeValue,
      remindBeforeVariant: _remindBeforeVariant,
      color: _color,
    );
    if (!mounted) return;

    setState(() => _saving = false);

    Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    // Категория обработки определяется видом, а для прививок — ещё и названием.
    // «Последняя запись» должна считаться по этому же ключу, иначе удаление
    // последней прививки в категории не покажет подтверждение.
    final editing = widget.editingEntry!;
    final last =
        widget.profile.treatmentHistory.entries.where((e) {
          if (e.kind != editing.kind) return false;
          if (editing.kind == TreatmentKind.vaccine) {
            return e.name == editing.name;
          }
          return true;
        }).length ==
        1;
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить запись?',
      ignorePreferences: last,
      message: last
          ? 'Это последняя запись, вместе с ней удалится вся категория обработок.'
          : 'Запись и связанное напоминание будут удалены.',
    );
    if (!confirmed) return;
    await TreatmentService().deleteTreatment(
      widget.profile.id,
      widget.editingEntry!.id,
    );
    if (mounted) {
      Navigator.of(context).pop(true);
    }
  }

  @override
  void initState() {
    super.initState();

    switch (widget.purpose) {
      case TreatmentDialogPurpose.create:
        _dialogTitle = 'Новая обработка';
        _color = _kind.color.toARGB32();
        _nextDate = _date.add(_kind.defaultInterval);
        break;
      case TreatmentDialogPurpose.append:
        _dialogTitle = 'Добавить обработку';
        _kind = widget.kind!;
        _color = widget.color!.toARGB32();
        _nextDate = _date.add(_kind.defaultInterval);
        _nameCtrl.text = widget.name!;
        break;
      case TreatmentDialogPurpose.edit:
        _dialogTitle = widget.editingEntry!.name;
        _kind = widget.editingEntry!.kind;
        _color = widget.editingEntry!.displayColor.toARGB32();
        _date = widget.editingEntry!.date;
        _nextDate = widget.editingEntry!.nextDate;
        _nameCtrl.text = widget.editingEntry!.name;
        _remindBeforeValue = widget.editingEntry!.remindBeforeValue;
        _remindBeforeVariant = widget.editingEntry!.remindBeforeVariant;
        break;
    }

    if (widget.purpose == TreatmentDialogPurpose.append) {}

    if (widget.editingEntry != null &&
        widget.purpose == TreatmentDialogPurpose.edit) {}
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.purpose == TreatmentDialogPurpose.edit;
    final hasCategory = widget.profile.treatmentHistory.entries.any(
      (e) => e.kind == _kind,
    );

    return AlertDialog(
      actionsAlignment: isEdit
          ? MainAxisAlignment.spaceBetween
          : MainAxisAlignment.end,
      actions: isEdit
          ? [
              IconButton(
                onPressed: _delete,
                icon: Icon(Icons.delete, color: ThemeColors.dangerZone),
              ),
              Row(
                spacing: 8,
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Отмена'),
                  ),
                  FilledButton(
                    onPressed: _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: context
                          .watch<AppearanceController>()
                          .primaryColor,
                    ),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  backgroundColor: context
                      .watch<AppearanceController>()
                      .primaryColor,
                ),
                child: const Text('Сохранить'),
              ),
            ],
      title: Text(
        _dialogTitle,
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _saving,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            if (widget.purpose != TreatmentDialogPurpose.edit) ...[
              _IconPickerTile(
                kind: _kind,
                color: _color,
                onTap: widget.purpose != TreatmentDialogPurpose.append
                    ? _openIconPicker
                    : null,
              ),
              if (!hasCategory)
                InfoGlassPlate(
                  color: _color != null
                      ? Color(_color!)
                      : context.watch<AppearanceController>().primaryColor,
                  label: 'Будет создана новая категория обработок',
                ),
              TextField(
                controller: _nameCtrl,
                decoration: baseInputDecoration(context, hint: 'Название'),
              ),
            ],
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
            RemindBeforePicker(
              value: _remindBeforeValue,
              variant: _remindBeforeVariant,
              onValueChanged: (v) => setState(() => _remindBeforeValue = v),
              onVariantChanged: (v) => setState(() => _remindBeforeVariant = v),
            ),
          ],
        ),
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

  Future<void> _initScreen() async {
    final fresh = await PetProfileService().loadProfile(widget.profile.id);
    if (!mounted) return;
    if (fresh != null) {
      final related =
          fresh.treatmentHistory.entries
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
        _nameCtrl.clear();
      });
    }
  }

  void _createTreatment(BuildContext context, TreatmentEntry entry) async {
    final added = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => CreateTreatmentDialog.append(
        profile: widget.profile,
        kind: entry.kind,
        color: entry.displayColor,
        name: entry.name,
      ),
    );
    if (added != null && added && mounted) {
      await _initScreen();
    }
  }

  void _editTreatment(BuildContext context, TreatmentEntry entry) async {
    final changed = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) => CreateTreatmentDialog.edit(
        profile: widget.profile,
        editingEntry: entry,
      ),
    );
    if (changed != null && changed) {
      await _initScreen();
      if (_entries.isEmpty && context.mounted) {
        Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final secondaryColor = context.watch<AppearanceController>().secondaryColor;
    final latest = _entries.isNotEmpty ? _entries.first : null;
    // Цвет иконки берём из последней записи (или цвет типа по умолчанию).
    final kindColor = latest?.displayColor ?? widget.kind.color;

    // Next date countdown
    String? countdownText;
    Color countdownColor = context.watch<AppearanceController>().secondaryColor;
    if (latest != null) {
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      final next = DateTime(
        latest.nextDate.year,
        latest.nextDate.month,
        latest.nextDate.day,
      );
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
      initialSize: null,
      maxSize: 0.85,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero ────────────────────────────────────────────────────────
          Center(
            child: Column(
              children: [
                SoftRoundedIcon(
                  icon: widget.kind.icon,
                  color: kindColor,
                  size: 36,
                ),
                const SizedBox(height: 12),
                Text(
                  _title,
                  style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),
                if (countdownText != null) ...[
                  const SizedBox(height: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: countdownColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: countdownColor.withAlpha(60)),
                    ),
                    child: Text(
                      countdownText,
                      style: TextStyle(
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
            Text('Последняя запись'),
            const SizedBox(height: 8),
            GlassPlate(
              padding: 0,
              child: Column(
                children: [
                  _InfoRow(
                    icon: Icons.event_available,
                    iconColor: accent,
                    label:
                        'Следующее по плану: ${DateFormat('d MMMM yyyy', 'ru').format(latest.nextDate)}',
                  ),
                  Divider(
                    height: 1,
                    indent: 46,
                    color: context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(60),
                  ),
                  _InfoRow(
                    icon: Icons.alarm,
                    iconColor: accent,
                    label: latest.hasRemindBefore
                        ? 'Напоминание ${latest.remindBeforeLabel}'
                        : 'Без напоминания',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          SoftGlassButton(
            icon: Icons.add_circle_outline_rounded,
            title: 'Добавить новую запись',
            subtitle: 'В категорию "${widget.kind.label}"',
            onTap: () => _createTreatment(context, latest!),
          ),

          // ── История записей ──────────────────────────────────────────────
          if (_entries.isNotEmpty) ...[
            Text('Записи', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ..._entries.asMap().entries.map((mapEntry) {
              final i = mapEntry.key;
              final entry = mapEntry.value;
              final isLast = i == _entries.length - 1;
              // Интервал (в днях) до следующей, более старой обработки.
              final gapDays = isLast
                  ? 0
                  : _dayGap(entry.date, _entries[i + 1].date);

              return IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Timeline column
                    SizedBox(
                      width: 54,
                      child: Column(
                        children: [
                          // Верхняя половина: линия к предыдущей (более новой)
                          // записи + подпись даты вплотную над точкой.
                          Expanded(
                            child: Column(
                              children: [
                                Expanded(
                                  child: i == 0
                                      ? const SizedBox.shrink()
                                      : Center(
                                          child: Container(
                                            width: 2,
                                            color: secondaryColor,
                                          ),
                                        ),
                                ),
                                Text(
                                  formatSmartDate(
                                    entry.date,
                                    pattern:
                                        entry.date.year == DateTime.now().year
                                        ? 'd MMMM'
                                        : 'd MMMM yyyy',
                                    locale: 'ru',
                                  ),
                                  textAlign: TextAlign.center,
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(
                                        height: 1.2,
                                        color: i == 0
                                            ? kindColor
                                            : secondaryColor,
                                      ),
                                ),
                                const SizedBox(height: 4),
                              ],
                            ),
                          ),
                          // Точка — напротив центра карточки.
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: i == 0 ? kindColor : secondaryColor,
                              border: Border.all(
                                color: (i == 0 ? kindColor : secondaryColor)
                                    .withAlpha(60),
                                width: 2,
                              ),
                            ),
                          ),
                          // Нижняя половина: линия к следующей (более старой)
                          // записи + бейдж с интервалом между обработками.
                          Expanded(
                            child: isLast
                                ? const SizedBox.shrink()
                                : Stack(
                                    alignment: Alignment.center,
                                    children: [
                                      Center(
                                        child: Container(
                                          width: 2,
                                          decoration: BoxDecoration(
                                            gradient: i == 0
                                                ? LinearGradient(
                                                    begin: Alignment.topCenter,
                                                    end: Alignment.bottomCenter,
                                                    stops: const [0.4, 1.0],
                                                    colors: [
                                                      kindColor,
                                                      secondaryColor,
                                                    ],
                                                  )
                                                : null,
                                            color: i != 0
                                                ? secondaryColor
                                                : null,
                                          ),
                                        ),
                                      ),
                                      _GapBadge(
                                        days: gapDays,
                                        color: secondaryColor,
                                      ),
                                    ],
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
                        child: GlassCard(
                          padding: 2,
                          callback: () => _editTreatment(context, entry),
                          child: ListTile(
                            title: Text(
                              entry.name,
                              style: Theme.of(context).textTheme.bodyLarge!
                                  .copyWith(
                                    color: i == 0 ? kindColor : null,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            subtitle: Text(
                              'Следующая по плану: '
                              '${formatSmartDate(entry.nextDate, pattern: 'd MMMM yyyy', locale: 'ru')}',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(color: context.subtitleColor),
                            ),
                            trailing: Icon(
                              Icons.chevron_right,
                              color: secondaryColor,
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

  /// Разница в целых днях между двумя записями (без учёта времени суток).
  static int _dayGap(DateTime a, DateTime b) {
    final da = DateTime(a.year, a.month, a.day);
    final db = DateTime(b.year, b.month, b.day);
    return da.difference(db).inDays;
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

/// Небольшой бейдж с интервалом между соседними обработками («12д», «>30 д.»).
class _GapBadge extends StatelessWidget {
  final int days;
  final Color color;

  const _GapBadge({required this.days, required this.color});

  @override
  Widget build(BuildContext context) {
    final label = days > 30 ? '>30 д.' : '$daysд';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        // Непрозрачный фон, чтобы бейдж «разрывал» линию таймлайна.
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(60)),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 10,
          height: 1.0,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

/// Тайл выбора вида + цвета обработки (открывает [showTreatmentIconPicker]).
class _IconPickerTile extends StatelessWidget {
  final TreatmentKind kind;
  final int? color;
  final VoidCallback? onTap;

  const _IconPickerTile({
    required this.kind,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
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
            SoftRoundedIcon(icon: kind.icon, color: Color(color!)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Вид и цвет',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor
                          .withAlpha(128),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    kind.shortLabel,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ],
              ),
            ),
            if (onTap != null)
              Icon(
                Icons.chevron_right,
                color: context.watch<AppearanceController>().secondaryColor,
                size: 22,
              ),
          ],
        ),
      ),
    );
  }
}

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
