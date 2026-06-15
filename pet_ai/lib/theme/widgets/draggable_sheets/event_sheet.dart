import 'package:flutter/material.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

enum EventSheetMode { view, create, edit }

extension EventSheetModeX on EventSheetMode {
  bool get isView => this == EventSheetMode.view;
  bool get isEdit => this == EventSheetMode.edit;
  bool get isCreate => this == EventSheetMode.create;
  bool get isEditable => isEdit || isCreate;

  String get label {
    switch (this) {
      case EventSheetMode.view:
        return 'Событие';
      case EventSheetMode.create:
        return 'Новое событие';
      case EventSheetMode.edit:
        return 'Редактирование';
    }
  }
}

class EventSheet extends StatefulWidget {
  final EventSheetMode mode;
  final Event? event;
  final DateTime? dateTime;

  /// Дата вхождения, для которой проверяется/переключается статус выполнения.
  /// Актуально при открытии из календаря (selectedDay).
  /// Если null — используется event.dateTime.
  final DateTime? completionDate;

  const EventSheet({super.key, required this.event, this.completionDate})
    : mode = EventSheetMode.view,
      dateTime = null;
  const EventSheet.edit({super.key, required this.event})
    : mode = EventSheetMode.edit,
      dateTime = null,
      completionDate = null;
  const EventSheet.create({super.key, required this.dateTime})
    : mode = EventSheetMode.create,
      event = null,
      completionDate = null;

  @override
  State<EventSheet> createState() => _EventSheetState();
}

