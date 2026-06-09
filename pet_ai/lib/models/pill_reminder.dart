import 'package:flutter/material.dart';
import 'package:pet_satellite/services/pb_service.dart';

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

// ─── Single intake time ───────────────────────────────────────────────────────

class PillSchedule {
  final int hour;
  final int minute;

  const PillSchedule({required this.hour, required this.minute});

  String get label =>
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';

  TimeOfDay toTimeOfDay() => TimeOfDay(hour: hour, minute: minute);

  factory PillSchedule.fromTimeOfDay(TimeOfDay t) =>
      PillSchedule(hour: t.hour, minute: t.minute);

  Map<String, dynamic> toJson() => {'hour': hour, 'minute': minute};

  factory PillSchedule.fromJson(Map<String, dynamic> json) => PillSchedule(
    hour: json['hour'] as int,
    minute: json['minute'] as int,
  );

  @override
  bool operator ==(Object other) =>
      other is PillSchedule && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

// ─── PillReminder ─────────────────────────────────────────────────────────────

class PillReminder implements PbEntity {
  static const codec = _PillReminderCodec();

  final String id;
  final String name;
  final String dose;             // e.g., "1 таблетка", "5 мл"
  final PillFrequencyType frequencyType;
  final List<int> weekdays;      // 1=Пн..7=Вс; only for frequencyType.weekdays
  /// Ordered list of daily intake times. At least one entry is always present.
  final List<PillSchedule> schedules;
  final DateTime startDate;
  final DateTime? endDate;
  /// Legacy per-day taken flag (kept for backward compat reading old saves).
  final List<String> takenDates;
  /// Per-schedule taken state: dateKey → list of schedule indices that were taken.
  final Map<String, List<int>> takenSchedules;
  final String? eventId;        // linked PetEvent for notifications

  const PillReminder({
    required this.id,
    required this.name,
    required this.dose,
    required this.frequencyType,
    required this.weekdays,
    required this.schedules,
    required this.startDate,
    this.endDate,
    required this.takenDates,
    this.takenSchedules = const {},
    this.eventId,
  });

  // ── Backward-compat accessors ─────────────────────────────────────────────

  int get hour => schedules.isNotEmpty ? schedules.first.hour : 9;
  int get minute => schedules.isNotEmpty ? schedules.first.minute : 0;

  // ── Computed properties ───────────────────────────────────────────────────

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

  /// Returns true when every schedule for [day] is marked as taken.
  bool isTakenOnDay(DateTime day) {
    final key = dateKey(day);
    if (takenSchedules.containsKey(key)) {
      return (takenSchedules[key]?.length ?? 0) >= schedules.length;
    }
    // Backward compat: fall back to legacy per-day flag.
    return takenDates.contains(key);
  }

  /// Whether a specific schedule [scheduleIndex] is marked as taken on [day].
  bool isScheduleTakenOnDay(DateTime day, int scheduleIndex) {
    final key = dateKey(day);
    return takenSchedules[key]?.contains(scheduleIndex) ?? false;
  }

  /// Number of individual schedules marked as taken on [day].
  int countTakenOnDay(DateTime day) {
    final key = dateKey(day);
    if (takenSchedules.containsKey(key)) {
      return takenSchedules[key]?.length ?? 0;
    }
    // Backward compat: if legacy flag set, treat all schedules as taken.
    return takenDates.contains(key) ? schedules.length : 0;
  }

  DateTime? nextScheduledDate() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    for (var i = 1; i <= 365; i++) {
      final candidate = today.add(Duration(days: i));
      if (isScheduledForDay(candidate)) return candidate;
    }
    return null;
  }

  /// Human-readable label for all scheduled times.
  String get timeLabel => schedules.map((s) => s.label).join(' · ');

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

  // ── copyWith ──────────────────────────────────────────────────────────────

