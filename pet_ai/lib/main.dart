import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:get_it/get_it.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:pet_satellite/pages/main_pages/ai_chat_page.dart';
import 'package:pet_satellite/pages/main_pages/events_page.dart';
import 'package:pet_satellite/pages/main_pages/health_page.dart';
import 'package:pet_satellite/pages/main_pages/home_page.dart';
import 'package:pet_satellite/pages/registration_flows/pet_registration_flow.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/api_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/crash_reporting_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/health_service.dart';
import 'package:pet_satellite/services/notification_service.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_theme.dart';
import 'package:pet_satellite/theme/widgets/floating_navigation_bar.dart';
import 'package:provider/provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // enable notifications only for web
  if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
    try {
      await NotificationService().init();
    } catch (_) {}
  }
  // initialize hive db
  await Hive.initFlutter();
  Hive.registerAdapter(ChatMessageAdapter());
  // initialize environment
  await dotenv.load(fileName: ".env");
  // initialize locale
  await initializeDateFormatting('ru_RU', null);

  // register services
  GetIt.instance.registerSingleton<ApiService>(
    ApiService(
      apiUrl: 'https://api.pet-sputnik.ru',
      aiUrl: 'https://ai.pet-sputnik.ru',
    ),
  );
  GetIt.instance.registerSingleton<PocketBaseService>(
    PocketBaseService(basePath: GetIt.instance<ApiService>().apiUrl),
  );
  GetIt.instance.registerSingleton<AuthService>(
    AuthService(pbService: GetIt.instance<PocketBaseService>()),
  );
  GetIt.instance.registerSingleton<CloudSyncService>(
    CloudSyncService(pbService: GetIt.instance<PocketBaseService>()),
  );
  // Crash/error reporting — устанавливает глобальные обработчики ошибок и
  // отправляет их в PocketBase (если включено в настройках).
  GetIt.instance.registerSingleton<CrashReportingService>(
    CrashReportingService(pbService: GetIt.instance<PocketBaseService>()),
  );
  await GetIt.instance<CrashReportingService>().init();

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
      _eventsKey.currentState?.refresh();
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
    final profiles = await PetService().loadAllProfiles();
    await EventService().migrateFromLegacy(profiles.map((p) => p.id).toList());

    final hasProfile = await PetService().hasProfiles();
    if (mounted) {
      setState(() {
        _hasProfile = hasProfile;
        _loading = false;
      });
    }
    _refreshHealthScore();
  }

  Future<void> _refreshHealthScore() async {
    final profile = await PetService().loadActiveProfile();
    if (profile == null) return;
    final events = await EventService().loadEvents(profile.id);
    final badges = await HealthAnalyzer.analyze(profile, events);
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
      HealthPage(key: _healthKey, onHealthChanged: _refreshHealthScore),
      const AIChatPage(),
      EventsPage(key: _eventsKey, initialDate: _calendarInitialDate),
    ];

    return Scaffold(
      // extendBody lets the page gradient bleed behind the glass navbar.
      extendBody: true,
      // Не ресайзим IndexedStack под клавиатуру: страницы вводят текст только в
      // модальных листах (со своим учётом клавиатуры), а чат сам поднимает поле
      // ввода. Иначе внешний ресайз сжимал бы активную страницу — и контент
      // «улетал» наверх при открытии клавиатуры.
      resizeToAvoidBottomInset: false,
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
            bottom:
                MediaQuery.of(context).padding.bottom +
                FloatingNavigationBar.bottomInset,
          ),
        ),
        child: IndexedStack(index: _selectedIndex.index, children: pages),
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
              final isSameTab = _selectedIndex.index == index;
              setState(() {
                _selectedIndex = NavigationTab.values[index];
              });
              // Re-tapping the active tab should not trigger a reload —
              // it surfaced skeleton states for no reason.
              if (isSameTab) return;
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
