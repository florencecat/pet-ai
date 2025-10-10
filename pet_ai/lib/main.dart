import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_ai/services/profile_service.dart';

import '../pages/main_pages/home_page.dart';
import '../pages/main_pages/ai_chat_page.dart';
import '../pages/main_pages/calendar_page.dart';
import '../pages/secondary_pages/pet_registration_flow.dart';

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
        colorScheme: ColorScheme.fromSeed(
          seedColor: Color.fromARGB(255, 156, 213, 210),
        ),
        useMaterial3: true,
      ),
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('en'), Locale('ru')],
      locale: const Locale('ru'),
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
  bool _loading = true;
  bool _hasProfile = false;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  Future<void> _checkProfile() async {
    final hasProfile = await ProfileService().hasProfile();
    setState(() {
      _hasProfile = hasProfile;
      _loading = false;
    });
  }

  void _onRegistrationComplete() {
    setState(() => _hasProfile = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (!_hasProfile) {
      return PetRegistrationFlow(onComplete: _onRegistrationComplete);
    }

    final pages = [
      HomePage(onOpenCalendar: () => _onItemTapped(2)),
      const AIChatPage(),
      const CalendarPage(),
    ];

    return Scaffold(
      body: pages[_selectedIndex],
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