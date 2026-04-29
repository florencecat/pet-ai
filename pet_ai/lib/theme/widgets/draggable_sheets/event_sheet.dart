import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

enum EventSheetMode { view, create, edit }

extension EventSheetModeX on EventSheetMode {
  bool get isView => this == EventSheetMode.view;
  bool get isEdit => this == EventSheetMode.edit;
  bool get isCreate => this == EventSheetMode.create;
  bool get isEditable => isEdit || isCreate;

  String get label {
    switch (this) {
      case EventSheetMode.view:
        return 'Просмотр события';
      case EventSheetMode.create:
        return 'Новое событие';
      case EventSheetMode.edit:
        return 'Изменение события';
    }
  }
}

class EventSheet extends StatefulWidget {
  final EventSheetMode mode;
  final PetEvent? event;
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
  int _remindBeforeMinutes = 0;

  /// Профили для выбора питомцев
  List<PetProfile> _allProfiles = [];
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
      _remindBeforeMinutes = widget.event!.remindBeforeMinutes;
    }
    _mode = widget.mode;
    _loadProfiles();
  }

  Future<void> _loadProfiles() async {
    final profiles = await ProfileService().loadAllProfiles();
    final activeId = await ProfileService().getActiveProfileId();

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
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() => _selectedTime = picked);
    }
  }

  Future<void> _deleteEvent(BuildContext context, PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Внимание'),
        content: const Text('Вы точно хотите удалить это событие?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.danger),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await EventService().deleteEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createEvent(BuildContext context, PetEvent event) async {
    await EventService().createEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editEvent(BuildContext context, PetEvent event) async {
    await EventService().saveEvent(event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleCompleted() async {
    final event = widget.event!;
    final date = widget.completionDate ?? event.dateTime;
    event.toggleCompletedOn(date);
    await EventService().saveEvent(event);
    setState(() {});
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
        _selectedTime == null ||
        _selectedCategory == null;

    return !hasError;
  }

  void _submitForm() {
    if (!_verifyForm()) return;

    final String name = _nameController.text;
    final EventCategory category = _selectedCategory!;
    final DateTime dateTime = DateTime(
      _selectedDate!.year,
      _selectedDate!.month,
      _selectedDate!.day,
      _selectedTime!.hour,
      _selectedTime!.minute,
    );

    final repeat = _isRepeating ? _selectedRepeat : RepeatInterval.none;
    final customDays = repeat == RepeatInterval.custom ? _customDays : <int>[];
    final petIds = _selectedPetIds.isNotEmpty ? _selectedPetIds : <String>[];

    if (EventSheetModeX(_mode).isCreate) {
      _createEvent(
        context,
        PetEvent(
          name: name,
          category: category,
          dateTime: dateTime,
          repeat: repeat,
          customDays: customDays,
          remindBeforeMinutes: _remindBeforeMinutes,
          petIds: petIds,
        ),
      );
    }
    if (EventSheetModeX(_mode).isEdit) {
      PetEvent event = widget.event!;
      event.assign(
        name,
        category,
        dateTime,
        repeat,
        customDays,
        _remindBeforeMinutes,
        petIds,
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
    return DraggableSheet(
      centerTitle: true,
      title: _mode.label,
      onBack: () => Navigator.of(context).pop(false),
      actions: _buildActions(),
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

  List<Widget> _buildActions() {
    return [
      if (EventSheetModeX(_mode).isView)
        IconButton(
          icon: const Icon(Icons.edit),
          color: ThemeColors.primary,
          onPressed: () => setState(() => _mode = EventSheetMode.edit),
        ),
      if (EventSheetModeX(_mode).isView)
        IconButton(
          icon: const Icon(Icons.delete),
          color: ThemeColors.danger,
          onPressed: () => _deleteEvent(context, widget.event!),
        ),
      if (EventSheetModeX(_mode).isEditable)
        IconButton(
          icon: widget.event?.starred == true
              ? const Icon(Icons.star_rounded)
              : const Icon(Icons.star_outline_rounded),
          color: ThemeColors.primary,
          onPressed: () {
            setState(() {
              if (widget.event != null) {
                widget.event!.starred = !widget.event!.starred;
              }
            });
          },
        ),
      if (EventSheetModeX(_mode).isEditable)
        IconButton(
          icon: const Icon(Icons.check),
          color: ThemeColors.primary,
          onPressed: _submitForm,
        ),
    ];
  }

  // ─── View Mode ─────────────────────────────────────────────────────────────

  List<Widget> _buildViewContent() {
    final event = widget.event!;
    final isCompleted = _isCompletedForDate;

    return [
      // Статус выполнения
      GlassPlate(
        color: isCompleted ? ThemeColors.primary : Colors.white,
        child: InkWell(
          onTap: _toggleCompleted,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle
                      : Icons.radio_button_unchecked,
                  color: isCompleted ? Colors.white : ThemeColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    isCompleted ? 'Выполнено' : 'Отметить выполненным',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isCompleted
                          ? Colors.white
                          : ThemeColors.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      const SizedBox(height: 12),

      // Название
      Text(
        event.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
          decoration: isCompleted ? TextDecoration.lineThrough : null,
        ),
      ),

      const SizedBox(height: 8),

      // Категория
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(event.category.icon, color: event.category.color, size: 20),
          const SizedBox(width: 6),
          Text(
            event.category.name,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w400),
          ),
        ],
      ),

      const SizedBox(height: 8),

      // Дата/время
      GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event, size: 20, color: ThemeColors.border),
              const SizedBox(width: 6),
              Text(
                formatSmartDateTime(event.dateTime),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),

      // Повтор
      if (event.repeat != RepeatInterval.none) ...[
        const SizedBox(height: 8),
        GlassPlate(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            child: Row(
              children: [
                const Icon(Icons.repeat, size: 20, color: ThemeColors.border),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _getRepeatText(event.repeat),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      if (event.repeat == RepeatInterval.custom &&
                          event.customDays.isNotEmpty)
                        Text(
                          event.customDays
                              .map((d) => WeekDays.labels[d] ?? '')
                              .join(', '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (event.remindBeforeMinutes > 0)
                        Text(
                          'Напоминание за ${event.remindBeforeMinutes} мин',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],

      // Питомцы, связанные с событием
      if (event.petIds.isNotEmpty && _profilesLoaded) ...[
        const SizedBox(height: 8),
        _buildPetBadges(event.petIds),
      ],
    ];
  }

  Widget _buildPetBadges(List<String> petIds) {
    final linked = _allProfiles.where((p) => petIds.contains(p.id)).toList();
    if (linked.isEmpty) return const SizedBox.shrink();

    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        child: Row(
          children: [
            const Icon(Icons.pets, size: 20, color: ThemeColors.border),
            const SizedBox(width: 8),
            Wrap(
              spacing: 6,
              children: linked.map((p) {
                return Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: p.palette.mainColor.withAlpha(60),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.palette.mainColor.withAlpha(120)),
                  ),
                  child: Text(
                    p.name.isEmpty ? 'Питомец' : p.name,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: p.palette.mainColor.withAlpha(220),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Edit/Create Mode ──────────────────────────────────────────────────────

  List<Widget> _buildEditableContent() {
    return [
      // Название
      GlassPlate(
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

      // Категория
      GlassPlate(
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

      // Дата и время
      Row(
        children: [
          Expanded(
            child: GlassCard(
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
                          ? ThemeColors.danger
                          : ThemeColors.primary,
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
          const SizedBox(width: 8),
          Expanded(
            child: GlassCard(
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
                          ? ThemeColors.danger
                          : ThemeColors.primary,
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
      ),

      const SizedBox(height: 8),

      // Повтор
      GlassPlate(
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
          activeThumbColor: ThemeColors.primary,
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
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            SizeTransition(sizeFactor: animation, child: child),
        child: _isRepeating ? _buildRepeatOptions() : const SizedBox.shrink(),
      ),

      const SizedBox(height: 8),

      // Напомнить за
      GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(
                Icons.notifications_outlined,
                size: 20,
                color: ThemeColors.primary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Напомнить за (мин):',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: ThemeColors.primary,
                onPressed: _remindBeforeMinutes > 0
                    ? () => setState(() => _remindBeforeMinutes -= 5)
                    : null,
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_remindBeforeMinutes',
                  textAlign: TextAlign.center,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: ThemeColors.primary,
                onPressed: _remindBeforeMinutes < 120
                    ? () => setState(() => _remindBeforeMinutes += 5)
                    : null,
              ),
            ],
          ),
        ),
      ),

      // Связанные питомцы (только если профилей > 1)
      if (_profilesLoaded && _allProfiles.length > 1) ...[
        const SizedBox(height: 8),
        _buildPetSelector(),
      ],
    ];
  }

  Widget _buildPetSelector() {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child:  Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Питомцы', style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: _allProfiles.map((p) {
                final selected = _selectedPetIds.contains(p.id);
                return FilterChip(
                  label: Text(p.name.isEmpty ? 'Без имени' : p.name),
                  selected: selected,
                  selectedColor: p.palette.mainColor.withAlpha(180),
                  backgroundColor: Colors.white.withAlpha(150),
                  labelStyle: TextStyle(
                    fontSize: 13,
                    color: selected ? Colors.white : ThemeColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.normal,
                  ),
                  checkmarkColor: Colors.white,
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        _selectedPetIds.add(p.id);
                      } else if (_selectedPetIds.length > 1) {
                        // Оставляем хотя бы одного питомца
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
      key: const ValueKey('repeat_options'),
      children: [
        const SizedBox(height: 8),

        // Интервал повторения
        GlassPlate(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Интервал повторения',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: RepeatInterval.values
                      .where((e) => e != RepeatInterval.none)
                      .map((interval) {
                        final selected = _selectedRepeat == interval;
                        return ChoiceChip(
                          label: Text(_getRepeatText(interval)),
                          selected: selected,
                          selectedColor: ThemeColors.primary,
                          labelStyle: TextStyle(
                            color: selected
                                ? Colors.white
                                : ThemeColors.textPrimary,
                          ),
                          onSelected: (_) {
                            setState(() => _selectedRepeat = interval);
                          },
                        );
                      })
                      .toList(),
                ),
              ],
            ),
          ),
        ),

        // Выбор дней недели для custom
        if (_selectedRepeat == RepeatInterval.custom) ...[
          const SizedBox(height: 8),
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Дни недели',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: List.generate(7, (i) {
                      final day = i + 1; // 1=Пн..7=Вс
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
                              ? ThemeColors.primary
                              : Colors.white.withAlpha(200),
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
