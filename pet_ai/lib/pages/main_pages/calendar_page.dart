import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../services/event_service.dart';
import '../../../theme/widgets/draggable_scrollable_sheet.dart';
import '../../../theme/app_styles.dart';

class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}



class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  List<PetEvent> _events = [];

  void openEventSheet(BuildContext context, DateTime dateTime) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDraggableSheet.create(mode: EventSheetMode.create, dateTime: dateTime),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Card.outlined(
              shape: cardBorder,
              child: Padding(
                padding: EdgeInsets.all(16),
                child: TableCalendar(
                  locale: 'ru_RU',
                  focusedDay: _focusedDay,
                  firstDay: DateTime.utc(2024),
                  lastDay: DateTime.utc(2030),
                  calendarFormat: _format,
                  headerStyle: HeaderStyle(formatButtonVisible: false),
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: Color.fromARGB(128, 59, 128, 123),
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: BoxDecoration(
                      color: Color.fromARGB(255, 59, 128, 123),
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
            Expanded(
              child: ListView(
                children: [
                  TextButton.icon(
                    onPressed: _selectedDay == null
                        ? null
                        : () => openEventSheet(context, _selectedDay!),
                    // onPressed: () async {
                    //   final added = await Navigator.push(
                    //     context,
                    //     MaterialPageRoute(
                    //       builder: (_) => const EventDraggableSheet(
                    //         mode: EventSheetMode.view,
                    //       ),
                    //     ),
                    //   );
                    //   if (added == true && mounted) {
                    //     ScaffoldMessenger.of(context).showSnackBar(
                    //       const SnackBar(content: Text('Событие добавлено')),
                    //     );
                    //   }
                    // },
                    icon: const Icon(Icons.add),
                    label: const Text('Добавить событие'),
                  ),

                  if (_selectedDay != null && _events.isNotEmpty)
                    ...(_events.where(
                      (e) =>
                          e.dateTime.year == _selectedDay!.year &&
                          e.dateTime.month == _selectedDay!.month &&
                          e.dateTime.day == _selectedDay!.day,
                    )).map(
                      (e) => Card.outlined(
                        clipBehavior: Clip.antiAlias,
                        shape: cardBorder,
                        child: InkWell(
                          splashColor: Colors.blue.withAlpha(50),
                          onTap: () {
                            debugPrint('Card tapped.');
                          },
                          child: ListTile(
                            leading: const Icon(Icons.event),
                            title: Text(e.name),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
