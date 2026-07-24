import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:provider/provider.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/onboarding_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/coach_marks.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pinnable_header_view.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/calendar_filter_sheet.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/calendar_filter.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class EventsPage extends StatefulWidget {
  final DateTime? initialDate;

  const EventsPage({super.key, this.initialDate});

  @override
  State<EventsPage> createState() => EventsPageState();
}

class EventsPageState extends State<EventsPage> {
  /// Форматы календаря от большего к меньшему — по этому порядку идут оба
  /// жеста смены формата: вертикальный свайп внутри TableCalendar и ручка под
  /// ним. Задан явно, чтобы ручка не разъехалась с умолчанием пакета.
  static const _formats = {
    CalendarFormat.month: 'Месяц',
    CalendarFormat.twoWeeks: '2 недели',
    CalendarFormat.week: 'Неделя',
  };

  /// Порог жеста ручки. Совпадает с порогом свайпа по самому календарю
  /// ([TableCalendar.simpleSwipeConfig]), чтобы жест ощущался одинаково.
  static const _handleSwipeThreshold = 25.0;

  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focusedDay;
  DateTime? _selectedDay;

  /// Начало вертикального жеста по ручке; null — шаг за этот жест уже сделан.
  double? _handleDragStart;

  bool _isLoadingEvents = true;
  bool _showAllPets = false;

  /// Растёт при каждой смене питомца — сигнал списку событий проиграть
  /// исчезновение старых карточек и появление новых.
  int _petSwitchToken = 0;

  List<Event> _events = [];
  List<Pet> _allProfiles = [];
  Pet? _activeProfile;
  Map<String, Color> _petColors = {};
  Map<String, String> _petNames = {};

  /// Что показывать в календаре (типы событий, прошедшие/выполненные/повторы).
  CalendarFilter _calendarFilter = const CalendarFilter.defaults();

  // Виджеты, которые подсвечивает обучение (см. [maybeShowOnboarding]).
  final _actionsKey = GlobalKey();
  final _calendarKey = GlobalKey();
  final _dayTitleKey = GlobalKey();

  /// Текущая загрузка экрана — обучение ждёт её, иначе на календаре ещё нет
  /// отметок событий, про которые оно рассказывает.
  Future<void>? _loaded;

  /// Обучение уже на экране — второй раз поверх него не открываем.
  bool _onboardingRunning = false;

  @override
  void initState() {
    super.initState();
    final initial = widget.initialDate ?? DateTime.now();
    _focusedDay = initial;
    _selectedDay = initial;
    _loaded = _loadEvents();
    _loadCalendarFilter();
  }

