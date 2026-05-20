import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:provider/provider.dart';

class EventsPage extends StatefulWidget {
  final DateTime? initialDate;

  const EventsPage({super.key, this.initialDate});

  @override
  State<EventsPage> createState() => EventsPageState();
}

class EventsPageState extends State<EventsPage> {
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  bool _isLoadingEvents = true;
  bool _showAllPets = false;

  List<PetEvent> _events = [];
  List<PetProfile> _allProfiles = [];
  PetProfile? _activeProfile;
  Map<String, Color> _petColors = {};
  Map<String, String> _petNames = {};

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = initial;
    _selectedDay = initial;
    _loadEvents();
  }

  @override
  void didUpdateWidget(EventsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // When the parent navigates to a specific date (e.g. from HomePage),
    // jump the calendar to that date without triggering a full data reload.
    if (widget.initialDate != null &&
        widget.initialDate != oldWidget.initialDate) {
      setState(() {
        _focusedDay = widget.initialDate!;
        _selectedDay = widget.initialDate!;
      });
    }
  }

  // ── Data helpers ────────────────────────────────────────────────────────────

  /// Called by [MainPage] via GlobalKey to reload data when the tab becomes active.
  void refresh() => _loadEvents();

  void _refresh() async => await _loadEvents();

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);

    final allProfiles = await ProfileService().loadAllProfiles();
    final activeId = await ProfileService().getActiveProfileId();

    final petColors = <String, Color>{};
    final petNames = <String, String>{};
    PetProfile? activeProfile;

    for (final p in allProfiles) {
      petColors[p.id] = p.palette.mainColor;
      petNames[p.id] = p.name.isEmpty ? 'Питомец' : p.name;
      if (p.id == activeId) activeProfile = p;
    }

    List<PetEvent> events;
    if (_showAllPets) {
      final allIds = allProfiles.map((p) => p.id).toList();
      events = await EventService().loadEventsForPets(allIds);
    } else if (activeId != null) {
      events = await EventService().loadEvents(activeId);
    } else {
      events = [];
    }

    if (events.length > 1) {
      events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }

    if (!mounted) return;
    setState(() {
      _isLoadingEvents = false;
      _events = events;
      _allProfiles = allProfiles;
      _activeProfile = activeProfile;
      _petColors = petColors;
      _petNames = petNames;
    });
  }

  /// Events for the selected day.
  List<PetEvent> get _filteredDayEvents {
    if (_selectedDay == null) return [];
    return _events.where((e) => e.occursOn(_selectedDay!)).toList();
  }

  /// Whether any event occurs in [_focusedDay]'s month for the given [petId].
  /// Pass null to check across all loaded pets.
  bool _hasEventsInFocusedMonth(String? petId) {
    final year = _focusedDay.year;
    final month = _focusedDay.month;
    final daysInMonth = DateTime(year, month + 1, 0).day;
    for (var d = 1; d <= daysInMonth; d++) {
      final date = DateTime(year, month, d);
      for (final e in _events) {
        if (petId != null && !e.petIds.contains(petId)) continue;
        if (e.occursOn(date)) return true;
      }
    }
    return false;
  }

  /// Marker dot color for a calendar event.
  Color _markerColor(PetEvent event) {
    if (_showAllPets && event.petIds.isNotEmpty) {
      return _petColors[event.petIds.first] ?? event.category.color;
    }
    return event.category.color;
  }

  /// Pet name + color pairs for an event's badge row.
  /// Returns [("Все", grey)] when the event covers all known pets.
  List<(String, Color)> _petBadgesFor(PetEvent event) {
    if (event.petIds.isEmpty) return [];
    final allIds = _allProfiles.map((p) => p.id).toSet();
    final eventIds = event.petIds.toSet();
    if (allIds.length > 1 && eventIds.containsAll(allIds)) {
      return [('Все', ThemeColors.border)];
    }
    return event.petIds
        .map(
          (id) => (
            _petNames[id] ?? 'Питомец',
            _petColors[id] ?? ThemeColors.border,
          ),
        )
        .toList();
  }

  // ── Sheet helpers ───────────────────────────────────────────────────────────

  void _openSearchSheet() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _EventSearchSheet(
        events: _events,
        petNames: _petNames,
        petColors: _petColors,
        onEventTap: (event) {
          // Close search sheet first, then open event detail
          Navigator.pop(context);
          _openViewSheet(event);
        },
      ),
    );
  }

  void _openCreateSheet() async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EventSheet.create(dateTime: _selectedDay ?? DateTime.now()),
    );
    if (updated == true) _refresh();
  }

  void _openViewSheet(PetEvent event) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event, completionDate: _selectedDay),
    );
    if (updated == true) _refresh();
  }

  Future<void> _deleteEvent(PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: Text(
          '«${event.name}» будет удалено без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: ThemeColors.dangerZone,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await EventService().deleteEvent(event);
    _refresh();
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    final bottomPadding = MediaQuery.of(context).padding.bottom;
    final primaryColor = context.watch<AppearanceController>().primaryColor;
    final monthLabel = DateFormat('MMMM yyyy', 'ru_RU').format(_focusedDay);
    final filtered = _filteredDayEvents;

    return Scaffold(
      floatingActionButton: Padding(
        padding: EdgeInsetsGeometry.only(bottom: bottomPadding),
        child: FloatingActionButton(
          onPressed: _openCreateSheet,
          backgroundColor: primaryColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: const Icon(Icons.add, color: Colors.white),
        ),
      ),
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: InlineLoading(
          isLoading: _isLoadingEvents,
          child: ListView(
            clipBehavior: Clip.none,
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 120),
            children: [
              // ── Header ───────────────────────────────────────────────────
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'События',
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        Text(
                          monthLabel,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                  GlassPlate(
                    padding: 4,
                    child: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: _openSearchSheet,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // ── Pet selector ─────────────────────────────────────────────
              if (_allProfiles.length > 1) ...[
                GlassPlate(
                  padding: 8,
                  child: Row(
                    children: [
                      Expanded(
                        child: _PetSelectorChip(
                          label: _activeProfile?.name.isNotEmpty == true
                              ? _activeProfile!.name
                              : 'Текущий',
                          selected: !_showAllPets,
                          color:
                              _activeProfile?.palette.mainColor ?? primaryColor,
                          hasEvents: _hasEventsInFocusedMonth(
                            _activeProfile?.id,
                          ),
                          onTap: () {
                            if (_showAllPets) {
                              setState(() => _showAllPets = false);
                              _loadEvents();
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _PetSelectorChip(
                          label: 'Все питомцы',
                          selected: _showAllPets,
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor,
                          hasEvents: _hasEventsInFocusedMonth(null),
                          onTap: () {
                            if (!_showAllPets) {
                              setState(() => _showAllPets = true);
                              _loadEvents();
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Calendar ─────────────────────────────────────────────────
              GlassPlate(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: TableCalendar(
                    locale: 'ru_RU',
                    startingDayOfWeek: StartingDayOfWeek.monday,
                    focusedDay: _focusedDay,
                    firstDay: DateTime.utc(2024),
                    lastDay: DateTime.utc(2030),
                    calendarFormat: _format,
                    calendarBuilders: CalendarBuilders(
                      markerBuilder: (context, day, events) {
                        if (events.isEmpty) return const SizedBox();
                        return Positioned(
                          bottom: 4,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: events.take(3).map((event) {
                              final e = event as PetEvent;
                              return Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 2,
                                ),
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _markerColor(e),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        );
                      },
                    ),
                    headerStyle: HeaderStyle(
                      formatButtonVisible: false,
                      titleTextStyle: Theme.of(context).textTheme.bodyLarge!,
                    ),
                    daysOfWeekStyle: DaysOfWeekStyle(
                      weekdayStyle: Theme.of(context).textTheme.bodySmall!
                          .copyWith(inherit: true, fontSize: 13),
                      weekendStyle: Theme.of(context).textTheme.bodySmall!
                          .copyWith(inherit: true, fontSize: 13),
                    ),
                    eventLoader: (day) => _events.where((e) {
                      if (!e.occursOn(day)) return false;
                      // Pills create repeating events — shown on health page,
                      // no need for calendar dots for each occurrence.
                      if (e.source == EventSource.pill) return false;
                      // Completed events should not show as dots.
                      if (e.isCompletedOn(day)) return false;
                      return true;
                    }).toList(),
                    calendarStyle: CalendarStyle(
                      todayDecoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: const TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedTextStyle: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
                    onDaySelected: (selectedDay, focusedDay) async {
                      setState(() {
                        _selectedDay = selectedDay;
                        _focusedDay = focusedDay;
                      });
                      await _loadEvents();
                    },
                    onPageChanged: (focusedDay) {
                      setState(() => _focusedDay = focusedDay);
                    },
                    onFormatChanged: (format) {
                      setState(() => _format = format);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Day events ───────────────────────────────────────────────
              if (_selectedDay != null) ...[
                Text(
                  _dayLabel(_selectedDay!),
                  style: Theme.of(context).textTheme.titleMedium!.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                if (filtered.isEmpty)
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      SizedBox(height: 32),
                      Icon(
                        Icons.event_busy_outlined,
                        size: 72,
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor
                            .withAlpha(60),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Нет событий.',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  inherit: true,
                                  color: context
                                      .watch<AppearanceController>()
                                      .secondaryColor
                                      .withAlpha(60),
                                ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              padding: EdgeInsetsGeometry.all(5),
                            ),
                            onPressed: _openCreateSheet,
                            child: Text(
                              'Создать',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    inherit: true,
                                    color: context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(192),
                                  ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  )
                else
                  ...filtered.map(
                    (e) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _SwipeableEventTile(
                        event: e,
                        petBadges: _petBadgesFor(e),
                        selectedDate: _selectedDay,
                        onTap: () => _openViewSheet(e),
                        onEdit: () => _openViewSheet(e),
                        onDelete: () => _deleteEvent(e),
                        onCompletedChanged: (val) async {
                          final profileId = await ProfileService()
                              .getActiveProfileId();
                          if (profileId != null) {
                            await EventService().toggleCompleted(
                              profileId,
                              e,
                              _selectedDay!,
                            );
                            _refresh();
                          }
                        },
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _dayLabel(DateTime day) {
    final now = DateTime.now();
    if (isSameDay(day, now)) return 'Сегодня';
    if (isSameDay(day, now.add(const Duration(days: 1)))) return 'Завтра';
    if (isSameDay(day, now.subtract(const Duration(days: 1)))) return 'Вчера';
    return DateFormat('d MMMM', 'ru_RU').format(day);
  }
}

// ── Pet selector chip (full-width) ───────────────────────────────────────────

class _PetSelectorChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final bool hasEvents;
  final VoidCallback onTap;

  const _PetSelectorChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.hasEvents,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(200) : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: selected ? Colors.white : color.withAlpha(200),
              ),
            ),
            if (hasEvents) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? Colors.white.withAlpha(200)
                      : color.withAlpha(220),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Swipeable wrapper ────────────────────────────────────────────────────────

class _SwipeableEventTile extends StatefulWidget {
  final PetEvent event;
  final List<(String, Color)> petBadges;
  final DateTime? selectedDate;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final ValueChanged<bool>? onCompletedChanged;

  const _SwipeableEventTile({
    required this.event,
    required this.petBadges,
    this.selectedDate,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCompletedChanged,
  });

  @override
  State<_SwipeableEventTile> createState() => _SwipeableEventTileState();
}

class _SwipeableEventTileState extends State<_SwipeableEventTile>
    with SingleTickerProviderStateMixin {
  static const double _btnSize = 52.0;
  static const double _btnGap = 10.0;
  static const double _sidePad = 12.0;
  static late double _actionsCount;
  static late double _actionWidth;

  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  bool _revealed = false;

  @override
  void initState() {
    super.initState();

    _actionsCount = widget.event.completable ? 3 : 2;
    _actionWidth =
        _btnSize * _actionsCount + _sidePad * 2 + _btnGap * (_actionsCount - 1);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<double>(
      begin: 0,
      end: -_actionWidth,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.selectionClick();
    _ctrl.forward();
    _revealed = true;
  }

  void _close() {
    _ctrl.reverse();
    _revealed = false;
  }

  void _onHorizontalDrag(DragUpdateDetails d) {
    final dx = d.primaryDelta ?? 0;
    if (dx < -6 && !_revealed) _open();
    if (dx > 6 && _revealed) _close();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDrag,
      onTap: _revealed ? _close : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        children: [
          // Action buttons (behind card)
          Positioned(
            right: _sidePad,
            top: 0,
            bottom: 0,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: _btnGap,
              children: [
                if (widget.event.completable)
                  _ActionBtn(
                    icon: Icons.check,
                    color: ThemeColors.positiveDynamics,
                    label: 'Выполнено',
                    onTap: () {
                      _close();
                      widget.onCompletedChanged?.call(
                        widget.event.isCompletedOn(widget.selectedDate!),
                      );
                    },
                  ),

                _ActionBtn(
                  icon: Icons.edit_outlined,
                  color: context.watch<AppearanceController>().secondaryColor,
                  label: 'Изменить',
                  onTap: () {
                    _close();
                    widget.onEdit?.call();
                  },
                ),
                _ActionBtn(
                  icon: Icons.delete_outline,
                  color: ThemeColors.dangerZone,
                  label: 'Удалить',
                  onTap: () {
                    _close();
                    widget.onDelete?.call();
                  },
                ),
              ],
            ),
          ),

          // Card (slides left)
          AnimatedBuilder(
            animation: _slide,
            builder: (_, child) => Transform.translate(
              offset: Offset(_slide.value, 0),
              child: child,
            ),
            child: _EventTileCard(
              event: widget.event,
              petBadges: widget.petBadges,
              selectedDate: widget.selectedDate,
              onTap: _revealed ? _close : widget.onTap,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Round action button ──────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _SwipeableEventTileState._btnSize,
            height: _SwipeableEventTileState._btnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Event tile card ──────────────────────────────────────────────────────────

class _EventTileCard extends StatelessWidget {
  final PetEvent event;
  final List<(String, Color)> petBadges;
  final DateTime? selectedDate;
  final VoidCallback? onTap;

  const _EventTileCard({
    required this.event,
    required this.petBadges,
    this.selectedDate,
    this.onTap,
  });

  DateTime get _effectiveDate => selectedDate ?? event.dateTime;

  bool get _isCompleted => event.isCompletedOn(_effectiveDate);

  @override
  Widget build(BuildContext context) {
    final overdue = event.isOverdue;
    final time = DateFormat('HH:mm').format(event.dateTime);

    return GlassPlate(
      color: Colors.white,
      transparent: false,
      padding: 0,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap?.call();
        },
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (event.source != EventSource.note) ...[
                  // ── Time ─────────────────────────────────────────────────
                  Expanded(
                    flex: 1,
                    child: Text(
                      time,
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        color: overdue
                            ? ThemeColors.dangerZone
                            : event.category.color,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  // ── Vertical splitter ─────────────────────────────────────
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: ThemeColors.border.withAlpha(60),
                  ),
                ],

                // ── Icon + name + category + pet badges ───────────────────
                Expanded(
                  flex: 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SoftRoundedIcon(
                        icon: event.category.icon,
                        color: event.categoryColor,
                        size: 24,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              event.name,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    inherit: true,
                                    decoration: _isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                    decorationColor: overdue
                                        ? ThemeColors.dangerZone
                                        : context
                                              .watch<AppearanceController>()
                                              .secondaryColor,
                                    decorationThickness: 3,
                                    color: overdue
                                        ? ThemeColors.dangerZone
                                        : context
                                              .watch<AppearanceController>()
                                              .secondaryColor,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              event.categoryCaption,
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            if (petBadges.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Wrap(
                                spacing: 4,
                                runSpacing: 4,
                                children: petBadges.map((badge) {
                                  return SoftGlassBadge(
                                    color: badge.$2,
                                    icon: Icons.pets,
                                    label: badge.$1,
                                    selected: false,
                                    onChanged: null,
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
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

// ── Search sheet (all events) ────────────────────────────────────────────────

class _EventSearchSheet extends StatefulWidget {
  final List<PetEvent> events;
  final Map<String, String> petNames;
  final Map<String, Color> petColors;
  final ValueChanged<PetEvent> onEventTap;

  const _EventSearchSheet({
    required this.events,
    required this.petNames,
    required this.petColors,
    required this.onEventTap,
  });

  @override
  State<_EventSearchSheet> createState() => _EventSearchSheetState();
}

class _EventSearchSheetState extends State<_EventSearchSheet> {
  final _ctrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<PetEvent> get _results {
    if (_query.isEmpty) return widget.events;
    final q = _query.toLowerCase();
    return widget.events
        .where(
          (e) =>
              e.name.toLowerCase().contains(q) ||
              e.category.name.toLowerCase().contains(q),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final results = _results;

    return DraggableSheet(
      title: 'Поиск событий',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.9,
      minSize: 0.5,
      maxSize: 1.0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Search field
          GlassPlate(
            padding: 0,
            child: TextField(
              controller: _ctrl,
              autofocus: true,
              onChanged: (q) => setState(() => _query = q),
              decoration: InputDecoration(
                hintText: 'Название события или категория...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () {
                          _ctrl.clear();
                          setState(() => _query = '');
                        },
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Result count
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Text(
              _query.isEmpty
                  ? 'Все события (${results.length})'
                  : 'Найдено: ${results.length}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: ac.secondaryColor.withAlpha(160),
                  ),
            ),
          ),

          // Results list
          if (results.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Column(
                children: [
                  Icon(
                    Icons.search_off,
                    size: 56,
                    color: ac.primaryColor.withAlpha(60),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Ничего не найдено',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: ac.secondaryColor.withAlpha(120),
                        ),
                  ),
                ],
              ),
            )
          else
            ...results.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _SearchResultTile(
                  event: e,
                  petNames: widget.petNames,
                  petColors: widget.petColors,
                  onTap: () => widget.onEventTap(e),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _SearchResultTile extends StatelessWidget {
  final PetEvent event;
  final Map<String, String> petNames;
  final Map<String, Color> petColors;
  final VoidCallback onTap;

  const _SearchResultTile({
    required this.event,
    required this.petNames,
    required this.petColors,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final dateLabel = formatSmartDate(event.dateTime, pattern: 'd MMMM yyyy');
    final timeLabel = DateFormat('HH:mm').format(event.dateTime);
    final overdue = event.isOverdue;

    return GlassPlate(
      padding: 0,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              SoftRoundedIcon(
                icon: event.category.icon,
                color: event.categoryColor,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      event.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: overdue
                                ? ThemeColors.dangerZone
                                : ac.secondaryColor,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dateLabel · $timeLabel',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                size: 18,
                color: ac.primaryColor.withAlpha(120),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
