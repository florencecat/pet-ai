import 'package:flutter/material.dart';

enum PillFrequencyType {
  daily,
  weekdays,
}

extension PillFrequencyTypeX on PillFrequencyType {
  String get label {
    switch (this) {
      case PillFrequencyType.daily:
        return 'Ежедневно';
      case PillFrequencyType.weekdays:
        return 'По дням недели';
    }
  }

  IconData get icon {
    switch (this) {
      case PillFrequencyType.daily:
        return Icons.repeat;
      case PillFrequencyType.weekdays:
        return Icons.calendar_view_week;
    }
  }
}

const _weekdayShort = {
  1: 'Пн', 2: 'Вт', 3: 'Ср', 4: 'Чт', 5: 'Пт', 6: 'Сб', 7: 'Вс',
};

class PillReminder {
  final String id;
  final String name;
  final String dose;             // e.g., "1 таблетка", "5 мл"
  final PillFrequencyType frequencyType;
  final List<int> weekdays;      // 1=Пн..7=Вс; only for frequencyType.weekdays
  final int hour;
  final int minute;
  final DateTime startDate;
  final DateTime? endDate;
  final List<String> takenDates; // "yyyy-MM-dd" when each dose was taken
  final String? eventId;        // linked PetEvent for notifications

  const PillReminder({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequencyType,
    required this.weekdays,
    required this.hour,
    required this.minute,
    required this.startDate,
    this.endDate,
    required this.takenDates,
    this.eventId,
  });

  bool get isActive {
    if (endDate == null) return true;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
    return !end.isBefore(today);
  }

  bool isScheduledForDay(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (d.isBefore(start)) return false;
    if (endDate != null) {
      final end = DateTime(endDate!.year, endDate!.month, endDate!.day);
      if (d.isAfter(end)) return false;
    }
    switch (frequencyType) {
      case PillFrequencyType.daily:
        return true;
      case PillFrequencyType.weekdays:
        return weekdays.contains(d.weekday);
    }
  }

  bool isTakenOnDay(DateTime day) => takenDates.contains(dateKey(day));

  DateTime? nextScheduledDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 1; i <= 365; i++) {
      final candidate = today.add(Duration(days: i));
      if (isScheduledForDay(candidate)) return candidate;
    }
    return null;
  }

  String get timeLabel =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  String get frequencyLabel {
    switch (frequencyType) {
      case PillFrequencyType.daily:
        return 'Ежедневно';
      case PillFrequencyType.weekdays:
        if (weekdays.isEmpty) return 'По дням недели';
        final sorted = List.of(weekdays)..sort();
        return sorted.map((d) => _weekdayShort[d] ?? '').join(', ');
    }
  }

  PillReminder copyWith({
    List<String>? takenDates,
    String? eventId,
  }) => PillReminder(
    id: id,
    name: name,
    dose: dose,
    frequencyType: frequencyType,
    weekdays: weekdays,
    hour: hour,
    minute: minute,
    startDate: startDate,
    endDate: endDate,
    takenDates: takenDates ?? this.takenDates,
    eventId: eventId ?? this.eventId,
  );

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  factory PillReminder.fromJson(Map<String, dynamic> json) => PillReminder(
    id: json['id'] as String,
    name: json['name'] as String,
    dose: json['dose'] as String? ?? '',
    frequencyType: PillFrequencyType.values.firstWhere(
      (f) => f.name == json['frequencyType'],
      orElse: () => PillFrequencyType.daily,
    ),
    weekdays: (json['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
    hour: json['hour'] as int? ?? 9,
    minute: json['minute'] as int? ?? 0,
    startDate: DateTime.parse(json['startDate'] as String),
    endDate: json['endDate'] != null
        ? DateTime.parse(json['endDate'] as String)
        : null,
    takenDates: (json['takenDates'] as List<dynamic>?)?.cast<String>() ?? [],
    eventId: json['eventId'] as String?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'frequencyType': frequencyType.name,
    'weekdays': weekdays,
    'hour': hour,
    'minute': minute,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'takenDates': takenDates,
    'eventId': eventId,
  };
}