  Future<void> _loadCalendarFilter() async {
    final filter = await CalendarFilter.load();
    if (!mounted) return;
    setState(() => _calendarFilter = filter);
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
  void refresh() => _loaded = _loadEvents();

  /// Показывает обучение по календарю — один раз на установку.
  ///
  /// Вызывается [MainPage] при переходе на вкладку: страница живёт в
  /// IndexedStack и создаётся вместе с главной, поэтому сама момент «пользователь
  /// сюда пришёл» не отличает. Внутренние вызовы [refresh] (выбор дня, листание
  /// месяцев) обучение не трогают.
  Future<void> maybeShowOnboarding() async {
    if (_onboardingRunning) return;

    final onboarding = OnboardingService();
    if (await onboarding.isShown(OnboardingTour.events)) return;

    // Дожидаемся событий: без них на календаре нет отметок, про которые
    // рассказывает второй шаг.
    await _loaded;
    if (!mounted) return;

    _onboardingRunning = true;
    // Помечаем показанным до открытия, а не после: иначе повторный триггер
    // (пока пользователь не прошёл шаги) поднимет второй такой же слой.
    await onboarding.markShown(OnboardingTour.events);
    if (!mounted) {
      _onboardingRunning = false;
      return;
    }

    await showCoachMarks(
      context,
      steps: [
        CoachMarkStep(
          targetKey: _actionsKey,
          icon: Icons.tune,
          iconColor: ThemeColors.vetCardIconColor,
          title: 'Фильтр, поиск и создание',
          description:
              'Слева — фильтр: какие типы событий показывать на календаре и '
              'нужны ли прошедшие, выполненные и повторы. В центре — поиск по '
              'всем событиям питомца. Справа — создание нового события.',
        ),
        CoachMarkStep(
          targetKey: _calendarKey,
          icon: Icons.calendar_month_outlined,
          iconColor: ThemeColors.notesIconColor,
          title: 'Календарь',
          description:
              'Точки под датой — события этого дня, цвет совпадает с типом '
              'события; если их больше трёх, рядом появится «+N». Календарь '
              'меняет размер: потяните за ручку под ним или свайпните по нему '
              'вверх-вниз — месяц, две недели или одна.',
        ),
        CoachMarkStep(
          targetKey: _dayTitleKey,
          icon: Icons.event_note_outlined,
          iconColor: ThemeColors.filesIconColor,
          title: 'События выбранного дня',
          description:
              'Под этим заголовком — события того дня, который выбран в '
              'календаре. Нажмите другую дату, и список сразу обновится.',
          radius: 12,
          inflate: 8,
        ),
      ],
    );

    _onboardingRunning = false;
  }

  void _refresh() async => await _loadEvents();

  /// [petSwitch] — перезагрузка вызвана сменой питомца: не показываем общий
  /// индикатор загрузки (чтобы был виден переход списка) и по завершении
  /// дёргаем [_petSwitchToken].
  Future<void> _loadEvents({bool petSwitch = false}) async {
    if (!petSwitch) setState(() => _isLoadingEvents = true);

    final allProfiles = await PetProfileService().loadAllProfiles();
    final activeId = await PetProfileService().getActiveProfileId();

    final petColors = <String, Color>{};
    final petNames = <String, String>{};
    Pet? activeProfile;

    for (final p in allProfiles) {
      petColors[p.id] = p.palette.darkShade;
      petNames[p.id] = p.name.isEmpty ? 'Питомец' : p.name;
      if (p.id == activeId) activeProfile = p;
    }

    List<Event> events;
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
      if (petSwitch) _petSwitchToken++;
    });
  }

  /// Меняет формат календаря на шаг: [collapse] — к более компактному виду.
  /// Ровно то же, что делает вертикальный свайп внутри календаря.
  void _stepFormat({required bool collapse}) {
    final formats = _formats.keys.toList();
    final next = formats.indexOf(_format) + (collapse ? 1 : -1);
    if (next < 0 || next >= formats.length) return;
    setState(() => _format = formats[next]);
  }

  /// Events for the selected day. Список дня показывает ВСЕ события выбранного
  /// дня — фильтр отображения касается только меток в самом календаре, иначе
  /// скрытые события стало бы невозможно увидеть.
  List<Event> get _filteredDayEvents {
    if (_selectedDay == null) return [];
    return _events.where((e) => e.occursOn(_selectedDay!)).toList();
  }

  /// Проходит ли вхождение события на [day] фильтр меток календаря.
  bool _passesCalendarFilter(Event e, DateTime day) {
    final f = _calendarFilter;
    if (!f.showPills && e.fromPill) return false;
    if (!f.showTreatments && e.fromTreatment) return false;
    if (!f.showNotes && e.fromNote) return false;
    if (!f.showRepeating && e.repeat != RepeatInterval.none) return false;
    if (!f.showCompleted && e.isCompletedOn(day)) return false;
    if (!f.showPast && _isPastDay(day)) return false;
    return true;
  }

  /// [day] раньше сегодняшнего (по календарной дате).
  bool _isPastDay(DateTime day) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(day.year, day.month, day.day).isBefore(today);
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

  /// Pet name + color pairs for an event's badge row.
  /// Returns [("Все", grey)] when the event covers all known pets.
  List<(String, Color)> _petBadgesFor(Event event) {
    if (event.petIds.isEmpty) return [];
    final allIds = _allProfiles.map((p) => p.id).toSet();
    final eventIds = event.petIds.toSet();
    if (allIds.length > 1 && eventIds.containsAll(allIds)) {
      return [('Все', context.watch<AppearanceController>().secondaryColor)];
    }
    return event.petIds
        .map(
          (id) => (
            _petNames[id] ?? 'Питомец',
            _petColors[id] ??
                context.watch<AppearanceController>().secondaryColor,
          ),
        )
        .toList();
  }

  // ── Sheet helpers ───────────────────────────────────────────────────────────

  void _openCalendarFilter() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => CalendarFilterSheet(
        filter: _calendarFilter,
        onChanged: (f) => setState(() => _calendarFilter = f),
      ),
    );
  }

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
    final created = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) =>
          EventSheet.create(dateTime: _selectedDay ?? DateTime.now()),
    );
    if (created != null) {
      _selectedDay = created;
      _refresh();
    }
  }

  void _openViewSheet(Event event) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event, completionDate: _selectedDay),
    );
    _refresh();
  }

  void _openEditSheet(Event event) async {
    final edited = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet.edit(event: event),
    );
    if (edited != null && edited) {
      _refresh();
    }
  }

  /// Подтверждает и удаляет событие из хранилища, но НЕ перезагружает список —
  /// список обновляет плитка после своей анимации исчезновения. Возвращает
  /// `true`, если удаление подтверждено и выполнено.
  Future<bool> _deleteEvent(Event event) async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить «${event.name}»?',
      message: event.origin.deleteWarning,
    );
    if (!confirmed) return false;
    await EventService().deleteEvent(event);
    return true;
  }

  /// Заглушка «нет событий» с кнопкой создания.
  Widget _buildEmptyState(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.event_busy_outlined,
          size: 72,
          color: ac.secondaryColor.withAlpha(60),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Нет событий.',
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                inherit: true,
                color: ac.secondaryColor.withAlpha(60),
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(padding: EdgeInsetsGeometry.all(5)),
              onPressed: _openCreateSheet,
              child: Text(
                'Создать',
                style: Theme.of(context).textTheme.titleLarge!.copyWith(
                  inherit: true,
                  color: ac.primaryColor.withAlpha(192),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  // ── Build ───────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final primaryColor = context.watch<AppearanceController>().primaryColor;
    final monthLabel = DateFormat('MMMM yyyy', 'ru_RU').format(_focusedDay);
    final filtered = _filteredDayEvents;

    return Scaffold(
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: InlineLoading(
          isLoading: _isLoadingEvents,
          child: PinnableHeaderView(
            bottomPadding: 120,
            header: Row(
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
                      Text(monthLabel, style: context.subtitleMediumStyle),
                    ],
                  ),
                ),
                GlassPlate(
                  key: _actionsKey,
                  padding: 4,
                  child: Row(
                    spacing: 8,
                    children: [
                      IconButton(
                        icon: Icon(Icons.list, color: context.titleColor),
                        onPressed: _openCalendarFilter,
                      ),
                      IconButton(
                        icon: Icon(Icons.search, color: context.titleColor),
                        onPressed: _openSearchSheet,
                      ),
                      IconButton(
                        icon: Icon(Icons.add, color: context.titleColor),
                        onPressed: _openCreateSheet,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            children: [
              // ── Pet selector ─────────────────────────────────────────────
              // Сегментированный переключатель: выбранная «пилюля» плавно
              // переезжает между питомцами, растягиваясь по ходу движения.
              if (_allProfiles.length > 1) ...[
                GlassPlate(
                  padding: 8,
                  child: _PetSegmentedSwitch(
                    selectedIndex: _showAllPets ? 1 : 0,
                    segments: [
                      _PetSegment(
                        label: _activeProfile?.name.isNotEmpty == true
                            ? _activeProfile!.name
                            : 'Текущий',
                        color:
                            _activeProfile?.palette.mainColor ?? primaryColor,
                        hasEvents: _hasEventsInFocusedMonth(_activeProfile?.id),
                      ),
                      _PetSegment(
                        label: 'Все питомцы',
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor,
                        hasEvents: _hasEventsInFocusedMonth(null),
                      ),
                    ],
                    onChanged: (index) {
                      final all = index == 1;
                      if (all != _showAllPets) {
                        setState(() => _showAllPets = all);
                        _loadEvents(petSwitch: true);
                      }
                    },
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // ── Calendar ─────────────────────────────────────────────────
              GlassPlate(
                key: _calendarKey,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    children: [
                      TableCalendar(
                        locale: 'ru_RU',
                        startingDayOfWeek: StartingDayOfWeek.monday,
                        focusedDay: _focusedDay,
                        firstDay: DateTime.utc(2024),
                        lastDay: DateTime.utc(2030),
                        calendarFormat: _format,
                        availableCalendarFormats: _formats,
                        calendarBuilders: CalendarBuilders(
                          markerBuilder: (context, day, events) {
                            if (events.isEmpty) return const SizedBox();
                            final hiddenCount = events.length - 3;
                            return Positioned(
                              bottom: 4,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ...events.take(hiddenCount > 0 ? 2 : 3).map((
                                    event,
                                  ) {
                                    final e = event as Event;
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          // Тот же цвет, что у карточки события.
                                          color:
                                              e.style.color ?? e.category.color,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                    );
                                  }),
                                  if (hiddenCount > 0)
                                    Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 2,
                                      ),
                                      child: Text(
                                        '+${hiddenCount + 1}',
                                        style: Theme.of(context)
                                            .textTheme
                                            .bodySmall!
                                            .copyWith(
                                              fontSize: 11,
                                              height: 0.1,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            );
                          },
                        ),
                        headerStyle: HeaderStyle(
                          formatButtonVisible: false,
                          titleTextStyle: Theme.of(
                            context,
                          ).textTheme.bodyLarge!,
                        ),
                        daysOfWeekStyle: DaysOfWeekStyle(
                          weekdayStyle: Theme.of(context).textTheme.bodySmall!,
                        ),
                        eventLoader: (day) => _events
                            .where(
                              (e) =>
                                  e.occursOn(day) &&
                                  _passesCalendarFilter(e, day),
                            )
                            .toList(),
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
                        selectedDayPredicate: (day) =>
                            isSameDay(day, _selectedDay),
                        onDaySelected: (selectedDay, focusedDay) async {
                          setState(() {
                            _selectedDay = selectedDay;
                            _focusedDay = focusedDay;
                          });
                          refresh();
                        },
                        onPageChanged: (focusedDay) {
                          setState(() => _focusedDay = focusedDay);
                          refresh();
                        },
                        onFormatChanged: (format) {
                          setState(() => _format = format);
                        },
                      ),
                      // Ручка тянет формат календаря: вверх — схлопнуть,
                      // вниз — развернуть. Шаг делается один раз за жест, как
                      // только палец прошёл порог, — а не по его окончании,
                      // чтобы календарь отзывался сразу.
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onVerticalDragStart: (details) =>
                            _handleDragStart = details.localPosition.dy,
                        onVerticalDragUpdate: (details) {
                          final start = _handleDragStart;
                          if (start == null) return;
                          final shift = details.localPosition.dy - start;
                          if (shift.abs() < _handleSwipeThreshold) return;
                          _handleDragStart = null;
                          _stepFormat(collapse: shift < 0);
                        },
                        child: const DragHandle(),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // ── Day events ───────────────────────────────────────────────
              if (_selectedDay != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      key: _dayTitleKey,
                      formatSmartDate(
                        _selectedDay!,
                        pattern: 'dd MMMM',
                        locale: 'ru-RU',
                      ),
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    _DayEvents(
                      events: filtered,
                      // Смена питомца → исчезновение старых, затем появление
                      // новых. Смена дня → только появление.
                      switchToken: _petSwitchToken,
                      enterToken: _selectedDay!,
                      emptyBuilder: _buildEmptyState,
                      itemBuilder: (event) => _SwipeableEventTile(
                        event: event,
                        petBadges: _petBadgesFor(event),
                        selectedDate: _selectedDay,
                        onTap: () => _openViewSheet(event),
                        onEdit: () => _openEditSheet(event),
                        onDelete: () => _deleteEvent(event),
                        onCompleteToggle: (wasCompleted) async {
                          final profileId = await PetProfileService()
                              .getActiveProfileId();
                          if (profileId != null) {
                            await EventService().toggleCompleted(
                              profileId,
                              event,
                              _selectedDay!,
                            );
                          }
                        },
                        onChanged: _refresh,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Сегментированный переключатель питомцев ──────────────────────────────────

/// Один сегмент переключателя: подпись, цвет выделения и метка «есть события».
class _PetSegment {
  final String label;
  final Color color;
  final bool hasEvents;

  const _PetSegment({
    required this.label,
    required this.color,
    required this.hasEvents,
  });
}

/// Горизонтальный сегментированный контрол. Выделенная «пилюля» плавно
/// переезжает к выбранному сегменту, причём ведущий её край опережает
/// ведомый — за счёт этого пилюля в движении заметно растягивается, а к концу
/// снова стягивается до ширины сегмента. Цвет пилюли перетекает от старого
/// сегмента к новому.
class _PetSegmentedSwitch extends StatefulWidget {
  final int selectedIndex;
  final List<_PetSegment> segments;
  final ValueChanged<int> onChanged;

  const _PetSegmentedSwitch({
    required this.selectedIndex,
    required this.segments,
    required this.onChanged,
  });

  @override
  State<_PetSegmentedSwitch> createState() => _PetSegmentedSwitchState();
}

class _PetSegmentedSwitchState extends State<_PetSegmentedSwitch>
    with SingleTickerProviderStateMixin {
  static const double _height = 42;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
    value: 1,
  );

  late int _from = widget.selectedIndex;
  late int _to = widget.selectedIndex;

  @override
  void didUpdateWidget(covariant _PetSegmentedSwitch old) {
    super.didUpdateWidget(old);
    if (widget.selectedIndex != _to) {
      _from = _to;
      _to = widget.selectedIndex;
      _ctrl.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  static double _lerp(double a, double b, double t) => a + (b - a) * t;

  @override
  Widget build(BuildContext context) {
    final count = widget.segments.length;

    return SizedBox(
      height: _height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final segW = constraints.maxWidth / count;

          return AnimatedBuilder(
            animation: _ctrl,
            builder: (context, _) {
              final t = _ctrl.value.clamp(0.0, 1.0);
              final movingRight = _to > _from;

              // Ведущий край движется быстрее ведомого — пилюля растягивается.
              final leadT = Curves.easeOut.transform(t);
              final trailT = Curves.easeInOut.transform(t);

              final fromLeft = _from * segW;
              final toLeft = _to * segW;
              final fromRight = fromLeft + segW;
              final toRight = toLeft + segW;

              final double left, right;
              if (movingRight) {
                right = _lerp(fromRight, toRight, leadT);
                left = _lerp(fromLeft, toLeft, trailT);
              } else {
                left = _lerp(fromLeft, toLeft, leadT);
                right = _lerp(fromRight, toRight, trailT);
              }

              final pillColor = Color.lerp(
                widget.segments[_from].color,
                widget.segments[_to].color,
                t,
              )!;

              return Stack(
                children: [
                  // Выделенная пилюля.
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: left,
                    width: (right - left).clamp(0.0, constraints.maxWidth),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: pillColor.withAlpha(210),
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ),

                  // Подписи сегментов поверх пилюли.
                  Row(
                    children: [
                      for (var i = 0; i < count; i++)
                        Expanded(child: _buildLabel(i, t)),
                    ],
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildLabel(int index, double t) {
    final seg = widget.segments[index];
    // Насколько сегмент сейчас «под пилюлей»: 0 — цвет питомца, 1 — белый.
    final double sel;
    if (index == _to) {
      sel = t;
    } else if (index == _from) {
      sel = 1 - t;
    } else {
      sel = 0;
    }

    final textColor = Color.lerp(seg.color.withAlpha(200), Colors.white, sel)!;
    final dotColor = Color.lerp(
      seg.color.withAlpha(220),
      Colors.white.withAlpha(220),
      sel,
    )!;

    return Pressable(
      onTap: () => widget.onChanged(index),
      haptic: HapticStrength.selection,
      scale: 0.94,
      child: SizedBox.expand(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Flexible(
              child: Text(
                seg.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontWeight: FontWeight.w600, color: textColor),
              ),
            ),
            if (seg.hasEvents) ...[
              const SizedBox(width: 6),
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: dotColor,
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

/// Тип спецэффекта, который сейчас проигрывает плитка.
enum _TileFx { none, completing, deleting }

class _SwipeableEventTile extends StatefulWidget {
  final Event event;
  final List<(String, Color)> petBadges;
  final DateTime? selectedDate;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;

  /// Подтверждает и удаляет событие из хранилища. Возвращает `true`, если
  /// удаление подтверждено — тогда плитка проигрывает анимацию исчезновения.
  final Future<bool> Function()? onDelete;

  /// Переключает статус выполнения в хранилище (без перезагрузки списка).
  /// [wasCompleted] — состояние до нажатия (true → снимаем отметку).
  final Future<void> Function(bool wasCompleted)? onCompleteToggle;

  /// Просит родителя перезагрузить список — после того как плитка отыграла
  /// свою анимацию.
  final VoidCallback? onChanged;

  const _SwipeableEventTile({
    required this.event,
    required this.petBadges,
    this.selectedDate,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.onCompleteToggle,
    this.onChanged,
  });

  @override
  State<_SwipeableEventTile> createState() => _SwipeableEventTileState();
}

class _SwipeableEventTileState extends State<_SwipeableEventTile>
    with TickerProviderStateMixin {
  static const double _btnWidth = 66.0;
  static const double _btnGap = 8.0;
  static const double _sidePad = 12.0;

  late final double _actionsCount;
  late final double _actionWidth;
  late final AnimationController _ctrl;
  late final Animation<double> _slide;
  bool _revealed = false;

  // Спецэффект строки: отметка «выполнено» / удаление.
  late final AnimationController _fxCtrl;
  _TileFx _fx = _TileFx.none;

  @override
  void initState() {
    super.initState();

    _actionsCount = widget.event.completable ? 3 : 2;
    _actionWidth =
        _btnWidth * _actionsCount +
        _sidePad * 2 +
        _btnGap * (_actionsCount - 1);

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<double>(
      begin: 0,
      end: -_actionWidth,
    ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

    _fxCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 620),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _fxCtrl.dispose();
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

  /// Проигрывает fx-анимацию до конца. Возвращает `false`, если виджет
  /// размонтирован во время анимации (тикер отменён) — тогда продолжать нельзя.
  Future<bool> _playFx() async {
    try {
      await _fxCtrl.forward(from: 0);
    } catch (_) {
      return false;
    }
    return mounted;
  }

  Future<void> _handleComplete() async {
    final was = widget.event.isCompletedOn(widget.selectedDate!);
    _close();
    await widget.onCompleteToggle?.call(was);
    if (!mounted) return;
    // Празднуем только отметку «выполнено», а не её снятие.
    if (!was) {
      triggerHaptic(HapticStrength.medium);
      setState(() => _fx = _TileFx.completing);
      if (!await _playFx()) return;
      setState(() => _fx = _TileFx.none);
    }
    widget.onChanged?.call();
  }

  Future<void> _handleDelete() async {
    _close();
    final ok = await widget.onDelete?.call() ?? false;
    if (!ok || !mounted) return;
    triggerHaptic(HapticStrength.heavy);
    setState(() => _fx = _TileFx.deleting);
    if (!await _playFx()) return;
    widget.onChanged?.call();
  }

  @override
  Widget build(BuildContext context) {
    final tile = GestureDetector(
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
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: _btnGap,
              children: [
                if (widget.event.completable)
                  _ActionBtn(
                    icon: Icons.check,
                    color: ThemeColors.positiveDynamics,
                    label: 'Выполнить',
                    onTap: _handleComplete,
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
                  onTap: _handleDelete,
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

          // Праздничный «штамп» при отметке выполненным.
          if (_fx == _TileFx.completing)
            Positioned.fill(child: _CompleteBurst(animation: _fxCtrl)),
        ],
      ),
    );

    // При удалении строка сначала плавно гаснет на месте, затем мягко
    // «сворачивает» свою высоту — без сдвига вбок.
    return AnimatedBuilder(
      animation: _fxCtrl,
      builder: (context, child) {
        if (_fx != _TileFx.deleting) return child!;
        final t = _fxCtrl.value.clamp(0.0, 1.0);
        final fade = Curves.easeOut.transform((t / 0.6).clamp(0.0, 1.0));
        final collapse = Curves.easeInOut.transform(
          ((t - 0.45) / 0.55).clamp(0.0, 1.0),
        );
        return Opacity(
          opacity: (1 - fade).clamp(0.0, 1.0),
          child: ClipRect(
            child: Align(
              alignment: Alignment.topCenter,
              heightFactor: (1 - collapse).clamp(0.0, 1.0),
              child: child,
            ),
          ),
        );
      },
      child: tile,
    );
  }
}

// ── Праздничный «штамп» отметки выполненным ─────────────────────────────────

/// Зелёный кружок с галочкой, который упруго «впечатывается» поверх карточки
/// и мягко гаснет. Проигрывается один раз по [animation] (0 → 1).
class _CompleteBurst extends StatelessWidget {
  final Animation<double> animation;

  const _CompleteBurst({required this.animation});

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          final pop = Curves.elasticOut.transform(t.clamp(0.0, 1.0));
          // Быстро появляемся, держимся, затем плавно гаснем к концу.
          final appear = Curves.easeOut.transform((t / 0.25).clamp(0.0, 1.0));
          final fadeOut =
              1 - Curves.easeIn.transform(((t - 0.65) / 0.35).clamp(0.0, 1.0));
          final opacity = (appear * fadeOut).clamp(0.0, 1.0);
          return Opacity(
            opacity: opacity,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: ThemeColors.positiveDynamics.withAlpha(36),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Transform.scale(
                scale: 0.4 + 0.6 * pop,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: const BoxDecoration(
                    color: ThemeColors.positiveDynamics,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ── Список событий дня с каскадным появлением/исчезновением ───────────────────

enum _Phase { entering, exiting }

/// Показывает события выбранного дня с каскадной анимацией: карточки по одной
/// «выезжают» снизу при появлении и уходят вниз при исчезновении.
///
/// - Смена [switchToken] (сменили питомца) → сперва проигрывается исчезновение
///   текущих карточек (реверс появления, снизу вверх), затем появление новых.
/// - Смена [enterToken] (сменили день) → только появление.
/// - Тихие обновления (удаление/отметка «выполнено») меняют список без общей
///   анимации — свою анимацию отыгрывает сама карточка.
class _DayEvents extends StatefulWidget {
  final List<Event> events;
  final Object switchToken;
  final Object enterToken;
  final Widget Function(Event event) itemBuilder;
  final WidgetBuilder emptyBuilder;

  const _DayEvents({
    required this.events,
    required this.switchToken,
    required this.enterToken,
    required this.itemBuilder,
    required this.emptyBuilder,
  });

  @override
  State<_DayEvents> createState() => _DayEventsState();
}

class _DayEventsState extends State<_DayEvents>
    with SingleTickerProviderStateMixin {
  /// Доля таймлайна, которую занимает анимация одной карточки; оставшаяся часть
  /// раздаётся как задержки старта, чтобы карточки шли одна за другой.
  static const double _itemFrac = 0.62;
  static const double _shift = 24;

  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 350),
  );

  late List<Event> _shown = widget.events;
  _Phase _phase = _Phase.entering;

  @override
  void initState() {
    super.initState();
    _ctrl.addStatusListener((status) {
      // Как только доиграло исчезновение — показываем новые с появлением.
      if (status == AnimationStatus.completed && _phase == _Phase.exiting) {
        _enterNew();
      }
    });
    _ctrl.forward();
  }

  @override
  void didUpdateWidget(covariant _DayEvents old) {
    super.didUpdateWidget(old);
    if (widget.switchToken != old.switchToken) {
      if (_shown.isNotEmpty) {
        setState(() => _phase = _Phase.exiting);
        _ctrl.forward(from: 0);
      } else {
        _enterNew();
      }
    } else if (widget.enterToken != old.enterToken) {
      _enterNew();
    } else if (!listEquals(_shown, widget.events)) {
      // Первое наполнение пустого списка тоже показываем с появлением.
      if (_shown.isEmpty && widget.events.isNotEmpty) {
        _enterNew();
      } else {
        setState(() => _shown = widget.events);
      }
    }
  }

  void _enterNew() {
    if (!mounted) return;
    setState(() {
      _shown = widget.events;
      _phase = _Phase.entering;
    });
    _ctrl.forward(from: 0);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _startFor(int idx, int n) =>
      n <= 1 ? 0 : (1 - _itemFrac) * (idx / (n - 1));

  @override
  Widget build(BuildContext context) {
    if (_shown.isEmpty) {
      return FadeTransition(
        opacity: CurvedAnimation(parent: _ctrl, curve: Curves.easeOut),
        child: widget.emptyBuilder(context),
      );
    }

    final n = _shown.length;
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final exiting = _phase == _Phase.exiting;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < n; i++) _item(i, n, _ctrl.value, exiting),
          ],
        );
      },
    );
  }

  Widget _item(int i, int n, double t, bool exiting) {
    // При исчезновении карточки уходят в обратном порядке — снизу вверх.
    final order = exiting ? (n - 1 - i) : i;
    final local = ((t - _startFor(order, n)) / _itemFrac).clamp(0.0, 1.0);
    final eased = Curves.easeOut.transform(local);

    final double opacity, dy;
    if (exiting) {
      opacity = 1 - eased;
      dy = _shift * eased;
    } else {
      opacity = eased;
      dy = _shift * (1 - eased);
    }

    return Opacity(
      key: ValueKey(_shown[i].id),
      opacity: opacity,
      child: Transform.translate(
        offset: Offset(0, dy),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: widget.itemBuilder(_shown[i]),
        ),
      ),
    );
  }
}

// ── Full-height capsule action button (iOS-style) ────────────────────────────

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
    // delete-кнопке даём более сильный отклик — деструктивное действие
    final isDelete = color == ThemeColors.dangerZone;
    return Pressable(
      onTap: onTap,
      haptic: isDelete ? HapticStrength.heavy : HapticStrength.medium,
      scale: 0.94,
      child: Container(
        width: _SwipeableEventTileState._btnWidth,
        decoration: BoxDecoration(
          color: color,
          // Полукруглые торцы → вертикальная «капсула» во всю высоту карточки.
          borderRadius: BorderRadius.circular(
            _SwipeableEventTileState._btnWidth / 2,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 22),
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                  fontSize: 11,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Event tile card ──────────────────────────────────────────────────────────

class _EventTileCard extends StatelessWidget {
  final Event event;
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
    final overdue = event.isOverdueOn(_effectiveDate);
    final time = event.allDay
        ? 'Весь\nдень'
        : DateFormat('HH:mm').format(event.dateTime);

    return GlassPlate(
      transparent: false,
      color: Colors.white,
      padding: 0,
      child: Pressable(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 18),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (!event.fromNote) ...[
                  SizedBox(
                    width: 52,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        time,
                        style: Theme.of(context).textTheme.titleLarge!.copyWith(
                          color: overdue
                              ? ThemeColors.dangerZone
                              : context
                                    .watch<AppearanceController>()
                                    .secondaryColor,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),

                  // ── Vertical splitter ─────────────────────────────────────
                  Container(
                    width: 1,
                    margin: const EdgeInsets.symmetric(horizontal: 12),
                    color: context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(60),
                  ),
                ],

                // ── Icon + name + category + pet badges ───────────────────
                Expanded(
                  flex: 4,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      SoftRoundedIcon(
                        icon: event.style.icon,
                        color: event.style.color ?? event.category.color,
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
                              event.caption,
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
  final List<Event> events;
  final Map<String, String> petNames;
  final Map<String, Color> petColors;
  final ValueChanged<Event> onEventTap;

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

  List<Event> get _results {
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
      initialSize: null,
      maxSize: 0.7,
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
              decoration: baseInputDecoration(
                context,
                prefixIcon: Icon(Icons.search, color: context.titleColor),
                hint: 'Название события или категория...',
                suffixIcon: _query.isNotEmpty
                    ? Padding(
                        padding: EdgeInsetsGeometry.symmetric(horizontal: 6),
                        child: IconButton(
                          icon: Icon(Icons.close, color: context.titleColor),
                          onPressed: () {
                            _ctrl.clear();
                            setState(() => _query = '');
                          },
                        ),
                      )
                    : null,
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
              style: context.subtitleStyle,
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
  final Event event;
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
    final timeLabel = event.allDay
        ? 'Весь день'
        : DateFormat('HH:mm').format(event.dateTime);
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
                icon: event.style.icon,
                color: event.style.color,
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