  PillReminder copyWith({
    String? name,
    String? dose,
    PillFrequencyType? frequencyType,
    List<int>? weekdays,
    List<PillSchedule>? schedules,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    List<String>? takenDates,
    Map<String, List<int>>? takenSchedules,
    String? eventId,
  }) => PillReminder(
    id: id,
    name: name ?? this.name,
    dose: dose ?? this.dose,
    frequencyType: frequencyType ?? this.frequencyType,
    weekdays: weekdays ?? this.weekdays,
    schedules: schedules ?? this.schedules,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    takenDates: takenDates ?? this.takenDates,
    takenSchedules: takenSchedules ?? this.takenSchedules,
    eventId: eventId ?? this.eventId,
  );

  // ── Serialization ─────────────────────────────────────────────────────────

  static String dateKey(DateTime day) =>
      '${day.year.toString().padLeft(4, '0')}-'
      '${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';

  factory PillReminder.fromJson(Map<String, dynamic> json) {
    // Backward compat: if new 'schedules' key is absent, read old hour/minute
    final List<PillSchedule> schedules;
    if (json['schedules'] != null) {
      schedules = (json['schedules'] as List<dynamic>)
          .map((s) => PillSchedule.fromJson(s as Map<String, dynamic>))
          .toList();
    } else {
      schedules = [
        PillSchedule(
          hour: json['hour'] as int? ?? 9,
          minute: json['minute'] as int? ?? 0,
        ),
      ];
    }

    return PillReminder(
      id: json['id'] as String,
      name: json['name'] as String,
      dose: json['dose'] as String? ?? '',
      frequencyType: PillFrequencyType.values.firstWhere(
        (f) => f.name == json['frequencyType'],
        orElse: () => PillFrequencyType.daily,
      ),
      weekdays: (json['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
      schedules: schedules,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      takenDates: (json['takenDates'] as List<dynamic>?)?.cast<String>() ?? [],
      takenSchedules: _parseTakenSchedules(json['takenSchedules']),
      eventId: json['eventId'] as String?,
    );
  }

  static Map<String, List<int>> _parseTakenSchedules(dynamic raw) {
    if (raw == null) return {};
    final map = raw as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()));
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'dose': dose,
    'frequencyType': frequencyType.name,
    'weekdays': weekdays,
    'schedules': schedules.map((s) => s.toJson()).toList(),
    // Also write legacy fields so old app versions can still read them
    'hour': hour,
    'minute': minute,
    'startDate': startDate.toIso8601String(),
    'endDate': endDate?.toIso8601String(),
    'takenDates': takenDates,
    'takenSchedules': takenSchedules,
    'eventId': eventId,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    "id": id,
    "name": name,
    "pet": ownerId,
    "dose": dose,
    "frequency": frequencyType.name,
    "weekdays": weekdays.map((w) => w.toString()).join(', '),
    "start": startDate.toIso8601String(),
    "end": endDate?.toIso8601String()
  };
}

class _PillReminderCodec extends PbCodec<PillReminder> {
  const _PillReminderCodec();

  @override
  PillReminder fromPocketBase(Map<String, dynamic> data) {
    final weekdayStr = data['weekdays'] as String? ?? '';
    final weekdays = weekdayStr.isEmpty
        ? <int>[]
        : weekdayStr
            .split(',')
            .map((s) => int.tryParse(s.trim()))
            .whereType<int>()
            .toList();

    return PillReminder(
      id: data['id'] as String,
      name: data['name'] as String,
      dose: data['dose'] as String? ?? '',
      frequencyType: PillFrequencyType.values.firstWhere(
        (f) => f.name == data['frequency'],
        orElse: () => PillFrequencyType.daily,
      ),
      weekdays: weekdays,
      // schedules не хранятся в PocketBase — восстанавливаем дефолтное
      schedules: const [PillSchedule(hour: 9, minute: 0)],
      startDate: DateTime.parse(data['start'] as String),
      endDate: data['end'] != null
          ? DateTime.tryParse(data['end'] as String)
          : null,
      takenDates: const [],
    );
  }
}
