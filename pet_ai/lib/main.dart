import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:table_calendar/table_calendar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ru_RU', null);
  runApp(const PetHealthApp());
}

class PetHealthApp extends StatelessWidget {
  const PetHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pet Health Tracker',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const MainPage(),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

class _MainPageState extends State<MainPage> {
  int _selectedIndex = 0;

  final List<Widget> _pages = const [HomePage(), AIChatPage(), CalendarPage()];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        selectedItemColor: Colors.teal,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: 'Главная'),
          BottomNavigationBarItem(
            icon: Icon(Icons.chat_bubble_outline),
            label: 'AI Чат',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.calendar_month),
            label: 'Календарь',
          ),
        ],
      ),
    );
  }
}

//
// 🏠 Главная страница
//
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          Card.outlined(
            clipBehavior: Clip.hardEdge,
            child: InkWell(
              splashColor: Colors.blue.withAlpha(50),
              onTap: () {
                debugPrint('Card tapped.');
              },
              child:
                ListTile(
                  leading: const Icon(
                    Icons.pets_outlined,
                    size: 40,
                    color: Colors.teal,
                  ),
                  title: const Text('Барни'),
                  subtitle: const Text(
                    'Вельш-корги кардиган\n1.5 года',
                  ),
                ),
            ),
          ),
          const SizedBox(height: 16),
          Card.outlined(
            child: ListTile(
              title: const Text('Здоровье'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text('Последний осмотр: 10.09.2025'),
                  Text('Вес: 12.4 кг'),
                  Text('Активность: высокая'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Card.outlined(
            child: ListTile(
              title: const Text('Напоминания'),
              subtitle: const Text('Следующая вакцина: 15.10.2025'),
              trailing: const Icon(Icons.notifications_active_outlined),
            ),
          ),
        ],
      ),
    );
  }
}

//
// 🤖 Страница AI Чата
//
class AIChatPage extends StatefulWidget {
  const AIChatPage({super.key});

  @override
  State<AIChatPage> createState() => _AIChatPageState();
}

class _AIChatPageState extends State<AIChatPage> {
  final TextEditingController _controller = TextEditingController();
  String _response = '';
  final List<String> _history = [
    '💬 Как часто нужно чистить уши собаке?',
    '💬 Что делать, если питомец отказывается от еды?',
    '💬 Как понять, что пора к ветеринару?',
  ];

  //void _attachPhoto() {}

  void _sendPrompt() {
    setState(() {
      _response =
          '🤖 Ответ ИИ на запрос: "${_controller.text}".\n\n(В реальном приложении сюда подставится результат модели.)';
      _history.insert(0, _controller.text);
      _controller.clear();
    });
  }

  void _openHistorySheet() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      backgroundColor: Colors.grey[50],
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return ListView.builder(
              controller: scrollController,
              itemCount: _history.length,
              itemBuilder: (context, index) {
                final prompt = _history[index];
                return ListTile(
                  leading: const Icon(Icons.history),
                  title: Text(prompt),
                  subtitle: const Text('Ответ ИИ сохранён (заглушка)'),
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _response =
                          '📜 Повтор выбранного запроса:\n\n"$prompt"\n\n(Здесь можно подгрузить сохранённый ответ)';
                    });
                  },
                );
              },
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('AI Чат'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            tooltip: 'История запросов',
            onPressed: _openHistorySheet,
          ),
        ],
      ),
      body: SafeArea(
        child: Stack(
          children: [
            // Текст в центре
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: SingleChildScrollView(
                  child: Text(
                    _response.isEmpty
                        ? 'Задайте вопрос, чтобы получить ответ от ИИ.'
                        : _response,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),

            // Поле ввода внизу
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Введите вопрос об уходе за питомцем',
                          border: OutlineInputBorder(),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: Colors.teal),
                      onPressed: _sendPrompt,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

//
// 📅 Страница Календаря
//
class CalendarPage extends StatefulWidget {
  const CalendarPage({super.key});

  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  CalendarFormat _format = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  final Map<DateTime, List<String>> _events = {};

  void _addEvent(DateTime day) async {
    final TextEditingController controller = TextEditingController();
    await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Добавить событие'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: 'Введите событие'),
        ),
        actions: [
          TextButton(
            onPressed: () {
              if (controller.text.isNotEmpty) {
                setState(() {
                  _events[day] = (_events[day] ?? [])..add(controller.text);
                });
              }
              Navigator.pop(context);
            },
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TableCalendar(
          locale: 'ru_RU',
          focusedDay: _focusedDay,
          firstDay: DateTime.utc(2024),
          lastDay: DateTime.utc(2030),
          calendarFormat: _format,
          selectedDayPredicate: (day) => isSameDay(day, _selectedDay),
          onDaySelected: (selectedDay, focusedDay) {
            setState(() {
              _selectedDay = selectedDay;
              _focusedDay = focusedDay;
            });
          },
          onFormatChanged: (format) {
            setState(() => _format = format);
          },
        ),
        Expanded(
          child: ListView(
            children: [
              if (_selectedDay != null)
                ...(_events[_selectedDay] ?? []).map(
                  (e) => ListTile(
                    leading: const Icon(Icons.event),
                    title: Text(e),
                  ),
                ),
              TextButton.icon(
                onPressed: _selectedDay == null
                    ? null
                    : () => _addEvent(_selectedDay!),
                icon: const Icon(Icons.add),
                label: const Text('Добавить событие'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}