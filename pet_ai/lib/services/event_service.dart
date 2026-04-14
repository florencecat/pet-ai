import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

enum RepeatInterval { none, daily, weekly, monthly, custom }

/// Дни недели для custom-повторений (1=Пн, 7=Вс)
class WeekDays {
  static const int monday = 1;
  static const int tuesday = 2;
  static const int wednesday = 3;
  static const int thursday = 4;
  static const int friday = 5;
  static const int saturday = 6;
  static const int sunday = 7;

  static const labels = {
    monday: 'Пн',
    tuesday: 'Вт',
    wednesday: 'Ср',
    thursday: 'Чт',
    friday: 'Пт',
    saturday: 'Сб',
    sunday: 'Вс',
  };
}

class EventCategory {
  final String id;
  final String name;
  final String description;
  final int colorValue;
  final IconData icon;

  const EventCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.colorValue,
    required this.icon,
  });

  Color get color => Color(colorValue);
}

class EventCategories {
  static const empty = EventCategory(
    id: 'empty',
    name: '',
    description: '',
    colorValue: 0,
    icon: Icons.pets,
  );

  static const health = EventCategory(
    id: 'health',
    name: 'Здоровье',
    description: 'Визиты к врачу, прививки',
    colorValue: 0xFFE53935,
    icon: Icons.medical_information,
  );

  static const grooming = EventCategory(
    id: 'grooming',
    name: 'Груминг',
    description: 'Стрижка, купание',
    colorValue: 0xFF1E88E5,
    icon: Icons.wash,
  );

  static const food = EventCategory(
    id: 'food',
    name: 'Питание',
    description: 'Кормление, добавки',
    colorValue: 0xFF43A047,
    icon: Icons.feed,
  );

  static const walk = EventCategory(
    id: 'walk',
    name: 'Прогулка',
    description: 'Выгул, активности на улице',
    colorValue: 0xFFFF9800,
    icon: Icons.directions_walk,
  );

  static const training = EventCategory(
    id: 'training',
    name: 'Дрессировка',
    description: 'Тренировки, обучение',
    colorValue: 0xFF7B1FA2,
    icon: Icons.school,
  );

  static const vaccination = EventCategory(
    id: 'vaccination',
    name: 'Вакцинация',
    description: 'Прививки, профилактика',
    colorValue: 0xFFD32F2F,
    icon: Icons.vaccines,
  );

  static const other = EventCategory(
    id: 'other',
    name: 'Другое',
    description: 'Прочие события',
    colorValue: 0xFF607D8B,
    icon: Icons.more_horiz,
  );

  static const all = [empty, health, grooming, food, walk, training, vaccination, other];

  static EventCategory byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => other);
  }
}

class PetEvent {
  final String id;
  String name;
  EventCategory category;
  DateTime dateTime;
  bool starred;
  bool completed;
  RepeatInterval repeat;
  List<int> customDays; // дни недели для RepeatInterval.custom (1=Пн..7=Вс)
  int remindBeforeMinutes;

  PetEvent({
    required this.name,
    required this.category,
    required this.dateTime,
    this.repeat = RepeatInterval.none,
    this.customDays = const [],
    this.remindBeforeMinutes = 0,
  }) : id = UniqueKey().toString(),
        starred = false,
        completed = false;

  PetEvent.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
    required this.starred,
    required this.completed,
    required this.repeat,
    required this.customDays,
    required this.remindBeforeMinutes,
  });

  PetEvent.empty()
      : id = UniqueKey().toString(),
        name = "",
        category = EventCategories.empty,
        dateTime = DateTime.now(),
        starred = false,
        completed = false,
        repeat = RepeatInterval.none,
        customDays = const [],
        remindBeforeMinutes = 0;

  void assign(
      String? name,
      EventCategory? category,
      DateTime? dateTime,
      RepeatInterval? repeat,
      List<int>? customDays,
      int? remindBeforeMinutes,
      ) {
    this.name = name ?? this.name;
    this.category = category ?? this.category;
    this.dateTime = dateTime ?? this.dateTime;
    this.repeat = repeat ?? this.repeat;
    this.customDays = customDays ?? this.customDays;
    this.remindBeforeMinutes = remindBeforeMinutes ?? this.remindBeforeMinutes;
  }

  /// Проверяет, приходится ли повторяющееся событие на заданный день.
  bool occursOn(DateTime day) {
    final base = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final target = DateTime(day.year, day.month, day.day);

    if (base == target) return true;
    if (target.isBefore(base)) return false;

    switch (repeat) {
      case RepeatInterval.none:
        return false;
      case RepeatInterval.daily:
        return true;
      case RepeatInterval.weekly:
        return base.weekday == target.weekday;
      case RepeatInterval.monthly:
        return base.day == target.day;
      case RepeatInterval.custom:
        return customDays.contains(target.weekday);
    }
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.id,
    'dateTime': dateTime.toIso8601String(),
    'starred': starred,
    'completed': completed,
    'repeat': repeat.index,
    'customDays': customDays,
    'remindBeforeMinutes': remindBeforeMinutes,
  };

  factory PetEvent.fromJson(Map<String, dynamic> json) => PetEvent.deserialize(
    id: json['id'],
    name: json['name'],
    category: EventCategories.byId(json['category']),
    dateTime: DateTime.parse(json['dateTime']),
    starred: json['starred'] ?? false,
    completed: json['completed'] ?? false,
    repeat: RepeatInterval.values[json['repeat'] ?? 0],
    customDays: (json['customDays'] as List<dynamic>?)
        ?.map((e) => e as int).toList() ?? const [],
    remindBeforeMinutes: json['remindBeforeMinutes'] ?? 0,
  );
}

