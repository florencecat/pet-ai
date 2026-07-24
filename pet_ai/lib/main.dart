import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
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
import 'package:pet_satellite/theme/widgets/draggable_sheets/event_sheet.dart';
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
  // initialize locale
  await initializeDateFormatting('ru_RU', null);

  // register services
  GetIt.instance.registerSingleton<ApiService>(
    ApiService(
      apiUrl: 'https://api.pet-sputnik.ru',
      aiUrl: 'https://ai.pet-sputnik.ru',
      privacyUrl: 'https://pet-sputnik.ru/legal/privacy-policy.html',
      termsUrl: 'https://pet-sputnik.ru/legal/terms-of-use.html',
    ),
  );
  // PocketBase loads its auth token from SecureStorage asynchronously.
  // Must complete before AuthService/CloudSyncService are constructed, or the
  // already-signed-in user will look anonymous to the backend → "Сессия истекла".
  final pbService = PocketBaseService(
    basePath: GetIt.instance<ApiService>().apiUrl,
  );
  await pbService.init();
  GetIt.instance.registerSingleton<PocketBaseService>(pbService);
  GetIt.instance.registerSingleton<AuthService>(
    AuthService(pbService: GetIt.instance<PocketBaseService>()),
  );
  GetIt.instance.registerSingleton<CloudSyncService>(
    CloudSyncService(pbService: GetIt.instance<PocketBaseService>()),
  );
  await GetIt.instance<CloudSyncService>().init();
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

  /// Глобальный ключ навигатора — позволяет открывать экраны из обработчиков
  /// тапа по уведомлению, у которых нет своего BuildContext.
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AppearanceController()..load(),
      child: Consumer<AppearanceController>(
        builder: (context, appearance, _) {
          return MaterialApp(
            title: 'Pet Health Tracker',
            navigatorKey: navigatorKey,
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
            // Глобально скрываем клавиатуру при тапе мимо полей ввода. Оборачивает
            // весь Navigator (включая модальные листы), поэтому не нужно вешать
            // GestureDetector на каждый экран. translucent + onTap не мешают
            // дочерним кнопкам: тап по интерактиву достаётся ему, а по пустому
            // месту — снимает фокус.
            builder: (context, child) => GestureDetector(
              behavior: HitTestBehavior.translucent,
              onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
              child: child,
            ),
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

class _MainPageState extends State<MainPage> with WidgetsBindingObserver {
  bool _loading = true;
  bool _hasProfile = false;
  NavigationTab _selectedIndex = NavigationTab.home;
  final _homeKey = GlobalKey<HomePageState>();
  final _healthKey = GlobalKey<HealthPageState>();
  final _eventsKey = GlobalKey<EventsPageState>();
  final _chatKey = GlobalKey<AIChatPageState>();
  DateTime _calendarInitialDate = DateTime.now();
  Color? _healthScoreColor;

  /// Одноразовый показ уведомления о сборе диагностики за сессию.
  // Static: гвард переживает пересоздание состояния (переключение питомца,
  // пересборка дерева после онбординга), чтобы окно не показалось дважды.
  static bool _crashConsentChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Тап по уведомлению при живом приложении — открыть/отметить событие.
    NotificationService.onOpenEvent = _handleOpenEvent;
    NotificationService.onCompleteEvent = _handleCompleteEvent;
    PetProfileService.activeProfileChanged.addListener(_onProfileSwitched);
    _checkProfile();
    _bootstrapNotifications();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    NotificationService.onOpenEvent = null;
    NotificationService.onCompleteEvent = null;
    PetProfileService.activeProfileChanged.removeListener(_onProfileSwitched);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Каждый возврат в приложение пересобирает расписание (на случай сброса
    // системных будильников оптимизациями питания) и разбирает отложенные тапы.
    if (state == AppLifecycleState.resumed) {
      _bootstrapNotifications();
    }
  }

  /// Точка входа регистрации уведомлений: при каждом открытии приложения
  /// асинхронно пересобираем расписание и обрабатываем отложенные действия по
  /// тапу из «холодного» старта. Не блокирует UI.
  void _bootstrapNotifications() {
    // Пересборка расписания не блокирует UI.
    EventService().rescheduleAllNotifications();
    // Отложенные действия по тапу разбираем после первого кадра — для открытия
    // листа события нужен готовый Navigator.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumePendingNotificationActions(),
    );
  }

  Future<void> _consumePendingNotificationActions() async {
    final completeId =
        await NotificationService.consumePendingCompleteEventId();
    if (completeId != null) await _handleCompleteEvent(completeId);
    final openId = await NotificationService.consumePendingOpenEventId();
    if (openId != null) await _handleOpenEvent(openId);
  }

  /// Открывает связанное событие в листе деталей (по тапу на уведомление).
  Future<void> _handleOpenEvent(String eventId) async {
    final event = await EventService().findById(eventId);
    if (event == null) return;
    final ctx = PetHealthApp.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;
    await showModalBottomSheet<void>(
      context: ctx,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event),
    );
  }

  /// Отмечает событие выполненным на сегодня (быстрое действие «Выполнено»).
  Future<void> _handleCompleteEvent(String eventId) async {
    final event = await EventService().findById(eventId);
    if (event == null || event.petIds.isEmpty) return;
    final today = DateTime.now();
    if (event.isCompletedOn(today)) return;
    await EventService().toggleCompleted(event.petIds.first, event, today);
    if (mounted) {
      _eventsKey.currentState?.refresh();
      _refreshHealthScore();
    }
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
    final hasProfile = await PetProfileService().hasProfiles();
    if (mounted) {
      setState(() {
        _hasProfile = hasProfile;
        _loading = false;
      });
    }
    _refreshHealthScore();
    // Первичное уведомление о сборе диагностики показываем на главном экране —
    // после онбординга (у нового пользователя) либо сразу (при обновлении).
    // Следом, не наслаиваясь на него, — обучение по главному экрану.
    if (hasProfile) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await _maybeShowCrashConsent();
        if (!mounted || _selectedIndex != NavigationTab.home) return;
        await _homeKey.currentState?.maybeShowOnboarding();
      });
    }
  }

  /// Однократно уведомляет пользователя о том, что приложение может отправлять
  /// обезличенные отчёты о сбоях (модель opt-out: включено по умолчанию, здесь
  /// можно сразу отключить). Соответствует требованиям к прозрачности сбора
  /// диагностических данных.
  Future<void> _maybeShowCrashConsent() async {
    if (_crashConsentChecked) return;
    _crashConsentChecked = true;

    final crash = CrashReportingService.instance;
    if (await crash.isNoticeShown()) return;

    final ctx = PetHealthApp.navigatorKey.currentContext;
    if (ctx == null || !ctx.mounted) return;

    // Помечаем показанным сразу, до открытия окна: иначе повторный триггер
    // (пока пользователь не закрыл диалог) снова увидит isNoticeShown == false
    // и откроет второе такое же окно.
    await crash.markNoticeShown();
    if (!ctx.mounted) return;

    final keepEnabled = await showDialog<bool>(
      context: ctx,
      barrierDismissible: false,
      builder: (dctx) => AlertDialog(
        title: const Text('Помогите улучшить приложение'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Приложение может отправлять обезличенные отчёты о сбоях, чтобы '
              'мы быстрее находили и исправляли ошибки. Отчёты не содержат '
              'ваших личных данных. Это можно изменить в любой момент '
              'в настройках.',
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () => GetIt.instance<ApiService>().openPrivacy(),
              child: Text(
                'Политика конфиденциальности',
                style: TextStyle(
                  color: Theme.of(dctx).colorScheme.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, false),
            child: const Text('Отключить'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, true),
            child: const Text('Разрешить'),
          ),
        ],
      ),
    );

    // Явный отказ — выключаем сбор. null (жест «назад») трактуем как «оставить
    // по умолчанию включённым» согласно модели opt-out.
    if (keepEnabled == false) {
      await crash.setEnabled(false);
    }
  }

  /// Единая реакция на смену активного питомца — из любого места приложения
  /// (см. [PetProfileService.activeProfileChanged]).
  ///
  /// Все вкладки живут в IndexedStack и сами не пересоздаются, а палитра и
  /// контроллер чата держат данные прежнего питомца, поэтому обновляем их явно.
  void _onProfileSwitched() {
    if (!mounted) return;
    _checkProfile(); // внутри — _refreshHealthScore()
    context.read<AppearanceController>().reloadProfile();
    _homeKey.currentState?.refresh();
    _healthKey.currentState?.refresh();
    _eventsKey.currentState?.refresh();
    _chatKey.currentState?.reloadPet();
  }

  Future<void> _refreshHealthScore() async {
    final profile = await PetProfileService().loadActiveProfile();
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
      ),
      HealthPage(key: _healthKey, onHealthChanged: _refreshHealthScore),
      AIChatPage(key: _chatKey),
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
          textScaler: MediaQuery.of(
            context,
          ).textScaler.clamp(minScaleFactor: 0.8, maxScaleFactor: 1.1),
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
                // Страница живёт в IndexedStack и создаётся вместе с главной,
                // поэтому «пользователь пришёл сюда» знает только навигация.
                _healthKey.currentState?.maybeShowOnboarding();
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
