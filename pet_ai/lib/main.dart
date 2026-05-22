import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_satellite/pages/main_pages/ai_chat_page.dart';
import 'package:pet_satellite/pages/main_pages/events_page.dart';
import 'package:pet_satellite/pages/main_pages/health_page.dart';
import 'package:pet_satellite/pages/main_pages/home_page.dart';
import 'package:pet_satellite/pages/registration_flows/pet_registration_flow.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/health_service.dart';
import 'package:pet_satellite/services/notification_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_theme.dart';
import 'package:pet_satellite/theme/widgets/floating_navigation_bar.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await NotificationService().init();
    } catch (_) {
      // Notification service unavailable — continue without notifications.
    }
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
  final _homeKey = GlobalKey<HomePageState>();
  final _healthKey = GlobalKey<HealthPageState>();
  final _eventsKey = GlobalKey<EventsPageState>();
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
        key: _homeKey,
        onOpenCalendar: _onOpenCalendar,
        onOpenCalendarByEvent: _onOpenCalendarByEvent,
        onProfileSwitched: () {
          _checkProfile();
          _refreshHealthScore();
          context.read<AppearanceController>().reloadProfile();
        },
      ),
      HealthPage(key: _healthKey),
      const AIChatPage(),
      EventsPage(key: _eventsKey, initialDate: _calendarInitialDate),
    ];

    return Scaffold(
      // extendBody lets the page gradient bleed behind the glass navbar.
      extendBody: true,
      // Transparent so the inner-page gradient shows through the navbar region
      // instead of the Scaffold's own surface painting full-width there.
      backgroundColor: Colors.transparent,
      // Flutter does NOT propagate bottomNavigationBar height into
      // MediaQuery.padding.bottom for nested Scaffolds when extendBody: true.
      // We override it here so every inner Scaffold (e.g. EventsPage) positions
      // its FAB and bottom content above the glass navbar automatically.
      body: MediaQuery(
        data: MediaQuery.of(context).copyWith(
          padding: MediaQuery.of(context).padding.copyWith(
            bottom: MediaQuery.of(context).padding.bottom +
                FloatingNavigationBar.bottomInset,
          ),
        ),
        child: IndexedStack(
          index: _selectedIndex.index,
          children: pages,
        ),
      ),

      // Using bottomNavigationBar (instead of Positioned) means Flutter
      // automatically adjusts MediaQuery.padding.bottom for all descendants,
      // so inner-Scaffold FABs and ListViews position themselves correctly
      // without needing to know the navbar height.
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: FloatingNavigationBar(
            currentIndex: _selectedIndex.index,
            healthScoreColor: _healthScoreColor,
            onTap: (index) {
              setState(() {
                _selectedIndex = NavigationTab.values[index];
              });
              if (index == NavigationTab.home.index) {
                _homeKey.currentState?.refresh();
              }
              if (index == NavigationTab.health.index) {
                _healthKey.currentState?.refresh();
                _refreshHealthScore();
              }
              if (index == NavigationTab.calendar.index) {
                _eventsKey.currentState?.refresh();
              }
            },
          ),
        ),
      ),
    );
  }
}
