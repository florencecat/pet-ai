import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';
import 'pet_profile_service.dart';
import '../models/pill_reminder.dart';

enum RepeatInterval { none, daily, weekly, monthly, custom }

/// Источник создания события.
/// Позволяет связать событие с породившим его объектом (препарат, вакцина, заметка)
/// и применить контекстно-корректное поведение (синхронизация статуса, UI).
enum EventSource {
  manual,    // создано вручную через EventSheet
  pill,      // создано из напоминания о препарате (PillReminder)
  treatment, // создано из прививки / обработки (TreatmentEntry)
  note,      // создано из заметки
}

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
  /// Даты выполнения в формате "yyyy-MM-dd" — отдельно для каждого вхождения
  Set<String> completedDates;
  /// Питомцы, с которыми связано событие
  List<String> petIds;
  /// Связывание с заметками
  String? symptomTag;

  RepeatInterval repeat;
  List<int> customDays; // дни недели для RepeatInterval.custom (1=Пн..7=Вс)
  int remindBeforeMinutes;
  /// When false, no push notifications are scheduled for this event.
  bool notify;

  /// Откуда создано событие (вручную, препарат, вакцина, заметка).
  final EventSource source;

  /// ID связанного объекта: для [EventSource.pill] — PillReminder.id,
  /// для [EventSource.treatment] — не используется (link хранится в TreatmentEntry.eventId).
  final String? sourceId;

  PetEvent({
    required this.name,
    required this.category,
    required this.dateTime,
    this.repeat = RepeatInterval.none,
    this.customDays = const [],
    this.remindBeforeMinutes = 0,
    this.notify = true,
    List<String>? petIds,
    this.source = EventSource.manual,
    this.sourceId,
  }) : id = UniqueKey().toString(),
        starred = false,
        completedDates = {},
        petIds = petIds ?? [];

  PetEvent.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
    required this.starred,
    required this.completedDates,
    required this.petIds,
    required this.repeat,
    required this.customDays,
    required this.remindBeforeMinutes,
    this.notify = true,
    this.source = EventSource.manual,
    this.sourceId,
  });

  PetEvent.fromNote({required this.name, required this.dateTime, this.symptomTag})
      : id = UniqueKey().toString(),
        category = EventCategories.empty,
        starred = false,
        completedDates = {},
        petIds = [],
        repeat = RepeatInterval.none,
        customDays = const [],
        remindBeforeMinutes = 0,
        notify = false,
        source = EventSource.note,
        sourceId = null;

  PetEvent.empty()
      : id = UniqueKey().toString(),
        name = "",
        category = EventCategories.empty,
        dateTime = DateTime.now(),
        starred = false,
        completedDates = {},
        petIds = [],
        repeat = RepeatInterval.none,
        customDays = const [],
        remindBeforeMinutes = 0,
        notify = true,
        source = EventSource.manual,
        sourceId = null;

  bool get completable => source != EventSource.note;

  String get categoryCaption {
    switch(source) {
      case EventSource.note: return 'Заметка';
      case EventSource.pill: return 'Приём лекарств';
      case EventSource.treatment: return 'Обработка';
      case EventSource.manual: return category.name;
    }
  }

  Color get categoryColor {
    final defaultColor = ThemeColors.primary.withAlpha(128);
    switch(source) {
      case EventSource.note:
        {
          if (symptomTag != null) {
            return SymptomTags.byId(symptomTag!)?.color ?? defaultColor;
          }
          return defaultColor;
        }
      case EventSource.pill: return category.color;
      case EventSource.treatment: return category.color;
      case EventSource.manual: return category.color;
    }
  }

  /// Форматирует дату как ключ "yyyy-MM-dd"
  static String _dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Выполнено ли событие в конкретный день
  bool isCompletedOn(DateTime day) => completedDates.contains(_dateKey(day));

  /// Переключает статус выполнения для конкретного дня
  void toggleCompletedOn(DateTime day) {
    final key = _dateKey(day);
    if (completedDates.contains(key)) {
      completedDates.remove(key);
    } else {
      completedDates.add(key);
    }
  }

  /// Просрочено: не повторяется, дата в прошлом, не выполнено на эту дату
  bool get isOverdue {
    if (repeat != RepeatInterval.none) return false;
    final eventDay = DateTime(dateTime.year, dateTime.month, dateTime.day);
    final today = DateTime.now();
    final todayDay = DateTime(today.year, today.month, today.day);
    return eventDay.isBefore(todayDay) && !isCompletedOn(dateTime);
  }

  void assign(
      String? name,
      EventCategory? category,
      DateTime? dateTime,
      RepeatInterval? repeat,
      List<int>? customDays,
      int? remindBeforeMinutes,
      List<String>? petIds, {
      bool? notify,
      }) {
    this.name = name ?? this.name;
    this.category = category ?? this.category;
    this.dateTime = dateTime ?? this.dateTime;
    if (notify != null) this.notify = notify;
    this.repeat = repeat ?? this.repeat;
    this.customDays = customDays ?? this.customDays;
    this.remindBeforeMinutes = remindBeforeMinutes ?? this.remindBeforeMinutes;
    if (petIds != null) this.petIds = petIds;
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
    'completedDates': completedDates.toList(),
    'petIds': petIds,
    'repeat': repeat.index,
    'customDays': customDays,
    'remindBeforeMinutes': remindBeforeMinutes,
    'notify': notify,
    'source': source.name,
    if (sourceId != null) 'sourceId': sourceId,
  };

  factory PetEvent.fromJson(Map<String, dynamic> json) {
    // Поддержка старого формата: completed: bool → completedDates
    Set<String> completedDates = {};
    if (json['completedDates'] != null) {
      completedDates = Set<String>.from(
        (json['completedDates'] as List<dynamic>).map((e) => e as String),
      );
    } else if (json['completed'] == true) {
      final dt = DateTime.parse(json['dateTime'] as String);
      completedDates = {_dateKey(dt)};
    }

    final petIds = (json['petIds'] as List<dynamic>?)
        ?.map((e) => e as String)
        .toList() ?? [];

    final source = EventSource.values.firstWhere(
      (s) => s.name == (json['source'] as String?),
      orElse: () => EventSource.manual,
    );

    return PetEvent.deserialize(
      id: json['id'] as String,
      name: json['name'] as String,
      category: EventCategories.byId(json['category'] as String),
      dateTime: DateTime.parse(json['dateTime'] as String),
      starred: json['starred'] as bool? ?? false,
      completedDates: completedDates,
      petIds: petIds,
      repeat: RepeatInterval.values[json['repeat'] as int? ?? 0],
      customDays: (json['customDays'] as List<dynamic>?)
          ?.map((e) => e as int).toList() ?? const [],
      remindBeforeMinutes: json['remindBeforeMinutes'] as int? ?? 0,
      notify: json['notify'] as bool? ?? true,
      source: source,
      sourceId: json['sourceId'] as String?,
    );
  }
}

