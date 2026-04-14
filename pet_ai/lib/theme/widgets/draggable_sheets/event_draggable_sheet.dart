import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';

enum EventSheetMode { view, create, edit }

extension EventSheetModeX on EventSheetMode {
  bool get isView => this == EventSheetMode.view;
  bool get isEdit => this == EventSheetMode.edit;
  bool get isCreate => this == EventSheetMode.create;
  bool get isEditable => isEdit || isCreate;

  String get label {
    switch(this) {
      case EventSheetMode.view:
        return 'Просмотр события';
      case EventSheetMode.create:
        return 'Новое событие';
        case EventSheetMode.edit:
        return 'Изменение события';
    }
  }
}

class EventDraggableSheet extends StatefulWidget {
  final EventSheetMode mode;
  final PetEvent? event;
  final DateTime? dateTime;

  const EventDraggableSheet({super.key, required this.event})
    : mode = EventSheetMode.view,
      dateTime = null;
  const EventDraggableSheet.edit({super.key, required this.event})
    : mode = EventSheetMode.edit,
      dateTime = null;
  const EventDraggableSheet.create({super.key, required this.dateTime})
    : mode = EventSheetMode.create,
      event = null;

  @override
  State<EventDraggableSheet> createState() => _EventDraggableSheetState();
}

class _EventDraggableSheetState extends State<EventDraggableSheet> {
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

    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) await EventService().deleteEvent(profileId, event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createEvent(BuildContext context, PetEvent event) async {
    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) await EventService().createEvent(profileId, event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _editEvent(BuildContext context, PetEvent event) async {
    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) await EventService().saveEvent(profileId, event);
    if (context.mounted) Navigator.of(context).pop(true);
  }

  Future<void> _toggleCompleted() async {
    final event = widget.event!;
    final profileId = await ProfileService().getActiveProfileId();
    if (profileId != null) {
      await EventService().toggleCompleted(profileId, event);
      setState(() {});
    }
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
        ),
      );
    }
    if (EventSheetModeX(_mode).isEdit) {
      PetEvent event = widget.event!;
      event.assign(name, category, dateTime, repeat, customDays, _remindBeforeMinutes);
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

    return [
      // Completion status
      GlassPlate(
        color: event.completed ? ThemeColors.primary : Colors.white,
        child: InkWell(
          onTap: _toggleCompleted,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              children: [
                Icon(
                  event.completed ? Icons.check_circle : Icons.radio_button_unchecked,
                  color: event.completed ? Colors.white : ThemeColors.primary,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    event.completed ? 'Выполнено' : 'Отметить выполненным',
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: event.completed ? Colors.white : ThemeColors.textPrimary,
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

      // Event name
      Text(
        event.name,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleLarge!.copyWith(
          decoration: event.completed ? TextDecoration.lineThrough : null,
        ),
      ),

      const SizedBox(height: 8),

      // Category
      Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(event.category.icon, color: event.category.color, size: 20),
          const SizedBox(width: 6),
          Text(
            event.category.name,
            style: Theme.of(context).textTheme.bodyLarge!.copyWith(
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),

      const SizedBox(height: 8),

      // Date/time
      GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.event, size: 20, color: ThemeColors.border),
              const SizedBox(width: 6),
              Text(
                DateFormat('d MMMM в HH:mm', 'ru-RU').format(event.dateTime),
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),

      // Repeat info
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
    ];
  }

  // ─── Edit/Create Mode ──────────────────────────────────────────────────────

  List<Widget> _buildEditableContent() {
    return [
      // Name field
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
            validator: (v) => v == null || v.isEmpty ? 'Введите название' : null,
          ),
        ),
      ),

      const SizedBox(height: 8),

      // Category picker
      GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: DropdownButtonFormField<String>(
            validator: (v) => v == null || v.isEmpty ? 'Выберите категорию' : null,
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
                        Text(c.name, style: Theme.of(context).textTheme.bodyMedium),
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

      // Date & Time row
      Row(
        children: [
          Expanded(
            child: GlassCard(
              callback: () => _selectDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.calendar_today,
                      size: 18,
                      color: _selectedDate == null
                          ? ThemeColors.danger
                          : ThemeColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _selectedDate == null
                          ? 'Дата'
                          : DateFormat('dd.MM.yyyy').format(_selectedDate!),
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
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.access_time,
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

      // Repeat toggle
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

      // Repeat options (animated)
      AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            SizeTransition(sizeFactor: animation, child: child),
        child: _isRepeating
            ? _buildRepeatOptions()
            : const SizedBox.shrink(),
      ),

      const SizedBox(height: 8),

      // Remind before
      GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              const Icon(Icons.notifications_outlined,
                  size: 20, color: ThemeColors.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Напомнить за (мин):',
                  style: Theme.of(context).textTheme.bodyMedium,
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
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
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
    ];
  }

  Widget _buildRepeatOptions() {
    return Column(
      key: const ValueKey('repeat_options'),
      children: [
        const SizedBox(height: 8),

        // Repeat interval selector as chips
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
                        color: selected ? Colors.white : ThemeColors.textPrimary,
                      ),
                      onSelected: (_) {
                        setState(() => _selectedRepeat = interval);
                      },
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),

        // Custom weekday picker
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
