import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_ai/pages/main_pages/health_page.dart';
import 'package:pet_ai/services/ai_service.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/notification_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:provider/provider.dart';

import 'package:pet_ai/pages/main_pages/home_page.dart';
import 'package:pet_ai/pages/main_pages/ai_chat_page.dart';
import 'package:pet_ai/pages/main_pages/events_page.dart';
import 'package:pet_ai/pages/secondary_pages/pet_registration_flow.dart';
import 'package:pet_ai/theme/app_theme.dart';
import 'package:pet_ai/theme/widgets/floating_navigation_bar.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    await NotificationService().init();
  }

  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());

  await dotenv.load(fileName: ".env");

  await initializeDateFormatting('ru_RU', null);
  runApp(const PetHealthApp());
}

class PetHealthApp extends StatelessWidget {
  const PetHealthApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppearanceController()..load(),
      child: Consumer<AppearanceController>(
        builder: (context, appearance, _) {
          return MaterialApp(
            title: 'Pet Health Tracker',
            initialRoute: '/',
            routes: {'/registration': (context) => const PetRegistrationFlow()},
            theme: appearance.usePetColor
                ? AppTheme.withPalette(appearance.primaryPalette)
                : AppTheme.lightTheme,
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('en'), Locale('ru')],
            locale: const Locale('ru'),
            home: const MainPage(),
          );
        },
      ),
    );
  }
}

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => _MainPageState();
}

enum NavigationTab { home, health, chat, calendar }

class _MainPageState extends State<MainPage> {
  bool _loading = true;
  bool _hasProfile = false;
  NavigationTab _selectedIndex = NavigationTab.home;
  DateTime _calendarInitialDate = DateTime.now();
  Color? _healthScoreColor;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  void _onOpenCalendar() {
    setState(() {
      _selectedIndex = NavigationTab.calendar;
    });
  }

  void _onOpenCalendarByEvent(DateTime eventDate) {
    setState(() {
      _calendarInitialDate = eventDate;
      _selectedIndex = NavigationTab.calendar;
    });
  }

  Future<void> _checkProfile() async {
    // Однократная миграция событий из старого per-pet хранилища в глобальное v2
    final profiles = await ProfileService().loadAllProfiles();
    await EventService()
        .migrateFromLegacy(profiles.map((p) => p.id).toList());

    final hasProfile = await ProfileService().hasProfiles();
    if (mounted) {
      setState(() {
        _hasProfile = hasProfile;
        _loading = false;
      });
    }
    _refreshHealthScore();
  }

  Future<void> _refreshHealthScore() async {
    final profile = await ProfileService().loadActiveProfile();
    if (profile == null) return;
    final events = await EventService().loadEvents(profile.id);
    final badges = HealthAnalyzer.analyze(profile, events);
    final score = HealthAnalyzer.score(badges);
    if (mounted) setState(() => _healthScoreColor = score.palette.mainColor);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (!_hasProfile) {
      return PetRegistrationFlow();
    }

    final pages = [
      HomePage(
        onOpenCalendar: _onOpenCalendar,
        onOpenCalendarByEvent: _onOpenCalendarByEvent,
        onProfileSwitched: () {
          _checkProfile();
          _refreshHealthScore();
          context.read<AppearanceController>().reloadProfile();
        },
      ),
      const HealthPage(),
      const AIChatPage(),
      EventsPage(initialDate: _calendarInitialDate),
    ];

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          pages[_selectedIndex.index],

          // Floating Navbar
          Positioned(
            left: 16,
            right: 16,
            bottom: 24,
            child: SafeArea(
              top: false,
              child: FloatingNavigationBar(
                currentIndex: _selectedIndex.index,
                healthScoreColor: _healthScoreColor,
                onTap: (index) {
                  setState(() {
                    _selectedIndex = NavigationTab.values[index];
                  });
                  // Refresh health score when switching to health tab
                  if (index == NavigationTab.health.index) {
                    _refreshHealthScore();
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
