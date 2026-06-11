import 'package:flutter/material.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';

enum RepeatInterval { none, daily, weekly, monthly, custom }

enum RemindBeforeVariant { days, hours, minutes }

extension RemindBeforeVariantX on RemindBeforeVariant {
  String get label {
    switch (this) {
      case RemindBeforeVariant.days:
        return 'дней';
      case RemindBeforeVariant.hours:
        return 'часов';
      case RemindBeforeVariant.minutes:
        return 'минут';
    }
  }

  String declension(int count) {
    switch (this) {
      case RemindBeforeVariant.days:
        return dayDeclension(count);
      case RemindBeforeVariant.hours:
        return hourDeclension(count);
      case RemindBeforeVariant.minutes:
        return minuteDeclension(count);
    }
  }

  Duration duration(int count) {
    switch (this) {
      case RemindBeforeVariant.days:
        return Duration(days: count);
      case RemindBeforeVariant.hours:
        return Duration(hours: count);
      case RemindBeforeVariant.minutes:
        return Duration(minutes: count);
    }
  }
}

/// Источник создания события.
/// Позволяет связать событие с породившим его объектом (препарат, вакцина, заметка)
/// и применить контекстно-корректное поведение (синхронизация статуса, UI).
enum EventSource {
  manual, // создано вручную через EventSheet
  pill, // создано из напоминания о препарате (PillReminder)
  treatment, // создано из прививки / обработки (TreatmentEntry)
  note, // создано из заметки
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
    id: 'ittnghnkjarq0yk',
    name: '',
    description: '',
    colorValue: 0,
    icon: Icons.pets,
  );

  static const health = EventCategory(
    id: 'mhrd94cplxchfn1',
    name: 'Здоровье',
    description: 'Визиты к врачу, прививки',
    colorValue: 0xFFE53935,
    icon: Icons.medical_information,
  );

  static const grooming = EventCategory(
    id: '9r31dxunasavx8m',
    name: 'Груминг',
    description: 'Стрижка, купание',
    colorValue: 0xFF1E88E5,
    icon: Icons.wash,
  );

  static const food = EventCategory(
    id: 'qy647j7m7u2quv8',
    name: 'Питание',
    description: 'Кормление, добавки',
    colorValue: 0xFF43A047,
    icon: Icons.feed,
  );

  static const walk = EventCategory(
    id: 'dk5esfoxqqee3fs',
    name: 'Прогулка',
    description: 'Выгул, активности на улице',
    colorValue: 0xFFFF9800,
    icon: Icons.directions_walk,
  );

  static const training = EventCategory(
    id: 'effz3wiif4a5bvk',
    name: 'Дрессировка',
    description: 'Тренировки, обучение',
    colorValue: 0xFF7B1FA2,
    icon: Icons.school,
  );

  static const vaccination = EventCategory(
    id: '5c3568xphdbr70p',
    name: 'Вакцинация',
    description: 'Прививки, профилактика',
    colorValue: 0xFFD32F2F,
    icon: Icons.vaccines,
  );

  static const other = EventCategory(
    id: '3jb7qj80d412uhz',
    name: 'Другое',
    description: 'Прочие события',
    colorValue: 0xFF607D8B,
    icon: Icons.more_horiz,
  );

  static const all = [
    empty,
    health,
    grooming,
    food,
    walk,
    training,
    vaccination,
    other,
  ];

  static EventCategory byId(String id) {
    return all.firstWhere((c) => c.id == id, orElse: () => other);
  }
}

class Event implements PbEntity {
  static const codec = _EventCodec();

  final String id;
  String name;
  EventCategory category;
  DateTime dateTime;

  bool starred;
  bool remind;

  /// Даты выполнения в формате "yyyy-MM-dd" — отдельно для каждого вхождения
  Set<String> completedDates;

  /// Питомцы, с которыми связано событие
  List<String> petIds;

  /// Связывание с заметками
  String? symptomTag;

  RepeatInterval repeat;
  List<int> customDays; // дни недели для RepeatInterval.custom (1=Пн..7=Вс)

  /// Событие на весь день — время не указывается (хранится 00:00).
  bool allDay;

