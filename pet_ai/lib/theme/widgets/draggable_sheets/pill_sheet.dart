import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/remindable.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pill_reminder_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pill_icon.dart';
import 'package:pet_satellite/theme/widgets/remind_before_picker.dart';
import 'package:pet_satellite/theme/widgets/switch.dart';
import 'package:pet_satellite/theme/widgets/toast.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/services/pb_service.dart';

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
  // «Напомнить за» до каждого приёма.
  int remindBeforeValue;
  RemindBeforeVariant remindBeforeVariant;

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
    this.remindBeforeValue = 0,
    this.remindBeforeVariant = RemindBeforeVariant.minutes,
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
    remindBeforeValue: r.remindBeforeValue,
    remindBeforeVariant: r.remindBeforeVariant,
  );

  int get doseValue => int.tryParse(doseAmountCtrl.text.trim()) ?? 0;

  void dispose() {
    nameCtrl.dispose();
    doseAmountCtrl.dispose();
  }
}

// ─── Dialog: создание / редактирование курса ─────────────────────────────────

enum PillDialogPurpose { create, edit }

/// Создание нового курса и редактирование существующего — единый диалог поверх
/// общей формы [_PillForm] (по образцу CreateTreatmentDialog у обработок).
class PillDialog extends StatefulWidget {
  final Pet profile;
  final PillDialogPurpose purpose;

  /// Редактируемый курс — заполнен только для [PillDialogPurpose.edit].
  final Pill? editing;

  const PillDialog({super.key, required this.profile})
    : editing = null,
      purpose = PillDialogPurpose.create;

  const PillDialog.edit({
    super.key,
    required this.profile,
    required this.editing,
  }) : purpose = PillDialogPurpose.edit;

  @override
  State<PillDialog> createState() => _PillDialogState();
}

class _PillDialogState extends State<PillDialog> {
  late _PillFormState _form;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _form = widget.purpose == PillDialogPurpose.edit
        ? _PillFormState.fromReminder(widget.editing!)
        : _PillFormState();
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
    if (picked != null && !_form.schedules.contains(picked)) {
      setState(() => _form.schedules.add(picked));
    }
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

  /// Общая проверка формы для создания и редактирования.
  bool _validate() {
    if (_form.nameCtrl.text.trim().isEmpty) {
      showAppToast(context, 'Введите название препарата');
      return false;
    }
    if (_form.kind == null || _form.kind!.id.isEmpty) {
      showAppToast(context, 'Выберите вид препарата');
      return false;
    }
    if (_form.frequency == PillFrequencyType.weekdays &&
        _form.weekdays.isEmpty) {
      showAppToast(context, 'Выберите хотя бы один день');
      return false;
    }
    if (_form.frequency != PillFrequencyType.onDemand &&
        _form.schedules.isEmpty) {
      showAppToast(context, 'Добавьте хотя бы одно время приёма');
      return false;
    }
    return true;
  }