class EventService {
  // Ключ изолирован по petId: "pet_events:<petId>"
  static String _eventsKey(String petId) => 'pet_events:$petId';

  // ─── Чтение ──────────────────────────────────────────────────────────────

  Future<List<PetEvent>> loadEvents(String petId) async {
    final data =
        await SharedPreferencesAsync().getStringList(_eventsKey(petId)) ?? [];
    return data.map((e) => PetEvent.fromJson(jsonDecode(e))).toList();
  }

  /// Возвращает события всех питомцев, сгруппированные по petId.
  /// Удобно для агрегированного календаря.
  Future<Map<String, List<PetEvent>>> loadAllEvents(
      List<String> petIds,
      ) async {
    final result = <String, List<PetEvent>>{};
    for (final id in petIds) {
      result[id] = await loadEvents(id);
    }
    return result;
  }

  // ─── Запись ───────────────────────────────────────────────────────────────

  Future<void> _persistEvents(String petId, List<PetEvent> events) async {
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_eventsKey(petId), encoded);
  }

  Future<void> createEvent(String petId, PetEvent event) async {
    final events = await loadEvents(petId);
    events.add(event);
    await _persistEvents(petId, events);

    if (!Platform.isWindows) {
      await NotificationService().scheduleEventNotification(event);
    }
  }

  Future<void> saveEvent(String petId, PetEvent event) async {
    final events = await loadEvents(petId);
    final index = events.indexWhere((e) => e.id == event.id);
    if (index < 0) return;

    events[index] = event;
    await _persistEvents(petId, events);

    if (!Platform.isWindows) {
      await NotificationService().cancelNotification(event.id);
      await NotificationService().scheduleEventNotification(event);
    }
  }

  Future<void> toggleCompleted(String petId, PetEvent event) async {
    event.completed = !event.completed;
    await saveEvent(petId, event);
  }

  /// Все события, которые приходятся на конкретный день (включая повторяющиеся).
  Future<List<PetEvent>> eventsForDay(String petId, DateTime day) async {
    final events = await loadEvents(petId);
    return events.where((e) => e.occursOn(day)).toList();
  }

  Future<void> deleteEvent(String petId, PetEvent event) async {
    final events = await loadEvents(petId);
    events.removeWhere((e) => e.id == event.id);
    await _persistEvents(petId, events);

    if (!Platform.isWindows) {
      await NotificationService().cancelNotification(event.id);
    }
  }

  // ─── Очистка ──────────────────────────────────────────────────────────────

  /// Удаляет все события конкретного питомца (например, при удалении профиля).
  Future<void> clearEvents(String petId) async {
    final events = await loadEvents(petId);
    if (!Platform.isWindows) {
      for (final event in events) {
        await NotificationService().cancelNotification(event.id);
      }
    }
    await SharedPreferencesAsync().remove(_eventsKey(petId));
  }

  /// Удаляет события сразу нескольких питомцев. Вызывай при массовой очистке
  /// или удалении нескольких профилей за раз.
  Future<void> clearEventsForAll(List<String> petIds) async {
    for (final id in petIds) {
      await clearEvents(id);
    }
  }

  // ─── Фильтрация ───────────────────────────────────────────────────────────

  /// Ближайшие события питомца, начиная с [from] (по умолчанию — сейчас).
  Future<List<PetEvent>> upcomingEvents(
      String petId, {
        DateTime? from,
        int limit = 10,
      }) async {
    final now = from ?? DateTime.now();
    final events = await loadEvents(petId);
    final sorted = events
        .where((e) => e.dateTime.isAfter(now))
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return sorted.take(limit).toList();
  }

  /// Starred-события питомца, отсортированные по дате.
  Future<List<PetEvent>> starredEvents(String petId) async {
    final events = await loadEvents(petId);
    return events.where((e) => e.starred).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  /// События питомца по категории.
  Future<List<PetEvent>> eventsByCategory(
      String petId,
      EventCategory category,
      ) async {
    final events = await loadEvents(petId);
    return events
        .where((e) => e.category.id == category.id)
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }
}