  RemindBeforeVariant remindBeforeVariant;
  int remindBeforeValue;

  /// Откуда создано событие (вручную, препарат, вакцина, заметка).
  final EventSource source;

  /// ID связанного объекта: для [EventSource.pill] — PillReminder.id,
  /// для [EventSource.treatment] — не используется (link хранится в TreatmentEntry.eventId).
  final String? sourceId;

  Event({
    required this.name,
    required this.category,
    required this.dateTime,
    this.repeat = RepeatInterval.none,
    this.customDays = const [],
    this.allDay = false,
    this.remindBeforeVariant = RemindBeforeVariant.days,
    this.remindBeforeValue = 0,
    this.remind = true,
    List<String>? petIds,
    this.source = EventSource.manual,
    this.sourceId,
  }) : id = generateId(),
       starred = false,
       completedDates = {},
       petIds = petIds ?? [];

  Event.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
    required this.starred,
    required this.completedDates,
    required this.petIds,
    required this.repeat,
    required this.customDays,
    required this.remindBeforeVariant,
    required this.remindBeforeValue,
    this.allDay = false,
    this.remind = true,
    this.source = EventSource.manual,
    this.sourceId,
  });

  Event.fromNote({
    required this.name,
    required this.dateTime,
    this.symptomTag,
  }) : id = generateId(),
       category = EventCategories.empty,
       starred = false,
       completedDates = {},
       petIds = [],
       repeat = RepeatInterval.none,
       customDays = const [],
       allDay = false,
       remindBeforeVariant = RemindBeforeVariant.days,
       remindBeforeValue = 0,
       remind = false,
       source = EventSource.note,
       sourceId = null;

  Event.empty()
    : id = generateId(),
      name = "",
      category = EventCategories.empty,
      dateTime = DateTime.now(),
      starred = false,
      completedDates = {},
      petIds = [],
      repeat = RepeatInterval.none,
      customDays = const [],
      allDay = false,
      remindBeforeVariant = RemindBeforeVariant.days,
      remindBeforeValue = 0,
      remind = true,
      source = EventSource.manual,
      sourceId = null;

  bool get completable => remind && source != EventSource.note;

  String get categoryCaption {
    switch (source) {
      case EventSource.note:
        return 'Заметка';
      case EventSource.pill:
        return 'Приём лекарств';
      case EventSource.treatment:
        return 'Обработка';
      case EventSource.manual:
        return category.name;
    }
  }

  Color get categoryColor {
    final defaultColor = ThemeColors.primary.withAlpha(128);
    switch (source) {
      case EventSource.note:
        {
          if (symptomTag != null) {
            return SymptomTags.byId(symptomTag!)?.color ?? defaultColor;
          }
          return defaultColor;
        }
      case EventSource.pill:
        return category.color;
      case EventSource.treatment:
        return category.color;
      case EventSource.manual:
        return category.color;
    }
  }

  bool get fromNote => source == EventSource.note;
  bool get fromTreatment => source == EventSource.treatment;
  bool get fromPill => source == EventSource.pill;
  bool get manual => source == EventSource.manual;

  /// Форматирует дату как ключ "yyyy-MM-dd"
  static String dateKey(DateTime date) =>
      '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  /// Выполнено ли событие в конкретный день
  bool isCompletedOn(DateTime day) => completedDates.contains(dateKey(day));

  /// Переключает статус выполнения для конкретного дня
  void toggleCompletedOn(DateTime day) {
    final key = dateKey(day);
    if (completedDates.contains(key)) {
      completedDates.remove(key);
    } else {
      completedDates.add(key);
    }
  }

  /// Просрочено: не повторяется, дата в прошлом, не выполнено на эту дату
  bool get isOverdue {
    if (repeat != RepeatInterval.none) return false;
    if (!remind) return false;
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
    RemindBeforeVariant? remindBeforeVariant,
    int? remindBeforeMinutes,
    List<String>? petIds, {
    bool? remind,
    bool? allDay,
  }) {
    this.name = name ?? this.name;
    this.category = category ?? this.category;
    this.dateTime = dateTime ?? this.dateTime;
    if (remind != null) this.remind = remind;
    if (allDay != null) this.allDay = allDay;
    this.repeat = repeat ?? this.repeat;
    this.customDays = customDays ?? this.customDays;
    this.remindBeforeVariant = remindBeforeVariant ?? this.remindBeforeVariant;
    remindBeforeValue = remindBeforeMinutes ?? remindBeforeValue;
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
    'allDay': allDay,
    'remindBeforeVariant': remindBeforeVariant.name,
    'remindBeforeMinutes': remindBeforeValue,
    'remind': remind,
    'source': source.name,
    if (sourceId != null) 'sourceId': sourceId,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'name': name,
    'category': category.id,
    'starred': starred,
    'datetime': dateTime.toIso8601String(),
    'pets': petIds,
    'repeat_interval': repeat.name,
    if (customDays.isNotEmpty) 'repeat_days': customDays,
    'all_day': allDay,
    'remindBeforeVariant': remindBeforeVariant.name,
    'remind_before_minutes': remindBeforeValue,
    'remind': remind,
    'source': source.name,
  };

  factory Event.fromJson(Map<String, dynamic> json) {
    // Поддержка старого формата: completed: bool → completedDates
    Set<String> completedDates = {};
    if (json['completedDates'] != null) {
      completedDates = Set<String>.from(
        (json['completedDates'] as List<dynamic>).map((e) => e as String),
      );
    } else if (json['completed'] == true) {
      final dt = DateTime.parse(json['dateTime'] as String);
      completedDates = {dateKey(dt)};
    }

    final petIds =
        (json['petIds'] as List<dynamic>?)?.map((e) => e as String).toList() ??
        [];

    final source = EventSource.values.firstWhere(
      (s) => s.name == (json['source'] as String?),
      orElse: () => EventSource.manual,
    );

    final remindBeforeVariant = RemindBeforeVariant.values.firstWhere(
      (s) => s.name == (json['remindBeforeVariant'] as String?),
      orElse: () => RemindBeforeVariant.days,
    );

    return Event.deserialize(
      id: json['id'] as String,
      name: json['name'] as String,
      category: EventCategories.byId(json['category'] as String),
      dateTime: DateTime.parse(json['dateTime'] as String),
      starred: json['starred'] as bool? ?? false,
      completedDates: completedDates,
      petIds: petIds,
      repeat: RepeatInterval.values[json['repeat'] as int? ?? 0],
      customDays:
          (json['customDays'] as List<dynamic>?)
              ?.map((e) => e as int)
              .toList() ??
          const [],
      allDay: json['allDay'] as bool? ?? false,
      remindBeforeVariant: remindBeforeVariant,
      remindBeforeValue: json['remindBeforeMinutes'] as int? ?? 0,
      remind: json['remind'] as bool? ?? true,
      source: source,
      sourceId: json['sourceId'] as String?,
    );
  }
}