  Future<void> _save() async {
    if (!_validate()) return;

    setState(() => _saving = true);

    final name = _form.nameCtrl.text.trim();
    final schedules =
        (List.of(_form.schedules)..sort(
              (a, b) => a.hour != b.hour
                  ? a.hour.compareTo(b.hour)
                  : a.minute.compareTo(b.minute),
            ))
            .map((t) => PillSchedule.fromTimeOfDay(t))
            .toList();
    final weekdays = _form.frequency == PillFrequencyType.weekdays
        ? (List.of(_form.weekdays)..sort())
        : <int>[];

    if (widget.purpose == PillDialogPurpose.edit) {
      await PillReminderService().update(
        petId: widget.profile.id,
        updated: widget.editing!.copyWith(
          name: name,
          kind: _form.kind,
          color: _form.color,
          doseValue: _form.doseValue,
          doseUnit: _form.doseUnit,
          frequencyType: _form.frequency,
          weekdays: weekdays,
          schedules: schedules,
          startDate: _form.startDate,
          endDate: _form.hasEndDate ? _form.endDate : null,
          clearEndDate: !_form.hasEndDate,
          remindBeforeValue: _form.remindBeforeValue,
          remindBeforeVariant: _form.remindBeforeVariant,
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(true);
    } else {
      final newPill = Pill(
        id: generateId(),
        name: name,
        kind: _form.kind,
        color: _form.color,
        doseValue: _form.doseValue,
        doseUnit: _form.doseUnit,
        frequencyType: _form.frequency,
        weekdays: weekdays,
        schedules: schedules,
        startDate: _form.startDate,
        endDate: _form.hasEndDate ? _form.endDate : null,
        takenDates: const [],
        remindBeforeValue: _form.remindBeforeValue,
        remindBeforeVariant: _form.remindBeforeVariant,
      );
      await PillReminderService().add(
        petId: widget.profile.id,
        reminder: newPill,
      );
      if (!mounted) return;
      setState(() => _saving = false);
      Navigator.of(context).pop(newPill);
    }
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
      reminder: widget.editing!,
    );
    if (!mounted) return;
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final isEdit = widget.purpose == PillDialogPurpose.edit;

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
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: accent),
                    child: const Text('Сохранить'),
                  ),
                ],
              ),
            ]
          : [
              TextButton(
                onPressed: () => Navigator.of(context).pop(null),
                child: const Text('Отмена'),
              ),
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(backgroundColor: accent),
                child: const Text('Сохранить'),
              ),
            ],
      title: Text(
        widget.purpose == PillDialogPurpose.edit
            ? widget.editing!.name
            : 'Новый препарат',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _saving,
        child: SizedBox(
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: _PillForm(
              form: _form,
              accent: accent,
              onAddSchedule: _addSchedule,
              onEditSchedule: _editSchedule,
              onPickDate: _pickDate,
              onChanged: () => setState(() {}),
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Sheet: список курсов + карточка курса ───────────────────────────────────

class PillReminderSheet extends StatefulWidget {
  final Pet profile;

  /// Открыть сразу на карточке курса (переход из списка препаратов на странице
  /// здоровья). null — открыть список.
  final Pill? initialReminder;

  const PillReminderSheet({
    super.key,
    required this.profile,
    this.initialReminder,
  });

  @override
  State<PillReminderSheet> createState() => _PillReminderSheetState();
}

class _PillReminderSheetState extends State<PillReminderSheet> {
  /// Просматриваемый курс; null — страница списка. Смена значения
  /// «перелистывает» страницу внутри того же sheet — см. [_pageSwitcher].
  Pill? _selected;

  bool _actualRemindersExpanded = true;
  bool _archiveRemindersExpanded = false;

  @override
  void initState() {
    super.initState();
    _selected = widget.initialReminder;
  }

  // ── Данные ───────────────────────────────────────────────────────────────

  /// Перечитывает профиль: обновляет список курсов и просматриваемый курс.
  Future<void> _reload() async {
    final fresh = await PetProfileService().loadProfile(widget.profile.id);
    if (fresh == null || !mounted) return;
    setState(() {
      widget.profile.pillReminders
        ..clear()
        ..addAll(fresh.pillReminders);
      if (!widget.profile.pillReminders.contains(_selected)) {
        setState(() => _selected = null);
      } else {
        final selected = _selected;
        if (selected != null) {
          _selected = fresh.pillReminders.firstWhere(
            (r) => r.id == selected.id,
            orElse: () => selected,
          );
        }
      }
    });
  }

  // ── Создание / редактирование ────────────────────────────────────────────

  Future<void> _createPill() async {
    final created = await showAdaptiveDialog<Pill>(
      context: context,
      builder: (_) => PillDialog(profile: widget.profile),
    );
    if (created != null && mounted) {
      await _reload();
      setState(() {
        _selected = created;
      });
    }
  }

  Future<void> _editPill() async {
    final saved = await showAdaptiveDialog<bool>(
      context: context,
      builder: (_) =>
          PillDialog.edit(profile: widget.profile, editing: _selected!),
    );
    if (saved == true && mounted) await _reload();
  }

  // ── Действия на карточке курса ───────────────────────────────────────────

  /// Логирует приём «по требованию»: спрашиваем дозу и время, затем добавляем
  /// запись в журнал.
  Future<void> _logOnDemandIntake() async {
    final reminder = _selected!;
    final result = await showOnDemandIntakeDialog(
      context,
      kind: reminder.kind,
      defaultDoseValue: reminder.doseValue,
      defaultDoseUnit: reminder.doseUnit,
    );
    if (result == null) return;
    await PillReminderService().addOnDemandIntake(
      petId: widget.profile.id,
      reminderId: reminder.id,
      time: result.time,
      doseValue: result.doseValue,
      doseUnit: result.doseUnit,
    );
    await _reload();
  }

  Future<void> _removeIntake(PillIntake intake) async {
    await PillReminderService().removeOnDemandIntake(
      petId: widget.profile.id,
      reminderId: _selected!.id,
      time: intake.time,
    );
    await _reload();
  }

  Future<void> _toggleSchedule(int scheduleIndex) async {
    final reminder = _selected!;
    final today = DateTime.now();
    if (reminder.isScheduleTakenOnDay(today, scheduleIndex)) {
      await PillReminderService().markScheduleUntaken(
        petId: widget.profile.id,
        reminderId: reminder.id,
        date: today,
        scheduleIndex: scheduleIndex,
      );
    } else {
      await PillReminderService().markScheduleTaken(
        petId: widget.profile.id,
        reminderId: reminder.id,
        date: today,
        scheduleIndex: scheduleIndex,
      );
    }
    await _reload();
  }

  Future<void> _markTaken(DateTime day) async {
    await PillReminderService().markTaken(
      petId: widget.profile.id,
      reminderId: _selected!.id,
      date: day,
    );
    await _reload();
  }

  // ── Helpers карточки ─────────────────────────────────────────────────────

  List<DateTime> _scheduledDays(Pill reminder, int days) {
    final today = DateTime.now();
    final result = <DateTime>[];
    for (var i = 0; i < days; i++) {
      final d = DateTime(
        today.year,
        today.month,
        today.day,
      ).subtract(Duration(days: i));
      if (reminder.isScheduledForDay(d)) result.add(d);
    }
    return result;
  }

  List<DateTime> _missedDays(Pill reminder, int days) => _scheduledDays(
    reminder,
    days,
  ).where((d) => !reminder.isTakenOnDay(d)).toList();

  /// Приёмы «по требованию» за последние 30 дней, кроме сегодня, свежие сверху.
  List<PillIntake> _recentIntakes(Pill reminder, DateTime today) {
    final t0 = DateTime(today.year, today.month, today.day);
    final start = t0.subtract(const Duration(days: 30));
    return reminder.intakes
        .where((i) => i.time.isAfter(start) && i.time.isBefore(t0))
        .toList()
      ..sort((a, b) => b.time.compareTo(a.time));
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

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final selected = _selected;

    return DraggableSheet(
      title: selected == null ? 'Препараты' : 'Препарат',
      centerTitle: true,
      // На карточке «назад» возвращает к списку, а не закрывает sheet.
      onBack: selected == null
          ? () => Navigator.of(context).pop(true)
          : () => setState(() => _selected = null),
      initialSize: null,
      maxSize: 0.95,
      actions: selected == null
          ? null
          : [TextButton(onPressed: _editPill, child: Text('Редактировать'))],
      body: _pageSwitcher(
        selected == null
            // Ключ различает страницы: по нему же выбирается сторона въезда.
            ? KeyedSubtree(
                key: const ValueKey(false),
                child: _buildListBody(accent),
              )
            : KeyedSubtree(
                key: const ValueKey(true),
                child: _buildDetailBody(accent, selected),
              ),
      ),
    );
  }

  /// Длительность и кривая перелистывания. Одни и те же для сдвига страниц и
  /// для смены высоты sheet — иначе высота приезжала бы отдельно от контента.
  static const _pageDuration = Duration(milliseconds: 250);
  static const _pageCurve = Curves.easeInOut;

  /// Перелистывание страниц внутри sheet: карточка въезжает справа, список
  /// уходит влево; при возврате — наоборот. AnimatedSwitcher проигрывает
  /// уходящей странице ту же анимацию задом наперёд, поэтому достаточно задать
  /// каждой стороне свою точку входа.
  ///
  /// Кривая обязана быть симметричной — f(1-t) = 1-f(t). Уходящая страница
  /// считается по той же кривой от разворачивающегося t, и только при симметрии
  /// страницы едут синхронно, край в край (между ними всегда ровно одна ширина).
  /// С несимметричной (easeOutCubic и т.п.) входящая почти сразу доезжает до
  /// центра, а уходящая там ещё стоит — и страницы накладываются друг на друга.
  ///
  /// Страницы разной высоты, а sheet тянется по контенту (initialSize: null),
  /// поэтому высоту доводит AnimatedSize — теми же длительностью и кривой.
  Widget _pageSwitcher(Widget child) {
    return AnimatedSize(
      duration: _pageDuration,
      curve: _pageCurve,
      // Высота меняется от верха: при выравнивании по центру (по умолчанию)
      // контент дёргался бы относительно шапки.
      alignment: Alignment.topCenter,
      child: AnimatedSwitcher(
        duration: _pageDuration,
        switchInCurve: _pageCurve,
        switchOutCurve: _pageCurve,
        layoutBuilder: (currentChild, previousChildren) => Stack(
          alignment: Alignment.topCenter,
          children: [
            // Уходящая страница не должна задавать размер Stack: иначе на время
            // перехода он просил бы высоту по большей из двух страниц, и
            // AnimatedSize честно анимировал бы этот «горб» вместо перехода к
            // высоте новой страницы. Positioned из расчёта размера выпадает.
            for (final page in previousChildren)
              Positioned(top: 0, left: 0, right: 0, child: page),
            ?currentChild,
          ],
        ),
        transitionBuilder: (child, animation) {
          final isDetail = (child.key as ValueKey<bool>).value;
          return SlideTransition(
            position: Tween<Offset>(
              begin: isDetail ? const Offset(1, 0) : const Offset(-1, 0),
              end: Offset.zero,
            ).animate(animation),
            // Страницы обязаны быть одной ширины: сдвиг SlideTransition
            // задаётся в долях ширины ребёнка, а в Stack страницы получают
            // свободные ограничения и разъехались бы по ширине, а с ней и по
            // сдвигу. Ширина Stack задаётся текущей страницей, уходящая
            // подхватывает её через Positioned(left/right).
            child: SizedBox(width: double.infinity, child: child),
          );
        },
        child: child,
      ),
    );
  }

  // ── Страница: список курсов ──────────────────────────────────────────────

  Widget _buildListBody(Color accent) {
    final reminders = List.of(widget.profile.pillReminders)
      ..sort((a, b) => a.name.compareTo(b.name));
    final actualReminders = reminders
        .where(
          (r) =>
              r.endDate == null ||
              r.endDate!.isAfter(DateTime.now()) ||
              r.endDate!.isAtSameMomentAs(DateTime.now()),
        )
        .toList();
    final archiveReminders = reminders
        .where((r) => r.endDate != null && r.endDate!.isBefore(DateTime.now()))
        .toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SoftGlassButton(
          icon: Icons.medication_outlined,
          title: 'Добавить препарат',
          subtitle: 'Курс приёма с напоминаниями',
          onTap: _createPill,
        ),
        const SizedBox(height: 16),

        if (actualReminders.isEmpty && archiveReminders.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Text(
              'Напоминаний пока нет',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.watch<AppearanceController>().secondaryColor,
              ),
            ),
          ),

        if (actualReminders.isNotEmpty)
          _remindersSection(
            title: 'Активные курсы',
            reminders: actualReminders,
            accent: accent,
            expanded: _actualRemindersExpanded,
            onToggle: () => setState(
              () => _actualRemindersExpanded = !_actualRemindersExpanded,
            ),
          ),
        if (archiveReminders.isNotEmpty)
          _remindersSection(
            title: 'Законченные курсы',
            reminders: archiveReminders,
            accent: accent,
            expanded: _archiveRemindersExpanded,
            onToggle: () => setState(
              () => _archiveRemindersExpanded = !_archiveRemindersExpanded,
            ),
          ),
      ],
    );
  }

  /// Сворачиваемая секция курсов (активные / законченные).
  Widget _remindersSection({
    required String title,
    required List<Pill> reminders,
    required Color accent,
    required bool expanded,
    required VoidCallback onToggle,
  }) {
    return CollapsibleSection(
      expanded: expanded,
      onToggle: onToggle,
      titleContent: Row(
        spacing: 4,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (!expanded)
            Text(
              '( ${reminders.length} )',
              style: Theme.of(
                context,
              ).textTheme.titleMedium!.copyWith(color: accent.withAlpha(192)),
            ),
        ],
      ),
      body: Column(
        children: [
          ...reminders.map(
            (r) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _ReminderListTile(
                reminder: r,
                accent: accent,
                onTap: () => setState(() => _selected = r),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Страница: карточка курса ─────────────────────────────────────────────

  Widget _buildDetailBody(Color accent, Pill reminder) {
    final today = DateTime.now();
    final scheduledToday = reminder.isScheduledForDay(today);
    final isOnDemand = reminder.frequencyType == PillFrequencyType.onDemand;
    // «По требованию» нельзя пропустить — раздел пропусков не показываем.
    final missedDays = isOnDemand ? <DateTime>[] : _missedDays(reminder, 30);
    final todayIntakes = isOnDemand
        ? reminder.intakesOnDay(today)
        : <PillIntake>[];
    final journalIntakes = isOnDemand
        ? _recentIntakes(reminder, today)
        : <PillIntake>[];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Hero ────────────────────────────────────────────────────────────
        Center(
          child: Column(
            children: [
              PillIcon(
                kind: reminder.kind,
                colorValue: reminder.color,
                fallback: accent,
                size: 72,
              ),
              const SizedBox(height: 12),
              Text(
                reminder.name,
                style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),
              if (reminder.doseLabel.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  reminder.doseLabel,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: context.watch<AppearanceController>().secondaryColor,
                  ),
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
              if (reminder.kind != null) ...[
                _DetailRow(
                  icon: reminder.kind!.icon,
                  iconColor: reminder.color != null
                      ? Color(reminder.color!)
                      : accent,
                  label: reminder.kind!.name,
                ),
                Divider(
                  height: 1,
                  indent: 46,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(60),
                ),
              ],
              _DetailRow(
                icon: Icons.repeat,
                iconColor: accent,
                label: reminder.frequencyLabel,
              ),
              Divider(
                height: 1,
                indent: 46,
                color: context
                    .watch<AppearanceController>()
                    .secondaryColor
                    .withAlpha(60),
              ),
              // Show each time as a separate row (skip for on-demand — no schedule).
              if (!isOnDemand) ...[
                ...reminder.schedules.asMap().entries.map((entry) {
                  final i = entry.key;
                  final s = entry.value;
                  final isLast = i == reminder.schedules.length - 1;
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
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor
                              .withAlpha(60),
                        ),
                    ],
                  );
                }),
                Divider(
                  height: 1,
                  indent: 46,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(60),
                ),
              ],
              _DetailRow(
                icon: Icons.event,
                iconColor: accent,
                label: 'С ${formatSmartDate(reminder.startDate)}',
                sublabel: reminder.endDate != null
                    ? 'по ${formatSmartDate(reminder.endDate!)}'
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
            ...reminder.schedules.asMap().entries.map((entry) {
              final i = entry.key;
              final s = entry.value;
              final taken = reminder.isScheduleTakenOnDay(today, i);
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
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor
                            .withAlpha(60),
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
                                        ? context
                                              .watch<AppearanceController>()
                                              .secondaryColor
                                        : context
                                              .watch<AppearanceController>()
                                              .secondaryColor,
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
}

// ─── Shared form widget ───────────────────────────────────────────────────────

/// Поля курса препарата. Кнопку сохранения предоставляет вызывающая сторона
/// ([PillDialog] — через actions диалога).
class _PillForm extends StatelessWidget {
  final _PillFormState form;
  final Color accent;
  final VoidCallback onAddSchedule;
  final void Function(int index) onEditSchedule;
  final Future<void> Function({required bool isEnd}) onPickDate;
  final VoidCallback onChanged;

  const _PillForm({
    required this.form,
    required this.accent,
    required this.onAddSchedule,
    required this.onEditSchedule,
    required this.onPickDate,
    required this.onChanged,
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
          decoration: baseInputDecoration(context, hint: 'Название препарата'),
          textCapitalization: TextCapitalization.sentences,
        ),
        const SizedBox(height: 10),
        _DoseField(form: form, accent: accent, onChanged: onChanged),

        const SizedBox(height: 12),
        Text('Периодичность', style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 6),
        Wrap(
          spacing: 6,
          runSpacing: 6,
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
          const SizedBox(height: 12),
          RemindBeforePicker(
            value: form.remindBeforeValue,
            variant: form.remindBeforeVariant,
            onValueChanged: (v) {
              form.remindBeforeValue = v;
              onChanged();
            },
            onVariantChanged: (v) {
              form.remindBeforeVariant = v;
              onChanged();
            },
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
            OutlinedSwitch(
              value: form.hasEndDate,
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
            decoration: baseInputDecoration(context, hint: 'Доза'),
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
          .map(
            (u) => PopupMenuItem(value: u, child: Text(_menuLabel(u, count))),
          )
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
                    ? context
                          .watch<AppearanceController>()
                          .secondaryColor
                          .withAlpha(128)
                    : context.watch<AppearanceController>().secondaryColor,
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
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor
                          .withAlpha(128),
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
      useShadow: false,
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
              Icon(
                Icons.chevron_right,
                color: context.watch<AppearanceController>().secondaryColor,
                size: 20,
              ),
            ],
          ),
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
              : context.watch<AppearanceController>().secondaryColor.withAlpha(
                  100,
                ),
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
                  color: isTaken
                      ? Colors.white
                      : context.watch<AppearanceController>().secondaryColor,
                ),
                const SizedBox(width: 8),
                Text(
                  time,
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: isTaken
                        ? Colors.white
                        : context.watch<AppearanceController>().secondaryColor,
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
                    color: isTaken
                        ? Colors.white
                        : context.watch<AppearanceController>().secondaryColor,
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
                color: context
                    .watch<AppearanceController>()
                    .secondaryColor
                    .withAlpha(60),
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
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.watch<AppearanceController>().secondaryColor,
              ),
            ),
        ],
      ),

      trailing: IconButton(
        constraints: BoxConstraints(maxWidth: 36, maxHeight: 36),
        onPressed: onRemove,
        icon: Icon(
          Icons.close,
          size: 12,
          color: context.watch<AppearanceController>().secondaryColor,
        ),
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
    //                 ).textTheme.bodySmall!.copyWith(color: context.watch<AppearanceController>().secondaryColor),
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
    //           child: Icon(Icons.close, size: 18, color: context.watch<AppearanceController>().secondaryColor),
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
  late DateTime _date;
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
    _date = DateTime.now();
    _time = TimeOfDay.now();
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now, // приём в будущем отметить нельзя
    );
    if (picked != null) setState(() => _date = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _time);
    if (picked != null) setState(() => _time = picked);
  }

  void _save() {
    final time = DateTime(
      _date.year,
      _date.month,
      _date.day,
      _time.hour,
      _time.minute,
    );
    Navigator.of(context).pop((time: time, doseValue: _value, doseUnit: _unit));
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
                    decoration: baseInputDecoration(context, hint: 'Доза'),
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
            callback: _pickDate,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: Row(
                children: [
                  Icon(Icons.calendar_today, size: 18, color: accent),
                  const SizedBox(width: 8),
                  Text('Дата', style: Theme.of(context).textTheme.bodyMedium),
                  const Spacer(),
                  Text(
                    DateFormat('d MMM yyyy', 'ru_RU').format(_date),
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      fontWeight: FontWeight.w600,
                      color: accent,
                    ),
                  ),
                ],
              ),
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
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                    ),
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
