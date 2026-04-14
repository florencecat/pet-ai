import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';

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
  final _dateController = WidgetStatesController();
  final _timeController = WidgetStatesController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;
  EventCategory? _selectedCategory;
  EventSheetMode _mode = EventSheetMode.view;

  bool _isRepeating = false;
  RepeatInterval _selectedRepeat = RepeatInterval.none;
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
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
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

  bool _verifyForm() {
    final hasError =
        !_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null ||
        _selectedCategory == null;

    setState(() {
      _dateController.update(WidgetState.error, _selectedDate == null);
      _timeController.update(WidgetState.error, _selectedTime == null);
    });

    return !hasError;
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
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      centerTitle: true,
      title: widget.mode.label,
      onBack: () => Navigator.of(context).pop(false),
      actions: [
        if (EventSheetModeX(_mode).isView)
          IconButton(
            icon: const Icon(Icons.edit),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              setState(() {
                _mode = EventSheetMode.edit;
              });
            },
            enableFeedback: true,
          ),
        if (EventSheetModeX(_mode).isView)
          IconButton(
            icon: const Icon(Icons.delete),
            color: ThemeColors.danger,
            onPressed: () => _deleteEvent(context, widget.event!),
            enableFeedback: true,
          ),
        if (EventSheetModeX(_mode).isEditable)
          IconButton(
            icon: widget.event?.starred == true
                ? const Icon(Icons.star_rounded)
                : const Icon(Icons.star_outline_rounded),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
              setState(() {
                if (widget.event != null) {
                  widget.event!.starred = !widget.event!.starred;
                }
              });
            },
            enableFeedback: true,
          ),
        if (EventSheetModeX(_mode).isEditable)
          IconButton(
            icon: const Icon(Icons.check),
            color: Theme.of(context).colorScheme.primary,
            onPressed: () {
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

              final repeat = _isRepeating
                  ? _selectedRepeat
                  : RepeatInterval.none;

              if (EventSheetModeX(_mode).isCreate) {
                _createEvent(
                  context,
                  PetEvent(
                    name: name,
                    category: category,
                    dateTime: dateTime,
                    repeat: repeat,
                    remindBeforeMinutes: _remindBeforeMinutes,
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
                  _remindBeforeMinutes,
                );
                _editEvent(context, event);
              }
            },
          ),
      ],
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            if (EventSheetModeX(_mode).isEditable)
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Название',
                  labelStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                    inherit: true,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: Theme.of(context).textTheme.bodyMedium,
                validator: (v) =>
                    v == null || v.isEmpty ? 'Введите название' : null,
              )
            else
              Text(
                textAlign: TextAlign.center,
                widget.event?.name ?? "",
                style: Theme.of(context).textTheme.titleLarge,
              ),

            const SizedBox(height: 8),

            if (EventSheetModeX(_mode).isEditable)
              DropdownButtonFormField<String>(
                validator: (v) =>
                    v == null || v.isEmpty ? 'Выберите категорию' : null,
                decoration: InputDecoration(
                  labelText: 'Категория',
                  labelStyle: Theme.of(context).textTheme.titleMedium!.copyWith(
                    inherit: true,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
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
                  if (v != null) {
                    _selectedCategory = EventCategories.byId(v);
                  }
                }),
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    widget.event!.category.icon,
                    color: widget.event!.category.color,
                    size: 20,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    textAlign: TextAlign.center,
                    widget.event!.category.name,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      inherit: true,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),

            const SizedBox(height: 8),

            if (EventSheetModeX(_mode).isEditable)
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      statesController: _dateController,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            _dateController.value.contains(WidgetState.error)
                            ? ThemeColors.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.calendar_today),
                      label: Text(
                        _selectedDate == null
                            ? 'Выбрать дату'
                            : DateFormat('dd.MM.yyyy').format(_selectedDate!),
                      ),
                      onPressed: () => _selectDate(context),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextButton.icon(
                      statesController: _timeController,
                      style: TextButton.styleFrom(
                        foregroundColor:
                            _timeController.value.contains(WidgetState.error)
                            ? ThemeColors.error
                            : Theme.of(context).colorScheme.primary,
                      ),
                      icon: const Icon(Icons.access_time),
                      label: Text(
                        _selectedTime == null
                            ? 'Выбрать время'
                            : _selectedTime!.format(context),
                      ),
                      onPressed: () => _selectTime(context),
                    ),
                  ),
                ],
              )
            else
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.event, size: 20, color: ThemeColors.border),
                  const SizedBox(width: 6),
                  Text(
                    DateFormat(
                      'd MMMM в HH:mm',
                      'ru-RU',
                    ).format(widget.event!.dateTime),
                  ),
                ],
              ),

            if (EventSheetModeX(_mode).isEditable) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.all(0),
                title: Text(
                  'Повторять',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                subtitle: Text(
                  'Сделать событие регулярным',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                value: _isRepeating,
                activeColor: Theme.of(context).dividerColor,
                onChanged: (val) {
                  setState(() {
                    _isRepeating = val ?? false;
                    if (_isRepeating &&
                        _selectedRepeat == RepeatInterval.none) {
                      _selectedRepeat = RepeatInterval.daily;
                    }
                  });
                },
              ),
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return SizeTransition(sizeFactor: animation, child: child);
                },
                child: _isRepeating
                    ? Column(
                        children: [
                          DropdownButtonFormField<RepeatInterval>(
                            initialValue: _selectedRepeat == RepeatInterval.none
                                ? RepeatInterval.daily
                                : _selectedRepeat,
                            decoration: InputDecoration(
                              labelText: 'Интервал повторения',
                              labelStyle: Theme.of(context)
                                  .textTheme
                                  .titleMedium!
                                  .copyWith(
                                    inherit: true,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                            ),
                            items: RepeatInterval.values
                                .where((e) => e != RepeatInterval.none)
                                .map((e) {
                                  return DropdownMenuItem(
                                    value: e,
                                    child: Text(
                                      _getRepeatText(e),
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyLarge!
                                          .copyWith(
                                            inherit: true,
                                            fontWeight: FontWeight.w400,
                                          ),
                                    ),
                                  );
                                })
                                .toList(),
                            onChanged: (val) =>
                                setState(() => _selectedRepeat = val!),
                          ),
                          const SizedBox(height: 16),
                          Row(
                            children: [
                              const Expanded(
                                child: Text('Напомнить за (мин):'),
                              ),
                              IconButton(
                                icon: const Icon(Icons.remove_circle_outline),
                                onPressed: _remindBeforeMinutes > 0
                                    ? () => setState(
                                        () => _remindBeforeMinutes -= 5,
                                      )
                                    : null,
                              ),
                              SizedBox(
                                width: 40,
                                child: Text(
                                  '$_remindBeforeMinutes',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.add_circle_outline),
                                onPressed: _remindBeforeMinutes < 120
                                    ? () => setState(
                                        () => _remindBeforeMinutes += 5,
                                      )
                                    : null,
                              ),
                            ],
                          ),
                        ],
                      )
                    : const SizedBox.shrink(),
              ),
            ] else ...[
              // Просмотр повторений
              if (widget.event?.repeat != RepeatInterval.none)
                ListTile(
                  leading: const Icon(Icons.repeat, color: ThemeColors.border),
                  title: Text(_getRepeatText(widget.event!.repeat)),
                  subtitle: widget.event!.remindBeforeMinutes > 0
                      ? Text(
                          'Напоминание за ${widget.event!.remindBeforeMinutes} мин',
                        )
                      : null,
                ),
            ],
          ],
        ),
      ),
    );
  }
}
