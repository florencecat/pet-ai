import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';
import 'package:table_calendar/table_calendar.dart';

import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_ai/theme/app_colors.dart';

class EventsPage extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime selectedDate;

  EventsPage({super.key, this.initialDate}) : selectedDate = DateTime.now();

  @override
  State<EventsPage> createState() => _EventsPageState();
}

class _EventsPageState extends State<EventsPage> {
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focusedDay = DateTime.now();
  late DateTime? _selectedDay;

  bool _isLoadingEvents = true;
  bool _showAllPets = false;

  List<PetEvent> _events = [];

  /// Все профили (для режима «все питомцы»)
  List<PetProfile> _allProfiles = [];

  /// Активный профиль
  PetProfile? _activeProfile;

  /// Map petId → цвет и имя (для меток на календаре и бейджей на карточках)
  Map<String, Color> _petColors = {};
  Map<String, String> _petNames = {};

  void _refresh() async {
    await _loadEvents();
  }

  void openCreateEventSheet(BuildContext context, DateTime dateTime) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet.create(dateTime: dateTime),
    );

    if (updated == true) _refresh();
  }

  void openViewEventSheet(
    BuildContext context,
    PetEvent event, {
    DateTime? completionDate,
  }) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EventSheet(event: event, completionDate: completionDate),
    );

    if (updated == true) _refresh();
  }

  Future<void> _loadEvents() async {
    setState(() => _isLoadingEvents = true);

    final allProfiles = await ProfileService().loadAllProfiles();
    final activeId = await ProfileService().getActiveProfileId();

    final petColors = <String, Color>{};
    final petNames = <String, String>{};
    PetProfile? activeProfile;

    for (final p in allProfiles) {
      petColors[p.id] = p.color;
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

  @override
  void initState() {
    super.initState();
    _loadEvents();

    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = initial;
    _selectedDay = initial;
  }

  /// Возвращает цвет точки для события в зависимости от режима отображения
  Color _markerColor(PetEvent event) {
    if (_showAllPets && event.petIds.isNotEmpty) {
      return _petColors[event.petIds.first] ?? event.category.color;
    }
    return event.category.color;
  }

  /// Возвращает имя питомца для карточки (только в режиме «все питомцы»)
  String? _petNameFor(PetEvent event) {
    if (!_showAllPets) return null;
    if (event.petIds.isEmpty) return null;
    // Если у события несколько питомцев — перечисляем через запятую
    return event.petIds
        .map((id) => _petNames[id] ?? '')
        .where((n) => n.isNotEmpty)
        .join(', ');
  }

  /// Возвращает цвет первого питомца события (для бейджа)
  Color? _petColorFor(PetEvent event) {
    if (!_showAllPets || event.petIds.isEmpty) return null;
    return _petColors[event.petIds.first];
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(gradient: pageGradientDecoration.gradient),
        child: InlineLoading(
          isLoading: _isLoadingEvents,
          child: ListView(
            clipBehavior: Clip.none,
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 100),
            children: [
              // ── Переключатель «текущий питомец / все питомцы» ───────────
              if (_allProfiles.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _PetToggleChip(
                        label: _activeProfile?.name.isNotEmpty == true
                            ? _activeProfile!.name
                            : 'Текущий',
                        selected: !_showAllPets,
                        color: _activeProfile?.color ?? ThemeColors.primary,
                        onTap: () {
                          if (_showAllPets) {
                            setState(() => _showAllPets = false);
                            _loadEvents();
                          }
                        },
                      ),
                      const SizedBox(width: 8),
                      _PetToggleChip(
                        label: 'Все питомцы',
                        selected: _showAllPets,
                        color: ThemeColors.secondary,
                        onTap: () {
                          if (!_showAllPets) {
                            setState(() => _showAllPets = true);
                            _loadEvents();
                          }
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // ── Календарь ────────────────────────────────────────────────
              GlassPlate(
                child: Padding(
                  padding: EdgeInsetsGeometry.symmetric(horizontal: 16),
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
                    eventLoader: (day) {
                      return _events.where((e) => e.occursOn(day)).toList();
                    },
                    calendarStyle: CalendarStyle(
                      todayDecoration: BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                      ),
                      selectedDecoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      todayTextStyle: TextStyle(
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                      selectedTextStyle: TextStyle(
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
                    onFormatChanged: (format) {
                      setState(() => _format = format);
                    },
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ── Кнопка «Добавить событие» ───────────────────────────────
              GlassCard(
                color: ThemeColors.primary,
                callback: _selectedDay == null
                    ? null
                    : () => openCreateEventSheet(context, _selectedDay!),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.add, color: ThemeColors.white),
                    const SizedBox(width: 6),
                    Text(
                      'Добавить событие',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        inherit: true,
                        color: ThemeColors.white,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              // ── Список событий выбранного дня ───────────────────────────
              if (_selectedDay != null && _events.isNotEmpty)
                ...(_events.where((e) => e.occursOn(_selectedDay!))).map(
                  (e) => GlassEventCard(
                    event: e,
                    selectedDate: _selectedDay,
                    petColor: _petColorFor(e),
                    petName: _petNameFor(e),
                    callback: () => openViewEventSheet(
                      context,
                      e,
                      completionDate: _selectedDay,
                    ),
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
            ],
          ),
        ),
      ),
    );
  }
}

class _PetToggleChip extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _PetToggleChip({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? color.withAlpha(200) : color.withAlpha(40),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : color.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? Colors.white : color.withAlpha(200),
          ),
        ),
      ),
    );
  }
}