class EventService {
  // Глобальное хранилище всех событий (v2)
  static const _globalKey = 'pet_events_v2';
  static const _migrationDoneKey = 'pet_events_v2_migrated';

  // ─── Внутренние ───────────────────────────────────────────────────────────

  Future<List<PetEvent>> _loadAll() async {
    final data =
        await SharedPreferencesAsync().getStringList(_globalKey) ?? [];
    return data.map((e) => PetEvent.fromJson(jsonDecode(e))).toList();
  }

  Future<void> _persistAll(List<PetEvent> events) async {
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_globalKey, encoded);
  }

  // ─── Чтение ──────────────────────────────────────────────────────────────

  /// Все события конкретного питомца
  Future<List<PetEvent>> loadEvents(String petId) async {
    final all = await _loadAll();
    return all.where((e) => e.petIds.contains(petId)).toList();
  }

  /// Все события нескольких питомцев, дедуплицированные по ID события
  Future<List<PetEvent>> loadEventsForPets(List<String> petIds) async {
    final all = await _loadAll();
    final seen = <String>{};
    return all.where((e) {
      if (e.petIds.any((id) => petIds.contains(id))) {
        return seen.add(e.id);
      }
      return false;
    }).toList();
  }

  /// Возвращает события всех питомцев, сгруппированные по petId
  Future<Map<String, List<PetEvent>>> loadAllEvents(
      List<String> petIds,
      ) async {
    final all = await _loadAll();
    final result = <String, List<PetEvent>>{};
    for (final id in petIds) {
      result[id] = all.where((e) => e.petIds.contains(id)).toList();
    }
    return result;
  }

  // ─── Запись ───────────────────────────────────────────────────────────────

  Future<void> createEvent(PetEvent event) async {
    final all = await _loadAll();
    all.add(event);
    await _persistAll(all);

    if (event.notify && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await NotificationService().ensurePermission();
        await NotificationService().scheduleEventNotification(event);
      } catch (_) {
        // Silently ignore notification failures (e.g. permission denied).
      }
    }
  }

  Future<void> saveEvent(PetEvent event) async {
    final all = await _loadAll();
    final index = all.indexWhere((e) => e.id == event.id);
    if (index < 0) return;

    all[index] = event;
    await _persistAll(all);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await NotificationService().cancelNotification(event.id);
      await NotificationService().scheduleEventNotification(event);
    }
  }

  /// Переключает выполнение события для конкретного дня.
  /// Если событие связано с препаратом ([EventSource.pill]), синхронизирует
  /// статус с [PillReminder.takenDates] — чтобы отметка в календаре
  /// отражалась и на странице Здоровья, и наоборот.
  Future<void> toggleCompleted(
      String petId, PetEvent event, DateTime day) async {
    event.toggleCompletedOn(day);
    await saveEvent(event);

    if (event.source == EventSource.pill && event.sourceId != null) {
      await _syncToPillReminder(
        petId: petId,
        reminderId: event.sourceId!,
        day: day,
        completed: event.isCompletedOn(day),
      );
    }
  }

  /// Устанавливает статус выполнения события напрямую по ID (без переключения).
  /// Вызывается из [PillReminderService] при отметке препарата принятым,
  /// чтобы синхронизировать событие в календаре.
  Future<void> setCompletedOn(
      String eventId, DateTime day, bool completed) async {
    final all = await _loadAll();
    final idx = all.indexWhere((e) => e.id == eventId);
    if (idx < 0) return;
    final key = PetEvent._dateKey(day);
    if (completed) {
      all[idx].completedDates.add(key);
    } else {
      all[idx].completedDates.remove(key);
    }
    await _persistAll(all);
  }

  /// Синхронизирует статус выполнения в [PillReminder.takenDates]
  /// при переключении события из календаря / листа событий.
  Future<void> _syncToPillReminder({
    required String petId,
    required String reminderId,
    required DateTime day,
    required bool completed,
  }) async {
    final profile = await ProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;
    final old = profile.pillReminders[idx];
    final key = PillReminder.dateKey(day);
    final dates = List<String>.from(old.takenDates);
    if (completed && !dates.contains(key)) {
      dates.add(key);
    } else if (!completed) {
      dates.remove(key);
    } else {
      return; // already in sync
    }
    profile.pillReminders[idx] = old.copyWith(takenDates: dates);
    await ProfileService().saveProfile(profile);
  }

  /// Все события, которые приходятся на конкретный день (включая повторяющиеся)
  Future<List<PetEvent>> eventsForDay(String petId, DateTime day) async {
    final events = await loadEvents(petId);
    return events.where((e) => e.occursOn(day)).toList();
  }

  Future<void> deleteEvent(PetEvent event) async {
    final all = await _loadAll();
    all.removeWhere((e) => e.id == event.id);
    await _persistAll(all);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await NotificationService().cancelNotification(event.id);
    }
  }

  // ─── Очистка ──────────────────────────────────────────────────────────────

  /// Удаляет связь питомца со всеми событиями; события без питомцев удаляются
  Future<void> clearEvents(String petId) async {
    final all = await _loadAll();
    final updated = <PetEvent>[];
    for (final e in all) {
      if (e.petIds.contains(petId)) {
        e.petIds.remove(petId);
        if (e.petIds.isEmpty) {
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            await NotificationService().cancelNotification(e.id);
          }
          continue; // удаляем осиротевшее событие
        }
      }
      updated.add(e);
    }
    await _persistAll(updated);
  }

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

  // ─── Миграция ─────────────────────────────────────────────────────────────

  /// Переносит события из старых per-pet ключей в глобальное хранилище v2.
  /// Безопасно вызывать несколько раз — повторная миграция игнорируется.
  Future<void> migrateFromLegacy(List<String> petIds) async {
    final prefs = SharedPreferencesAsync();
    final alreadyDone = await prefs.getBool(_migrationDoneKey) ?? false;
    if (alreadyDone) return;

    final allEvents = <PetEvent>[];
    for (final petId in petIds) {
      final legacyData = await prefs.getStringList('pet_events:$petId');
      if (legacyData == null) continue;

      for (final item in legacyData) {
        try {
          final json = jsonDecode(item) as Map<String, dynamic>;
          // Инжектируем petId если его нет
          if (json['petIds'] == null || (json['petIds'] as List).isEmpty) {
            json['petIds'] = [petId];
          }
          final event = PetEvent.fromJson(json);
          if (!allEvents.any((e) => e.id == event.id)) {
            allEvents.add(event);
          }
        } catch (_) {}
      }
      await prefs.remove('pet_events:$petId');
    }

    await _persistAll(allEvents);
    await prefs.setBool(_migrationDoneKey, true);
  }
}
