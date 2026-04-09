import 'package:flutter/material.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../services/event_service.dart';
import '../../../theme/widgets/draggable_scrollable_sheet.dart';
import '../../../theme/app_colors.dart';

class CalendarPage extends StatefulWidget {
  final DateTime? initialDate;
  final DateTime selectedDate;

  CalendarPage({super.key, this.initialDate}) : selectedDate = DateTime.now();

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _format = CalendarFormat.month;
  late DateTime _focusedDay = DateTime.now();
  late DateTime? _selectedDay;

  List<PetEvent> _events = [];

  void openCreateEventSheet(BuildContext context, DateTime dateTime) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDraggableSheet.create(dateTime: dateTime),
    );

    if (updated == true) {
      final events = await EventService().loadEvents();
      setState(() {
        _events = events;
      });
    }
  }

  void openViewEventSheet(BuildContext context, PetEvent event) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDraggableSheet(event: event),
    );

    if (updated == true) {
      final events = await EventService().loadEvents();
      setState(() {
        _events = events;
      });
    }
  }

  Future<void> _loadEvents() async {
    setState(() {
    });

    final events = await EventService().loadEvents();
    if (events.length > 1) {
      events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    setState(() {
      _events = events;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        padding: EdgeInsetsGeometry.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            tileMode: TileMode.mirror,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThemeColors.gradientBegin.withAlpha(96),
              ThemeColors.gradientEnd.withAlpha(64),
            ],
          ),
        ),
        child: Column(
          children: [
            GlassPlate(
              child: Padding(
                padding: EdgeInsetsGeometry.all(16),
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
                            return Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: (event as PetEvent).category.color,
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
                    return _events
                        .where((e) => DateUtils.isSameDay(e.dateTime, day))
                        .toList();
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
                    _events = await EventService().loadEvents();
                  },
                  onFormatChanged: (format) {
                    setState(() => _format = format);
                  },
                ),
              ),
            ),
            const SizedBox(height: 16),

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

            // Expanded(
            //   child: InlineLoading(
            //     isLoading: _isLoadingEvents,
            //     child: ListView(
            //       children: [
            //         TextButton. icon(
            //           onPressed: ,
            //           icon:
            //           label:
            //         ),
            //         const SizedBox(height: 16),
            //         if (_selectedDay != null && _events.isNotEmpty)
            //           ...(_events.where(
            //             (e) =>
            //                 e.dateTime.year == _selectedDay!.year &&
            //                 e.dateTime.month == _selectedDay!.month &&
            //                 e.dateTime.day == _selectedDay!.day,
            //           )).map(
            //             (e) => EventCard(
            //               event: e,
            //               callback: () => openViewEventSheet(context, e),
            //             ),
            //           ),
            //       ],
            //     ),
            //   ),
            // ),
          ],
        ),
      ),
    );
  }
}
