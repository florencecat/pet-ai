import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'event_service.dart' as events;
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    tz.initializeTimeZones();
    final String timeZoneName = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
        );

    await _notificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: _onNotificationResponse,
    );

    await _requestPermissions();
  }

  /// Callback при нажатии на уведомление или действие в нём.
  /// actionId 'complete' — пометить событие выполненным.
  static void _onNotificationResponse(NotificationResponse details) {
    // actionId приходит когда пользователь нажал на кнопку действия
    if (details.actionId == 'complete') {
      // Сохраняем payload, чтобы приложение обработало при открытии
      _pendingCompleteEventId = details.payload;
    }
  }

  /// ID события, которое нужно отметить как выполненное (из push-действия).
  static String? _pendingCompleteEventId;

  /// Забрать и очистить pending event id (вызывается при старте/resume приложения).
  static String? consumePendingCompleteEventId() {
    final id = _pendingCompleteEventId;
    _pendingCompleteEventId = null;
    return id;
  }

  Future<void> _requestPermissions() async {
    if (Platform.isAndroid) {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await androidPlugin?.requestNotificationsPermission();
      await androidPlugin?.requestExactAlarmsPermission();
    } else if (Platform.isIOS) {
      await _notificationsPlugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    }
  }

  Future<void> scheduleEventNotification(events.PetEvent event) async {
    final id = event.id.hashCode;

    // Вычисляем время напоминания (с учетом отсрочки)
    final scheduledTime = event.dateTime.subtract(
      Duration(minutes: event.remindBeforeMinutes),
    );

    if (scheduledTime.isBefore(DateTime.now()) &&
        event.repeat == events.RepeatInterval.none) {
      return; // Пропускаем, если время уже прошло и повторов нет
    }

    // Преобразуем интервал в формат библиотеки
    DateTimeComponents? matchComponents;
    if (event.repeat == events.RepeatInterval.daily) {
      matchComponents = DateTimeComponents.time;
    } else if (event.repeat == events.RepeatInterval.weekly ||
               event.repeat == events.RepeatInterval.custom) {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (event.repeat == events.RepeatInterval.monthly) {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    const androidDetails = AndroidNotificationDetails(
      'pet_events_channel',
      'Напоминания',
      importance: Importance.max,
      priority: Priority.high,
      actions: [
        AndroidNotificationAction('complete', 'Выполнено ✓',
          cancelNotification: true),
        AndroidNotificationAction('dismiss', 'Отложить'),
      ],
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    final body = event.remindBeforeMinutes > 0
        ? "${event.name} (через ${event.remindBeforeMinutes} мин)"
        : event.name;

    if (event.repeat == events.RepeatInterval.custom &&
        event.customDays.isNotEmpty) {
      // Для custom — планируем уведомление на каждый выбранный день недели
      for (int i = 0; i < event.customDays.length; i++) {
        final dayOfWeek = event.customDays[i];
        final nextOccurrence = _nextWeekday(scheduledTime, dayOfWeek);
        await _notificationsPlugin.zonedSchedule(
          id + i,
          event.category.name,
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
        event.category.name,
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
    // Также отменяем возможные custom-day уведомления (id+0..id+6)
    for (int i = 1; i < 7; i++) {
      await _notificationsPlugin.cancel(id + i);
    }
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
