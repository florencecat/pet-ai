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
      onDidReceiveNotificationResponse: (details) {
        // Обработка нажатия на уведомление
      },
    );

    await _requestPermissions();
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
    } else if (event.repeat == events.RepeatInterval.weekly) {
      matchComponents = DateTimeComponents.dayOfWeekAndTime;
    } else if (event.repeat == events.RepeatInterval.monthly) {
      matchComponents = DateTimeComponents.dayOfMonthAndTime;
    }

    await _notificationsPlugin.zonedSchedule(
      id,
      event.category.name,
      event.remindBeforeMinutes > 0
          ? "${event.name} (через ${event.remindBeforeMinutes} мин)"
          : event.name,
      tz.TZDateTime.from(scheduledTime, tz.local),
      const NotificationDetails(
        android: AndroidNotificationDetails(
          'pet_events_channel',
          'Напоминания',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: matchComponents,
    );
  }

  Future<void> cancelNotification(String eventId) async {
    await _notificationsPlugin.cancel(eventId.hashCode);
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
