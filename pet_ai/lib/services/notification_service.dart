import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:pet_satellite/models/event.dart' as model;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

// ─── Ключи отложенных действий по тапу ───────────────────────────────────────
// Хранятся в SharedPreferences, чтобы переживать «холодный» старт и работать из
// фонового изолятора (тап по действию, когда приложение убито).
const _kPendingOpen = 'notif_pending_open';
const _kPendingComplete = 'notif_pending_complete';

/// Параметры локальных уведомлений, настраиваемые пользователем.
/// Хранятся в SharedPreferences; читаются при планировании каждого напоминания
/// и при полной пересборке расписания.
class NotificationSettings {
  /// Главный тумблер. Если выключен — расписание стирается, ничего не шлём.
  final bool enabled;

  /// Тихие часы: напоминания, попадающие в интервал, не планируются.
  final bool quietHoursEnabled;
  final int quietStartMinutes; // минуты от полуночи (22:00 → 1320)
  final int quietEndMinutes; // 08:00 → 480

  /// Звук уведомления (иначе — беззвучно).
  final bool sound;

  /// Вибрация при уведомлении (Android).
  final bool vibrate;

  /// Повышенная важность — всплывающее уведомление (heads-up) на Android.
  final bool highImportance;

  /// Час доставки напоминаний о событиях «на весь день» — минуты от полуночи
  /// (09:00 → 540). У all-day события нет времени суток (хранится 00:00),
  /// поэтому напоминание шлём в этот фиксированный момент, а не в полночь.
  final int allDayReminderMinutes;

  const NotificationSettings({
    this.enabled = true,
    this.quietHoursEnabled = false,
    this.quietStartMinutes = 22 * 60,
    this.quietEndMinutes = 8 * 60,
    this.sound = true,
    this.vibrate = true,
    this.highImportance = true,
    this.allDayReminderMinutes = 9 * 60,
  });

  static const _kEnabled = 'notif_enabled';
  static const _kQuietEnabled = 'notif_quiet_enabled';
  static const _kQuietStart = 'notif_quiet_start';
  static const _kQuietEnd = 'notif_quiet_end';
  static const _kSound = 'notif_sound';
  static const _kVibrate = 'notif_vibrate';
  static const _kHighImportance = 'notif_high_importance';
  static const _kAllDayReminder = 'notif_all_day_reminder';

  static Future<NotificationSettings> load() async {
    final p = SharedPreferencesAsync();
    return NotificationSettings(
      enabled: await p.getBool(_kEnabled) ?? true,
      quietHoursEnabled: await p.getBool(_kQuietEnabled) ?? false,
      quietStartMinutes: await p.getInt(_kQuietStart) ?? 22 * 60,
      quietEndMinutes: await p.getInt(_kQuietEnd) ?? 8 * 60,
      sound: await p.getBool(_kSound) ?? true,
      vibrate: await p.getBool(_kVibrate) ?? true,
      highImportance: await p.getBool(_kHighImportance) ?? true,
      allDayReminderMinutes: await p.getInt(_kAllDayReminder) ?? 9 * 60,
    );
  }

  Future<void> save() async {
    final p = SharedPreferencesAsync();
    await p.setBool(_kEnabled, enabled);
    await p.setBool(_kQuietEnabled, quietHoursEnabled);
    await p.setInt(_kQuietStart, quietStartMinutes);
    await p.setInt(_kQuietEnd, quietEndMinutes);
    await p.setBool(_kSound, sound);
    await p.setBool(_kVibrate, vibrate);
    await p.setBool(_kHighImportance, highImportance);
    await p.setInt(_kAllDayReminder, allDayReminderMinutes);
  }

  NotificationSettings copyWith({
    bool? enabled,
    bool? quietHoursEnabled,
    int? quietStartMinutes,
    int? quietEndMinutes,
    bool? sound,
    bool? vibrate,
    bool? highImportance,
    int? allDayReminderMinutes,
  }) {
    return NotificationSettings(
      enabled: enabled ?? this.enabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietStartMinutes: quietStartMinutes ?? this.quietStartMinutes,
      quietEndMinutes: quietEndMinutes ?? this.quietEndMinutes,
      sound: sound ?? this.sound,
      vibrate: vibrate ?? this.vibrate,
      highImportance: highImportance ?? this.highImportance,
      allDayReminderMinutes:
          allDayReminderMinutes ?? this.allDayReminderMinutes,
    );
  }