class _EventCodec extends PbCodec<Event> {
  const _EventCodec();

  @override
  Event fromPocketBase(Map<String, dynamic> data) => Event.deserialize(
    id: data['id'] as String,
    name: data['name'] as String,
    category: EventCategories.byId(data['category'] as String),
    dateTime: DateTime.parse(data['datetime'] as String),
    starred: data['starred'] as bool? ?? false,
    completedDates: const {},
    petIds: (data['pets'] as List<dynamic>?)?.cast<String>() ?? [],
    repeat: RepeatInterval.values.firstWhere(
      (r) => r.name == (data['repeat_interval'] as String?),
      orElse: () => RepeatInterval.none,
    ),
    customDays:
        (data['repeat_days'] as List<dynamic>?)?.cast<int>() ?? const [],
    allDay: data['all_day'] as bool? ?? false,
    remindBeforeVariant: RemindBeforeVariant.values.firstWhere(
          (s) => s.name == (data['remindBeforeVariant'] as String?),
      orElse: () => RemindBeforeVariant.days,
    ),
    remindBeforeValue:
        (data['remind_before_minutes'] as num?)?.toInt() ?? 0,
    remind: data['remind'] as bool? ?? true,
    source: EventSource.values.firstWhere(
      (s) => s.name == (data['source'] as String?),
      orElse: () => EventSource.manual,
    ),
    sourceId: null,
  );
}