class _EventSheetState extends State<EventSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  EventCategory? _selectedCategory;
  EventSheetMode _mode = EventSheetMode.view;

  bool _isRepeating = false;
  RepeatInterval _selectedRepeat = RepeatInterval.none;
  List<int> _customDays = [];

  bool _allDay = false;

  RemindBeforeVariant _remindBeforeVariant = RemindBeforeVariant.days;
  int _remindBeforeValue = 0;

  bool _remind = true;

  List<Pet> _allProfiles = [];
  List<String> _selectedPetIds = [];
  bool _profilesLoaded = false;

  @override
  void initState() {
    super.initState();
    if (widget.dateTime != null && _selectedDate == null) {
      _selectedDate = widget.dateTime;
    } else if (widget.event != null) {
      _nameController.text = widget.event!.name;
      _selectedCategory = widget.event!.category;
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);
      _selectedRepeat = widget.event!.repeat;
      _isRepeating = _selectedRepeat != RepeatInterval.none;
      _customDays = List.of(widget.event!.customDays);
      _allDay = widget.event!.allDay;
      _remindBeforeValue = widget.event!.remindBeforeValue;
      _remind = widget.event!.remind;
    }
    _mode = widget.mode;
    _loadProfiles();
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _loadProfiles() async {
    final profiles = await PetService().loadAllProfiles();
    final activeId = await PetService().getActiveProfileId();

    List<String> preselected;
    if (widget.mode == EventSheetMode.create) {
      preselected = activeId != null ? [activeId] : [];
    } else if (widget.event != null && widget.event!.petIds.isNotEmpty) {
      preselected = List.of(widget.event!.petIds);
    } else {
      preselected = activeId != null ? [activeId] : [];
    }

    if (mounted) {
      setState(() {
        _allProfiles = profiles;
        _selectedPetIds = preselected;
        _profilesLoaded = true;
      });
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 2)),
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _deleteEvent(BuildContext context, Event event) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить событие?',
      message: 'Событие будет удалено без возможности восстановления.',
    );
    if (!confirmed) return;
    await EventService().deleteEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createEvent(BuildContext context, Event event) async {
    await EventService().createEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editEvent(BuildContext context, Event event) async {
    await EventService().saveEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleCompleted() async {
    final event = widget.event!;
    final petId = event.petIds.isNotEmpty ? event.petIds.first : '';
    final date = widget.completionDate ?? event.dateTime;
    await EventService().toggleCompleted(petId, event, date);
    setState(() { });
  }

  bool get _isCompletedForDate {
    final event = widget.event;
    if (event == null) return false;
    final date = widget.completionDate ?? event.dateTime;
    return event.isCompletedOn(date);
  }

  bool _verifyForm() {
    final hasError =
        !_formKey.currentState!.validate() ||
        _selectedDate == null ||
        (!_allDay && _selectedTime == null) ||
        _selectedCategory == null;
    return !hasError;
  }

  void _submitForm() {
    if (!_verifyForm()) return;

    final name = _nameController.text;
    final category = _selectedCategory!;
    // Для события на весь день время не задаётся — фиксируем 00:00.
    final dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _allDay ? 0 : _selectedTime!.hour,
      _allDay ? 0 : _selectedTime!.minute,
    );
    final repeat = _isRepeating ? _selectedRepeat : RepeatInterval.none;
    final customDays = repeat == RepeatInterval.custom ? _customDays : <int>[];
    final petIds = _selectedPetIds.isNotEmpty ? _selectedPetIds : <String>[];

    if (EventSheetModeX(_mode).isCreate) {
      _createEvent(
        context,
        Event(
          name: name,
          category: category,
          dateTime: dateTime,
          repeat: repeat,
          customDays: customDays,
          allDay: _allDay,
          remindBeforeVariant: _remindBeforeVariant,
          remindBeforeValue: _remindBeforeValue,
          remind: _remind,
          petIds: petIds,
        ),
      );
    }
    if (EventSheetModeX(_mode).isEdit) {
      final event = widget.event!;
      event.assign(
        name,
        category,
        dateTime,
        repeat,
        customDays,
        _remindBeforeVariant,
        _remindBeforeValue,
        petIds,
        remind: _remind,
        allDay: _allDay,
      );
      _editEvent(context, event);
    }
  }

  String _getRepeatText(RepeatInterval interval) {
    switch (interval) {
      case RepeatInterval.none:
        return 'Не повторять';
      case RepeatInterval.daily:
        return 'Каждый день';
      case RepeatInterval.weekly:
        return 'Каждую неделю';
      case RepeatInterval.monthly:
        return 'Каждый месяц';
      case RepeatInterval.custom:
        return 'Выбрать дни';
    }
  }

  @override
  Widget build(BuildContext context) {
    // For pill/treatment events opened in view mode, disable editing
    // (those records are managed via the Health page).
    final editable = widget.event == null || widget.event!.manual;

    return DraggableSheet(
      centerTitle: true,
      title: _mode.label,
      onBack: () => Navigator.of(context).pop(),
      initialSize: _mode.isView ? 0.65 : 0.85,
      minSize: 0.4,
      maxSize: 0.95,
      actions: _buildActions(editable),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (EventSheetModeX(_mode).isEditable)
              ..._buildEditableContent()
            else
              ..._buildViewContent(),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildActions(bool editable) {
    if (EventSheetModeX(_mode).isView) {
      if (!editable) {
        // Linked events can only be deleted; editing must go through Health page
        return [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            color: ThemeColors.dangerZone,
            onPressed: () => _deleteEvent(context, widget.event!),
          ),
        ];
      }
      return [
        IconButton(
          icon: const Icon(Icons.edit_outlined),
          color: context.watch<AppearanceController>().primaryColor,
          onPressed: () => setState(() => _mode = EventSheetMode.edit),
        ),
        IconButton(
          icon: const Icon(Icons.delete_outline),
          color: ThemeColors.dangerZone,
          onPressed: () => _deleteEvent(context, widget.event!),
        ),
      ];
    }
    // Edit / create
    return [
      IconButton(
        icon: widget.event?.starred == true
            ? const Icon(Icons.star_rounded)
            : const Icon(Icons.star_outline_rounded),
        color: context.watch<AppearanceController>().primaryColor,
        onPressed: () {
          setState(() {
            if (widget.event != null) {
              widget.event!.starred = !widget.event!.starred;
            }
          });
        },
      ),
      IconButton(
        icon: const Icon(Icons.check),
        color: context.watch<AppearanceController>().primaryColor,
        onPressed: _submitForm,
      ),
    ];
  }

  // ─── View Mode ─────────────────────────────────────────────────────────────

  List<Widget> _buildViewContent() {
    final event = widget.event!;
    final isCompleted = _isCompletedForDate;
    final accent = context.watch<AppearanceController>().primaryColor;
    final catColor = event.category == EventCategories.empty
        ? ThemeColors.border
        : event.category.color;

    return [
      // ── Hero ──────────────────────────────────────────────────────────────
      Center(
        child: Column(
          children: [
            // Icon
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: catColor.withAlpha(20),
                border: Border.all(color: catColor.withAlpha(60), width: 1.5),
              ),
              child: Icon(event.category.icon, color: catColor, size: 34),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              event.name,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                fontWeight: FontWeight.w700,
                decoration: isCompleted ? TextDecoration.lineThrough : null,
                color: isCompleted ? ThemeColors.border : null,
              ),
            ),

            const SizedBox(height: 8),

            // Category chip
            if (event.category != EventCategories.empty)
              _CategoryTag(category: event.category),

            // Source badge
            if (event.source != EventSource.manual) ...[
              const SizedBox(height: 6),
              _SourceTag(source: event.source),
            ],
          ],
        ),
      ),

      const SizedBox(height: 20),

      // ── Info rows ─────────────────────────────────────────────────────────
      GlassPlate(
        padding: 0,
        child: Column(
          children: [
            _InfoRow(
              icon: Icons.calendar_today_outlined,
              iconColor: accent,
              label: event.allDay
                  ? '${formatSmartDate(event.dateTime)} · Весь день'
                  : formatSmartDateTime(event.dateTime),
            ),
            if (event.repeat != RepeatInterval.none) ...[
              const _RowDivider(),
              _InfoRow(
                icon: Icons.repeat,
                iconColor: accent,
                label: _getRepeatText(event.repeat),
                sublabel:
                    event.repeat == RepeatInterval.custom &&
                        event.customDays.isNotEmpty
                    ? event.customDays
                          .map((d) => WeekDays.labels[d] ?? '')
                          .join(', ')
                    : null,
              ),
            ],
            if (event.remindBeforeValue > 0) ...[
              const _RowDivider(),
              _InfoRow(
                icon: Icons.notifications_outlined,
                iconColor: accent,
                label: 'Напоминание за ${event.remindBeforeValue} мин',
              ),
            ],
            if (event.petIds.isNotEmpty && _profilesLoaded) ...[
              const _RowDivider(),
              _PetsInfoRow(
                petIds: event.petIds,
                profiles: _allProfiles,
                accent: accent,
              ),
            ],
          ],
        ),
      ),

      if (widget.event!.completable) ...[
        const SizedBox(height: 12),

        // ── Completion button ─────────────────────────────────────────────────
        _CompletionButton(
          isCompleted: isCompleted,
          accent: accent,
          onTap: _toggleCompleted,
        ),
      ],
    ];
  }

  // ─── Edit/Create Mode ──────────────────────────────────────────────────────

  List<Widget> _buildEditableContent() {
    return [
      GlassPlate(
        useShadow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: TextFormField(
            controller: _nameController,
            decoration: const InputDecoration(
              labelText: 'Название',
              border: InputBorder.none,
            ),
            style: Theme.of(context).textTheme.bodyMedium,
            validator: (v) =>
                v == null || v.isEmpty ? 'Введите название' : null,
          ),
        ),
      ),

      const SizedBox(height: 8),

      GlassPlate(
        useShadow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonFormField<String>(
            validator: (v) =>
                v == null || v.isEmpty ? 'Выберите категорию' : null,
            decoration: const InputDecoration(
              labelText: 'Категория',
              border: InputBorder.none,
            ),
            dropdownColor: Colors.white,
            initialValue: widget.event?.category.id,
            style: Theme.of(context).textTheme.bodyMedium,
            items: EventCategories.all
                .skip(1)
                .map(
                  (c) => DropdownMenuItem(
                    value: c.id,
                    child: Row(
                      children: [
                        Icon(c.icon, color: c.color),
                        const SizedBox(width: 8),
                        Text(
                          c.name,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                )
                .toList(),
            onChanged: (v) => setState(() {
              if (v != null) _selectedCategory = EventCategories.byId(v);
            }),
          ),
        ),
      ),

      const SizedBox(height: 8),

      Row(
        children: [
          Expanded(
            child: GlassCard(
              useShadow: false,
              callback: () => _selectDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: 12,
                  horizontal: 8,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: _selectedDate == null
                          ? ThemeColors.dangerZone
                          : context.watch<AppearanceController>().primaryColor,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDate == null
                          ? 'Дата'
                          : formatSmartDate(_selectedDate!),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Время скрывается, когда событие на весь день.
          if (!_allDay) ...[
            const SizedBox(width: 8),
            Expanded(
              child: GlassCard(
                useShadow: false,
                callback: () => _selectTime(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 12,
                    horizontal: 8,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.access_time,
                        size: 18,
                        color: _selectedTime == null
                            ? ThemeColors.dangerZone
                            : context
                                  .watch<AppearanceController>()
                                  .primaryColor,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        _selectedTime == null
                            ? 'Время'
                            : _selectedTime!.format(context),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),

      const SizedBox(height: 8),

      GlassPlate(
        useShadow: false,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            'Весь день',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            'Без точного времени',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _allDay,
          activeThumbColor: context.watch<AppearanceController>().primaryColor,
          onChanged: (val) => setState(() => _allDay = val),
        ),
      ),

      const SizedBox(height: 8),

      GlassPlate(
        useShadow: false,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            'Напоминать',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            'Отслеживать статус выполнения и отправлять push-уведомление',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _remind,
          activeThumbColor: context.watch<AppearanceController>().primaryColor,
          onChanged: (val) => setState(() => _remind = val),
        ),
      ),

      AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        transitionBuilder: (child, animation) =>
            SizeTransition(sizeFactor: animation, child: child),
        child: _remind
            ? Column(children: _buildRemindOptions())
            : const SizedBox.shrink(),
      ),

      if (_profilesLoaded && _allProfiles.length > 1) ...[
        const SizedBox(height: 8),
        _buildPetSelector(),
      ],
    ];
  }

  List<Widget> _buildRemindOptions() {
    return [
      const SizedBox(height: 8),

      GlassPlate(
        useShadow: false,
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text(
            'Повторять',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          subtitle: Text(
            'Сделать событие регулярным',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          value: _isRepeating,
          activeThumbColor: context.watch<AppearanceController>().primaryColor,
          onChanged: (val) {
            setState(() {
              _isRepeating = val;
              if (_isRepeating && _selectedRepeat == RepeatInterval.none) {
                _selectedRepeat = RepeatInterval.daily;
              }
            });
          },
        ),
      ),

      AnimatedSwitcher(
        duration: const Duration(milliseconds: 120),
        transitionBuilder: (child, animation) =>
            SizeTransition(sizeFactor: animation, child: child),
        child: _isRepeating ? _buildRepeatOptions() : const SizedBox.shrink(),
      ),

      const SizedBox(height: 8),

      GlassPlate(
        useShadow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Icon(
                Icons.notifications_outlined,
                size: 20,
                color: context.watch<AppearanceController>().primaryColor,
              ),
              const SizedBox(width: 8),
              Text(
                'Напомнить за',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: context.watch<AppearanceController>().primaryColor,
                onPressed: _remindBeforeValue > 0
                    ? () => setState(
                        () => _remindBeforeValue -=
                            _remindBeforeVariant == RemindBeforeVariant.minutes
                            ? 5
                            : 1,
                      )
                    : null,
              ),
              SizedBox(
                width: 25,
                child: Text(
                  '$_remindBeforeValue',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: context.watch<AppearanceController>().primaryColor,
                onPressed: _remindBeforeValue < 120
                    ? () => setState(
                        () => _remindBeforeValue +=
                            _remindBeforeVariant == RemindBeforeVariant.minutes
                            ? 5
                            : 1,
                      )
                    : null,
              ),
              const SizedBox(width: 8),
              PopupMenuButton<RemindBeforeVariant>(
                initialValue: RemindBeforeVariant.minutes,
                itemBuilder: (_) => RemindBeforeVariant.values
                    .map((v) => PopupMenuItem(value: v, child: Text(v.label)))
                    .toList(),
                onSelected: (v) => setState(() {
                  if (v != _remindBeforeVariant) {
                    _remindBeforeValue = 0;
                  }
                  _remindBeforeVariant = v;
                }),
                enableFeedback: true,
                child: Row(
                  children: [
                    Text(
                      _remindBeforeVariant.declension(_remindBeforeValue),
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    Icon(
                      Icons.expand_more,
                      size: 24,
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildPetSelector() {
    return GlassPlate(
      useShadow: false,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Питомцы', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _allProfiles.map((p) {
                final selected = _selectedPetIds.contains(p.id);
                return SoftGlassBadge(
                  label: p.name.isEmpty ? 'Без имени' : p.name,
                  color: p.palette.mainColor,
                  size: 12,
                  selected: selected,
                  icon: selected ? Icons.check_rounded : null,
                  onChanged: (val) {
                    setState(() {
                      if (val) {
                        _selectedPetIds.add(p.id);
                      } else if (_selectedPetIds.length > 1) {
                        _selectedPetIds.remove(p.id);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRepeatOptions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      key: const ValueKey('repeat_options'),
      children: [
        const SizedBox(height: 8),
        GlassPlate(
          useShadow: false,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Интервал повторения',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Wrap(
                  children: RepeatInterval.values
                      .where((e) => e != RepeatInterval.none)
                      .map((interval) {
                        final selected = _selectedRepeat == interval;

                        return Padding(
                          padding: EdgeInsetsGeometry.all(4),
                          child: SoftGlassBadge(
                            label: _getRepeatText(interval),
                            size: 12,
                            selected: selected,
                            color: selected
                                ? context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                : context
                                      .watch<AppearanceController>()
                                      .secondaryColor,
                            onChanged: (_) =>
                                setState(() => _selectedRepeat = interval),
                          ),
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        ),
        if (_selectedRepeat == RepeatInterval.custom) ...[
          const SizedBox(height: 8),
          GlassPlate(
            useShadow: false,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дни недели',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final day = i + 1;
                      final selected = _customDays.contains(day);
                      return GestureDetector(
                        onTap: () {
                          setState(() {
                            if (selected) {
                              _customDays.remove(day);
                            } else {
                              _customDays.add(day);
                            }
                          });
                        },
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: selected
                              ? context
                                    .watch<AppearanceController>()
                                    .primaryColor
                              : context
                                    .watch<AppearanceController>()
                                    .primaryColor
                                    .withAlpha(48),
                          child: Text(
                            WeekDays.labels[day]!,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: selected
                                  ? Colors.white
                                  : ThemeColors.textPrimary,
                            ),
                          ),
                        ),
                      );
                    }),
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ─── View-mode helpers ────────────────────────────────────────────────────────

class _CategoryTag extends StatelessWidget {
  final EventCategory category;
  const _CategoryTag({required this.category});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: category.color.withAlpha(20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: category.color.withAlpha(60)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(category.icon, size: 13, color: category.color),
          const SizedBox(width: 5),
          Text(
            category.name,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: category.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SourceTag extends StatelessWidget {
  final EventSource source;
  const _SourceTag({required this.source});

  @override
  Widget build(BuildContext context) {
    final (label, icon, color) = switch (source) {
      EventSource.pill => (
        'Препарат',
        Icons.medication_outlined,
        const Color(0xFF5C6BC0),
      ),
      EventSource.treatment => (
        'Прививка / обработка',
        Icons.vaccines_outlined,
        const Color(0xFF00897B),
      ),
      EventSource.note => (
        'Из заметки',
        Icons.note_outlined,
        ThemeColors.border,
      ),
      _ => ('', Icons.circle, ThemeColors.border),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withAlpha(15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(50)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color.withAlpha(180)),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              color: color.withAlpha(200),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String? sublabel;

  const _InfoRow({
    required this.icon,
    required this.iconColor,
    required this.label,
    this.sublabel,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
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

class _PetsInfoRow extends StatelessWidget {
  final List<String> petIds;
  final List<Pet> profiles;
  final Color accent;

  const _PetsInfoRow({
    required this.petIds,
    required this.profiles,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final linked = profiles.where((p) => petIds.contains(p.id)).toList();
    if (linked.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.pets, size: 18, color: accent),
          const SizedBox(width: 12),
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: linked.map((p) {
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: p.palette.mainColor.withAlpha(25),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: p.palette.mainColor.withAlpha(80)),
                ),
                child: Text(
                  p.name.isEmpty ? 'Питомец' : p.name,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: p.palette.mainColor,
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 46,
    endIndent: 0,
    color: ThemeColors.border.withAlpha(60),
  );
}

class _CompletionButton extends StatelessWidget {
  final bool isCompleted;
  final Color accent;
  final VoidCallback onTap;

  const _CompletionButton({
    required this.isCompleted,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: isCompleted ? accent : Colors.white,
        border: Border.all(
          color: isCompleted ? accent : ThemeColors.border.withAlpha(100),
        ),
        boxShadow: isCompleted
            ? [
                BoxShadow(
                  color: accent.withAlpha(60),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: Icon(
                    isCompleted
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    key: ValueKey(isCompleted),
                    color: isCompleted ? Colors.white : accent,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  isCompleted ? 'Выполнено' : 'Отметить выполненным',
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: isCompleted ? Colors.white : ThemeColors.textPrimary,
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
