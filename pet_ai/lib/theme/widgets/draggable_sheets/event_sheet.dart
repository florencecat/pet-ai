import 'package:flutter/material.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

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

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
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
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _selectTime(BuildContext context) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime ?? TimeOfDay.now(),
    );
    if (picked != null) setState(() => _selectedTime = picked);
  }

  Future<void> _deleteEvent(BuildContext context, PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: const Text('Событие будет удалено без возможности восстановления.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.dangerZone),
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
    final petId = event.petIds.isNotEmpty ? event.petIds.first : '';
    final date = widget.completionDate ?? event.dateTime;
    await EventService().toggleCompleted(petId, event, date);
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

    final name = _nameController.text;
    final category = _selectedCategory!;
    final dateTime = DateTime(
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
      final event = widget.event!;
      event.assign(name, category, dateTime, repeat, customDays, _remindBeforeMinutes, petIds);
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
    final isLinkedEvent = widget.event?.source == EventSource.pill ||
        widget.event?.source == EventSource.treatment;

    return DraggableSheet(
      centerTitle: true,
      title: _mode.label,
      onBack: () => Navigator.of(context).pop(false),
      initialSize: _mode.isView ? 0.65 : 0.85,
      minSize: 0.4,
      maxSize: 0.95,
      actions: _buildActions(isLinkedEvent),
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

  List<Widget> _buildActions(bool isLinkedEvent) {
    if (EventSheetModeX(_mode).isView) {
      if (isLinkedEvent) {
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
            if (widget.event != null) widget.event!.starred = !widget.event!.starred;
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
                color: isCompleted
                    ? ThemeColors.border
                    : null,
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
              label: formatSmartDateTime(event.dateTime),
            ),
            if (event.repeat != RepeatInterval.none) ...[
              const _RowDivider(),
              _InfoRow(
                icon: Icons.repeat,
                iconColor: accent,
                label: _getRepeatText(event.repeat),
                sublabel: event.repeat == RepeatInterval.custom &&
                        event.customDays.isNotEmpty
                    ? event.customDays
                        .map((d) => WeekDays.labels[d] ?? '')
                        .join(', ')
                    : null,
              ),
            ],
            if (event.remindBeforeMinutes > 0) ...[
              const _RowDivider(),
              _InfoRow(
                icon: Icons.notifications_outlined,
                iconColor: accent,
                label: 'Напоминание за ${event.remindBeforeMinutes} мин',
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
      ]
    ];
  }

  // ─── Edit/Create Mode ──────────────────────────────────────────────────────

  List<Widget> _buildEditableContent() {
    return [
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
          const SizedBox(width: 8),
          Expanded(
            child: GlassCard(
              callback: () => _selectTime(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.access_time,
                      size: 18,
                      color: _selectedTime == null
                          ? ThemeColors.dangerZone
                          : context.watch<AppearanceController>().primaryColor,
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

      GlassPlate(
        child: SwitchListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 12),
          title: Text('Повторять', style: Theme.of(context).textTheme.bodyLarge),
          subtitle: Text('Сделать событие регулярным',
              style: Theme.of(context).textTheme.bodySmall),
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
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, animation) =>
            SizeTransition(sizeFactor: animation, child: child),
        child: _isRepeating ? _buildRepeatOptions() : const SizedBox.shrink(),
      ),

      const SizedBox(height: 8),

      GlassPlate(
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
              Expanded(
                child: Text('Напомнить за (мин):',
                    style: Theme.of(context).textTheme.bodyLarge),
              ),
              IconButton(
                icon: const Icon(Icons.remove_circle_outline),
                color: context.watch<AppearanceController>().primaryColor,
                onPressed: _remindBeforeMinutes > 0
                    ? () => setState(() => _remindBeforeMinutes -= 5)
                    : null,
              ),
              SizedBox(
                width: 40,
                child: Text(
                  '$_remindBeforeMinutes',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge!
                      .copyWith(fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: context.watch<AppearanceController>().primaryColor,
                onPressed: _remindBeforeMinutes < 120
                    ? () => setState(() => _remindBeforeMinutes += 5)
                    : null,
              ),
            ],
          ),
        ),
      ),

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
        GlassPlate(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Интервал повторения',
                    style: Theme.of(context).textTheme.bodySmall),
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
                      selectedColor:
                          context.watch<AppearanceController>().primaryColor,
                      labelStyle: TextStyle(
                        color: selected ? Colors.white : ThemeColors.textPrimary,
                      ),
                      onSelected: (_) =>
                          setState(() => _selectedRepeat = interval),
                    );
                  }).toList(),
                ),
              ],
            ),
          ),
        ),
        if (_selectedRepeat == RepeatInterval.custom) ...[
          const SizedBox(height: 8),
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Дни недели',
                      style: Theme.of(context).textTheme.bodySmall),
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
      EventSource.pill => ('Препарат', Icons.medication_outlined, const Color(0xFF5C6BC0)),
      EventSource.treatment => ('Прививка / обработка', Icons.vaccines_outlined, const Color(0xFF00897B)),
      EventSource.note => ('Из заметки', Icons.note_outlined, ThemeColors.border),
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
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: ThemeColors.border,
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

class _PetsInfoRow extends StatelessWidget {
  final List<String> petIds;
  final List<PetProfile> profiles;
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
  Widget build(BuildContext context) =>
      Divider(height: 1, indent: 46, endIndent: 0, color: ThemeColors.border.withAlpha(60));
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
                    isCompleted ? Icons.check_circle_rounded : Icons.circle_outlined,
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
