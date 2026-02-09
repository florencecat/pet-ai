import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/theme/app_styles.dart';

import '../../services/event_service.dart';
//import '../../theme/widgets/validated_icon_button.dart';

enum EventSheetMode { view, create, edit }

final DraggableScrollableController _sheetController =
    DraggableScrollableController();


extension EventSheetModeX on EventSheetMode {
  bool get isView => this == EventSheetMode.view;
  bool get isEdit => this == EventSheetMode.edit;
  bool get isCreate => this == EventSheetMode.create;

  bool get isEditable => isEdit || isCreate;
}

class EventDraggableSheet extends StatefulWidget {
  EventSheetMode mode;
  final PetEvent? event;
  final DateTime? dateTime;
  final VoidCallback onClose;

  EventDraggableSheet({
    super.key,
    required this.event,
    required this.onClose,
  }) : mode = EventSheetMode.view,
       dateTime = null;
  EventDraggableSheet.edit({
    super.key,
    required this.event,
    required this.onClose,
  }) : mode = EventSheetMode.edit,
       dateTime = null;
  EventDraggableSheet.create({
    super.key,
    required this.dateTime,
    required this.onClose,
  }) : mode = EventSheetMode.create,
       event = null;

  @override
  State<EventDraggableSheet> createState() => _EventDraggableSheetState();
}

class _EventDraggableSheetState extends State<EventDraggableSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _categoryController = TextEditingController();
  final _dateController = WidgetStatesController();
  final _timeController = WidgetStatesController();
  DateTime? _selectedDate;
  TimeOfDay? _selectedTime;

  _EventDraggableSheetState();

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
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
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedTime = picked;
      });
    }
  }

  void collapseSheet() {
    _sheetController.animateTo(
      0.45,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void expandSheet() {
    _sheetController.animateTo(
      0.9,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
    );
  }

  void closeSheet(BuildContext context) {
    widget.onClose.call();
    Navigator.of(context).pop();
  }

  Future<void> deleteEvent(BuildContext context, PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(title: const Text('Внимание'),
        content: const Text('Вы точно хотите удалить это событие?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Нет'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: dangerColor),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    await EventService().deleteEvent(event);

    if (context.mounted) closeSheet(context);
  }

  Future<void> createEvent(BuildContext context, PetEvent event) async {
    EventService().createEvent(event);
    if (context.mounted) closeSheet(context);
  }

  Future<void> editEvent(BuildContext context, PetEvent event) async {
    EventService().saveEvent(event);
    if (context.mounted) closeSheet(context);
  }

  bool _verifyForm() {
    final hasError =
        !_formKey.currentState!.validate() ||
        _selectedDate == null ||
        _selectedTime == null;

    setState(() {
      _dateController.update(WidgetState.error, _selectedDate == null);
      _timeController.update(WidgetState.error, _selectedTime == null);
    });

    return !hasError;
  }

  @override
  Widget build(BuildContext context) {
    if (widget.dateTime != null && _selectedDate == null) {
      _selectedDate = widget.dateTime;
    }
    else if (widget.event != null) {
      _nameController.text = widget.event!.name;
      _categoryController.text = widget.event!.category;
      _selectedDate = widget.event!.dateTime;
      _selectedTime = TimeOfDay.fromDateTime(widget.event!.dateTime);
    }
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.45, 0.85],
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Form(
            key: _formKey,
            child: ListView(
              controller: scrollController,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
              children: [
                // DRAG HANDLE
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade400,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),

                SizedBox(
                  height: 48,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: mainColor,
                        onPressed: () => closeSheet(context),
                      ),
                      const Spacer(),
                      if (EventSheetModeX(widget.mode).isView)
                        IconButton(
                          icon: const Icon(Icons.edit),
                          color: mainColor,
                          onPressed: () {
                            setState(() {
                              widget.mode = EventSheetMode.edit;
                            });
                          },
                        ),
                      if (EventSheetModeX(widget.mode).isView)
                        IconButton(
                          icon: const Icon(Icons.delete),
                          color: dangerColor,
                          onPressed: () => deleteEvent(context, widget.event!),
                        ),
                      if (EventSheetModeX(widget.mode).isEditable)
                        IconButton(
                          icon: const Icon(Icons.check),
                          color: mainColor,
                          onPressed: () {
                            if (!_verifyForm()) return;

                            final String name = _nameController.text;
                            final String category = _categoryController.text;
                            final DateTime dateTime = DateTime(
                              _selectedDate!.year,
                              _selectedDate!.month,
                              _selectedDate!.day,
                              _selectedTime!.hour,
                              _selectedTime!.minute,
                            );

                            if (EventSheetModeX(widget.mode).isCreate) {
                              createEvent(context, PetEvent(name: name, category: category, dateTime: dateTime));
                            }
                            if (EventSheetModeX(widget.mode).isEdit) {
                              PetEvent event = widget.event!;
                              event.assign(name, category, dateTime);
                              editEvent(context, event);
                            }
                          },
                        ),
                    ],
                  ),
                ),

                if (EventSheetModeX(widget.mode).isEditable)
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(labelText: 'Название'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите название' : null,
                  )
                else
                  Text(
                    textAlign: TextAlign.center,
                    widget.event?.name ?? "",
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),

                const SizedBox(height: 8),

                if (EventSheetModeX(widget.mode).isEditable)
                  TextFormField(
                    controller: _categoryController,
                    decoration: const InputDecoration(labelText: 'Категория'),
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Введите категорию' : null,
                  )
                else
                  Text(
                    textAlign: TextAlign.center,
                    widget.event?.name ?? "",
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),

                const SizedBox(height: 16),

                if (EventSheetModeX(widget.mode).isEditable)
                  Row(
                    children: [
                      Expanded(
                        child: TextButton.icon(
                          statesController: _dateController,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                _dateController.value.contains(
                                  WidgetState.error,
                                )
                                ? errorColor
                                : mainColor,
                          ),
                          icon: const Icon(Icons.calendar_today),
                          label: Text(
                            _selectedDate == null
                                ? 'Выбрать дату'
                                : DateFormat(
                                    'dd.MM.yyyy',
                                  ).format(_selectedDate!),
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
                                _timeController.value.contains(
                                  WidgetState.error,
                                )
                                ? errorColor
                                : mainColor,
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
                      Icon(Icons.event, size: 18, color: Colors.grey.shade600),
                      const SizedBox(width: 6),
                      Text(widget.event?.dateTime.toString() ?? ""),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}