  /// Попадает ли момент [t] (по времени суток) в интервал тихих часов.
  bool isQuiet(DateTime t) {
    if (!quietHoursEnabled) return false;
    if (quietStartMinutes == quietEndMinutes) return false;
    final m = t.hour * 60 + t.minute;
    if (quietStartMinutes < quietEndMinutes) {
      return m >= quietStartMinutes && m < quietEndMinutes;
    }
    // Интервал переходит через полночь (например 22:00 → 08:00).
    return m >= quietStartMinutes || m < quietEndMinutes;
  }
}

/// Фоновый обработчик тапа по уведомлению/действию, когда приложение убито.
/// Выполняется в отдельном изоляторе — UI отсюда недоступен, поэтому просто
/// сохраняем намерение, а применяем его при следующем запуске приложения.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  final payload = response.payload;
  if (payload == null || payload.isEmpty) return;
  final key = response.actionId == 'complete' ? _kPendingComplete : _kPendingOpen;
  // fire-and-forget: ошибки канала в фоновом изоляторе глотаем.
  SharedPreferencesAsync().setString(key, payload);
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const _channelName = 'Напоминания';
  static const _channelDesc = 'Напоминания о событиях питомца';
  static const _iosCategoryId = 'pet_event';

  // Один канал напоминаний. Параметры канала (звук/вибрация/важность) на
  // Android O+ неизменяемы после создания, а пересоздание канала с тем же id
  // восстанавливает прежние настройки (Android намеренно защищает выбор
  // пользователя). Поэтому при смене настроек мы создаём НОВЫЙ канал со свежим
  // id (поколение растёт) и удаляем прежний — так в системных настройках всегда
  // ровно один канал, и новые параметры реально применяются.
  static const _kChannelGen = 'notif_channel_gen';
  static const _channelIdPrefix = 'pet_reminders_g';

  // Отдельный «тихий» канал для напоминаний, попадающих в тихие часы: без звука,
  // вибрации и всплытия (importance low). На Android O+ звук/вибрацию задаёт
  // именно канал, поэтому беззвучность одной нотификации достижима только через
  // такой канал. Его параметры постоянны → фиксированный id без поколений.
  static const _quietChannelId = 'pet_reminders_quiet';
  static const _quietChannelName = 'Напоминания (тихие часы)';
  static const _quietChannelDesc =
      'Беззвучные напоминания, попадающие в тихие часы';

  // Префиксы всех каналов, которые когда-либо создавало приложение — по ним
  // вычищаем устаревшие каналы (включая старые варианты pet_events_*).
  static const _ownedChannelPrefixes = ['pet_events', 'pet_reminders'];

  Future<String> _currentChannelId() async {
    final gen = await SharedPreferencesAsync().getInt(_kChannelGen) ?? 0;
    return '$_channelIdPrefix$gen';
  }

  /// Колбэки навигации, выставляются приложением (см. main). Срабатывают, когда
  /// приложение живо (foreground/background). Для «холодного» старта и убитого
  /// состояния используется отложенное действие в SharedPreferences.
  static void Function(String eventId)? onOpenEvent;
  static void Function(String eventId)? onCompleteEvent;

  Future<void> init() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    // Маленькая иконка уведомления — монохромный силуэт (res/drawable/ic_notification).
    // Полноцветный ic_launcher Android маскирует по альфе → серый квадрат.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('ic_notification');

    final DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              _iosCategoryId,
              actions: [
                DarwinNotificationAction.plain(
                  'complete',
                  'Выполнено',
                  options: {DarwinNotificationActionOption.foreground},
                ),
              ],
            ),
          ],
        );

    final InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // Создаём текущий канал заранее (на случай отсутствия событий) и подчищаем
    // устаревшие каналы от прежних поколений/вариантов.
    final settings = await NotificationSettings.load();
    await _ensureChannel(settings);
    await _cleanupChannels({await _currentChannelId(), _quietChannelId});

    // Приложение запущено тапом по уведомлению из убитого состояния — сохраняем
    // намерение, чтобы обработать его после инициализации UI.
    final launch = await _notificationsPlugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) {
      final resp = launch!.notificationResponse;
      await _storePending(resp?.actionId, resp?.payload);
    }
  }

  /// Callback при нажатии на уведомление или действие в нём (приложение живо).
  /// actionId 'complete' — пометить событие выполненным; иначе тап по телу —
  /// открыть связанное событие.
  static void _onNotificationResponse(NotificationResponse details) {
    final payload = details.payload;
    if (payload == null || payload.isEmpty) return;
    if (details.actionId == 'complete') {
      if (onCompleteEvent != null) {
        onCompleteEvent!(payload);
      } else {
        _storePending('complete', payload);
      }
    } else {
      if (onOpenEvent != null) {
        onOpenEvent!(payload);
      } else {
        _storePending(null, payload);
      }
    }
  }

  static Future<void> _storePending(String? actionId, String? payload) async {
    if (payload == null || payload.isEmpty) return;
    final p = SharedPreferencesAsync();
    await p.setString(
      actionId == 'complete' ? _kPendingComplete : _kPendingOpen,
      payload,
    );
  }

  /// Забрать и очистить отложенное «открыть событие» (после старта/resume).
  static Future<String?> consumePendingOpenEventId() async {
    final p = SharedPreferencesAsync();
    final v = await p.getString(_kPendingOpen);
    if (v != null) await p.remove(_kPendingOpen);
    return v;
  }

  /// Забрать и очистить отложенное «отметить выполненным» (после старта/resume).
  static Future<String?> consumePendingCompleteEventId() async {
    final p = SharedPreferencesAsync();
    final v = await p.getString(_kPendingComplete);
    if (v != null) await p.remove(_kPendingComplete);
    return v;
  }

  /// Call this before scheduling the first notification for a new event.
  /// Requests OS permission if not already granted. Silently ignores errors.
  Future<void> ensurePermission() async {
    try {
      await _requestPermissions();
    } catch (_) {
      // Permission denied or unavailable — continue without crashing.
    }
  }

  Future<void> _requestPermissions() async {
    if (!kIsWeb && Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } else if (!kIsWeb && Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  // ── Канал ──────────────────────────────────────────────────────────────────

  AndroidNotificationChannel _buildChannel(String id, NotificationSettings s) =>
      AndroidNotificationChannel(
        id,
        _channelName,
        description: _channelDesc,
        // IMPORTANCE_HIGH — порог для всплывающих (heads-up) уведомлений со звуком.
        importance:
            s.highImportance ? Importance.high : Importance.defaultImportance,
        playSound: s.sound,
        enableVibration: s.vibrate,
      );

  /// Тихий канал: всегда без звука, вибрации и всплытия (importance low).
  AndroidNotificationChannel _buildQuietChannel() =>
      const AndroidNotificationChannel(
        _quietChannelId,
        _quietChannelName,
        description: _quietChannelDesc,
        importance: Importance.low,
        playSound: false,
        enableVibration: false,
      );

  AndroidFlutterLocalNotificationsPlugin? get _android => _notificationsPlugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  /// Создаёт текущий (звуковой) и тихий каналы, если их ещё нет
  /// (idempotent, дёшево).
  Future<void> _ensureChannel(NotificationSettings s) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final id = await _currentChannelId();
    await _android?.createNotificationChannel(_buildChannel(id, s));
    await _android?.createNotificationChannel(_buildQuietChannel());
  }

  /// Удаляет все каналы приложения, кроме [keepIds] — чистит «мусор» от прежних
  /// поколений и старых вариантов канала. Тихий канал всегда должен быть в
  /// [keepIds], иначе его снесёт (его id тоже под owned-префиксом).
  Future<void> _cleanupChannels(Set<String> keepIds) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final android = _android;
    if (android == null) return;
    final channels = await android.getNotificationChannels() ?? [];
    for (final c in channels) {
      if (keepIds.contains(c.id)) continue;
      if (_ownedChannelPrefixes.any((p) => c.id.startsWith(p))) {
        await android.deleteNotificationChannel(c.id);
      }
    }
  }

  /// Применяет новые параметры канала: создаёт канал со свежим id (поколение +1,
  /// чтобы настройки точно вступили в силу) и удаляет прежние. Вызывающая сторона
  /// затем пересобирает расписание на новый канал. Тихий канал сохраняется.
  Future<void> applyChannelSettings(NotificationSettings s) async {
    if (kIsWeb || !Platform.isAndroid) return;
    final p = SharedPreferencesAsync();
    final gen = await p.getInt(_kChannelGen) ?? 0;
    await p.setInt(_kChannelGen, gen + 1);
    await _ensureChannel(s); // создаёт новый звуковой канал + тихий
    await _cleanupChannels({await _currentChannelId(), _quietChannelId});
  }

  // ── Планирование ─────────────────────────────────────────────────────────

  Future<void> scheduleEventNotification(
    model.Event event, {
    String? petLabel,
    NotificationSettings? settings,
  }) async {
    if (!event.remind) return;
    final s = settings ?? await NotificationSettings.load();
    if (!s.enabled) return;

    // курс завершён — не планируем
    final end = event.repeatEndDate;
    if (end != null && DateTime.now().isAfter(DateTime(end.year, end.month, end.day, 23, 59, 59))) {
      return;
    }

    final id = event.id.hashCode;

    // Вычисляем время напоминания (с учётом отсрочки).
    // Для события «на весь день» отсчёт от полуночи (event.dateTime = 00:00)
    // бессмысленен — доставляем в фиксированный час (allDayReminderMinutes),
    // а «напомнить за» трактуем только в целых днях.
    final DateTime scheduledTime;
    if (event.allDay) {
      final base = DateTime(
        event.dateTime.year,
        event.dateTime.month,
        event.dateTime.day,
        s.allDayReminderMinutes ~/ 60,
        s.allDayReminderMinutes % 60,
      );
      scheduledTime = base.subtract(Duration(days: event.remindBeforeValue));
    } else {
      // Смещение «за N единиц» вычисляет сам Remindable.
      scheduledTime = event.reminderTimeFor(event.dateTime);
    }

    // Тихие часы: напоминание НЕ теряется — планируем его в отдельный тихий
    // канал (без звука, вибрации и всплытия), чтобы не будить пользователя.
    // Решение зависит только от времени суток срабатывания, а оно одинаково у
    // всех повторов (у повтора тот же час/минута), поэтому вычисляем один раз.
    final quiet = s.isQuiet(scheduledTime);

    if (scheduledTime.isBefore(DateTime.now()) &&
        event.repeat == model.RepeatInterval.none) {
      return; // Пропускаем, если время уже прошло и повторов нет.
    }

    // Преобразуем интервал в формат библиотеки.
    DateTimeComponents? matchComponents;
    if (event.repeat == model.RepeatInterval.daily) {
      matchComponents = DateTimeComponents.time;
    } else if (event.repeat == model.RepeatInterval.weekly ||
        event.repeat == model.RepeatInterval.custom) {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (event.repeat == model.RepeatInterval.monthly) {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    // В тихие часы — тихий канал и приглушённые параметры. На Android < O канал
    // не действует, поэтому важны и сами флаги нотификации (playSound/priority).
    final channelId = quiet ? _quietChannelId : await _currentChannelId();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      quiet ? _quietChannelName : _channelName,
      channelDescription: quiet ? _quietChannelDesc : _channelDesc,
      icon: 'ic_notification',
      importance: quiet
          ? Importance.low
          : (s.highImportance ? Importance.high : Importance.defaultImportance),
      priority: quiet
          ? Priority.low
          : (s.highImportance ? Priority.high : Priority.defaultPriority),
      playSound: s.sound && !quiet,
      enableVibration: s.vibrate && !quiet,
      actions: const [
        AndroidNotificationAction(
          'complete',
          'Выполнено ✓',
          cancelNotification: true,
        ),
      ],
    );

    final iosDetails = DarwinNotificationDetails(
      presentSound: s.sound && !quiet,
      categoryIdentifier: _iosCategoryId,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    // Информативное содержимое: «Питомец · Категория» в заголовке, наименование
    // (с отсрочкой) — в теле.
    final categoryName = event.caption.trim();
    final hasPet = petLabel != null && petLabel.isNotEmpty;
    final String title;
    if (hasPet && categoryName.isNotEmpty) {
      title = '$petLabel · $categoryName';
    } else if (hasPet) {
      title = petLabel;
    } else if (categoryName.isNotEmpty) {
      title = categoryName;
    } else {
      title = 'Напоминание';
    }
    final remindVariant = event.allDay
        ? model.RemindBeforeVariant.days
        : event.remindBeforeVariant;
    final body = event.remindBeforeValue > 0
        ? "${event.name} (через ${event.remindBeforeValue} ${remindVariant.declension(event.remindBeforeValue)})"
        : event.name;

    // Гарантируем существование канала с актуальными настройками.
    await _ensureChannel(s);

    if (event.repeat == model.RepeatInterval.custom &&
        event.customDays.isNotEmpty) {
      // Для custom — планируем уведомление на каждый выбранный день недели.
      for (int i = 0; i < event.customDays.length; i++) {
        final dayOfWeek = event.customDays[i];
        final nextOccurrence = _nextWeekday(scheduledTime, dayOfWeek);
        await _notificationsPlugin.zonedSchedule(
          id + i,
          title,
          body,
          tz.TZDateTime.from(nextOccurrence, tz.local),
          notificationDetails,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.dayOfWeekAndTime,
          payload: event.id,
        );
      }
    } else {
      await _notificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(scheduledTime, tz.local),
        notificationDetails,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        matchDateTimeComponents: matchComponents,
        payload: event.id,
      );
    }
  }

  /// Возвращает ближайшую дату с указанным днём недели (1=Пн..7=Вс).
  DateTime _nextWeekday(DateTime from, int weekday) {
    int daysAhead = weekday - from.weekday;
    if (daysAhead <= 0) daysAhead += 7;
    return from.add(Duration(days: daysAhead));
  }

  Future<void> cancelNotification(String eventId) async {
    final id = eventId.hashCode;
    await _notificationsPlugin.cancel(id);
    // Также отменяем возможные custom-day уведомления (id+0..id+6).
    for (int i = 1; i < 7; i++) {
      await _notificationsPlugin.cancel(id + i);
    }
  }

  /// Снимает все запланированные уведомления (в т.ч. «осиротевшие»).
  Future<void> cancelAll() async {
    await _notificationsPlugin.cancelAll();
  }

  /// Немедленно показывает тестовое уведомление — для проверки звука/вибрации и
  /// всплытия (heads-up) на устройстве без ожидания запланированного времени.
  Future<void> showTestNotification() async {
    final s = await NotificationSettings.load();
    if (!s.enabled) return;
    await _ensureChannel(s);
    final channelId = await _currentChannelId();
    final androidDetails = AndroidNotificationDetails(
      channelId,
      _channelName,
      channelDescription: _channelDesc,
      icon: 'ic_notification',
      importance:
          s.highImportance ? Importance.high : Importance.defaultImportance,
      priority: s.highImportance ? Priority.high : Priority.defaultPriority,
      playSound: s.sound,
      enableVibration: s.vibrate,
    );
    final details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(
        presentSound: s.sound,
        categoryIdentifier: _iosCategoryId,
      ),
    );
    await _notificationsPlugin.show(
      990001,
      'Проверка уведомлений',
      'Звук, вибрация и всплытие — согласно настройкам приложения',
      details,
    );
  }

  Future<void> debugPendingNotifications() async {
    final List<PendingNotificationRequest> pendingRequests =
        await _notificationsPlugin.pendingNotificationRequests();
    if (kDebugMode) {
      print("--- ЗАПЛАНИРОВАННЫЕ УВЕДОМЛЕНИЯ (${pendingRequests.length}) ---");
      for (var request in pendingRequests) {
        print(
          "ID: ${request.id}, Title: ${request.title}, Body: ${request.body}",
        );
      }
      print("---------------------------------------------------------");
    }
  }
}
