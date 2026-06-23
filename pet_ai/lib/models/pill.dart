import 'package:flutter/material.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/theme/font_awesome_icons.dart';

class PillKind {
  final String id;
  final String name;

  const PillKind.empty() : id = '', name = '';
  const PillKind({required this.id, required this.name});

  Map<String, dynamic> toJson() => {'id': id, 'name': name};
  factory PillKind.fromJson(Map<String, dynamic> json) =>
      PillKind(id: json['id'], name: json['name']);

  /// Иконка-форма препарата (в стиле iOS: тип лекарства = форма иконки).
  IconData get icon {
    switch (id) {
      case 'qyamefo3gztqwg1': // Капсула
        return FontAwesome.capsules;
      case 'c1855lfnv3bni66': // Таблетка
        return FontAwesome.tablets;
      case 'rm4pf2ni3l99r4b': // Жидкость
        return FontAwesome.prescription_bottle;
      case 'lv3or9euunqavjq': // Препарат местного действия
        return FontAwesome.hand_holding_medical;
      case 'o21zqz6cfs3dcs4': // Гель
        return FontAwesome.pump_medical;
      case '2k0u98csxnvsh8o': // Ингалятор
        return FontAwesome.lungs;
      case 'unku1v40f48p4l4': // Инъекция
        return FontAwesome.syringe;
      case 'kepj0nk6qnccw77': // Капли
        return FontAwesome.tint;
      case 'ie1sziw80vagg4q': // Крем
        return FontAwesome.pump_soap;
      case '34lz4yydq52c0n0': // Лосьон
        return FontAwesome.hand_holding_water;
      case '3nyf1vbu009dn6x': // Мазь
        return FontAwesome.prescription_bottle_alt;
      case 'bf1o8009eycnzfr': // Пенка
        return FontAwesome.soap;
      case 'htv28sijgs6dagw': // Пластырь
        return FontAwesome.band_aid;
      case 's2akauj574a7mrx': // Порошок
        return FontAwesome.mortar_pestle;
      case 'mon5i8j2s9xoho7': // Спрей
        return FontAwesome.spray_can;
      default:
        return FontAwesome.pills;
    }
  }

  static const capsule = PillKind(id: 'qyamefo3gztqwg1', name: 'Капсула');
  static const pill = PillKind(id: 'c1855lfnv3bni66', name: 'Таблетка');
  static const fluid = PillKind(id: 'rm4pf2ni3l99r4b', name: 'Жидкость');
  static const localAction = PillKind(
    id: 'lv3or9euunqavjq',
    name: 'Препарат местного действия',
  );
  static const gel = PillKind(id: 'o21zqz6cfs3dcs4', name: 'Гель');
  static const inhalation = PillKind(id: '2k0u98csxnvsh8o', name: 'Ингалятор');
  static const injection = PillKind(id: 'unku1v40f48p4l4', name: 'Инъекция');
  static const drops = PillKind(id: 'kepj0nk6qnccw77', name: 'Капли');
  static const creme = PillKind(id: 'ie1sziw80vagg4q', name: 'Крем');
  static const lotion = PillKind(id: '34lz4yydq52c0n0', name: 'Лосьон');
  static const ointment = PillKind(id: '3nyf1vbu009dn6x', name: 'Мазь');
  static const foam = PillKind(id: 'bf1o8009eycnzfr', name: 'Пенка');
  static const plaster = PillKind(id: 'htv28sijgs6dagw', name: 'Пластырь');
  static const powder = PillKind(id: 's2akauj574a7mrx', name: 'Порошок');
  static const spray = PillKind(id: 'mon5i8j2s9xoho7', name: 'Спрей');

  static List<PillKind> get all => [
    capsule,
    pill,
    fluid,
    localAction,
    gel,
    inhalation,
    injection,
    drops,
    creme,
    lotion,
    ointment,
    foam,
    plaster,
    powder,
    spray,
  ];

  static PillKind byId(String id) {
    switch (id) {
      case 'qyamefo3gztqwg1':
        return capsule;
      case 'c1855lfnv3bni66':
        return pill;
      case 'rm4pf2ni3l99r4b':
        return fluid;
      case 'lv3or9euunqavjq':
        return localAction;
      case 'o21zqz6cfs3dcs4':
        return gel;
      case '2k0u98csxnvsh8o':
        return inhalation;
      case 'unku1v40f48p4l4':
        return injection;
      case 'kepj0nk6qnccw77':
        return drops;
      case 'ie1sziw80vagg4q':
        return creme;
      case '34lz4yydq52c0n0':
        return lotion;
      case '3nyf1vbu009dn6x':
        return ointment;
      case 'bf1o8009eycnzfr':
        return foam;
      case 'htv28sijgs6dagw':
        return plaster;
      case 's2akauj574a7mrx':
        return powder;
      case 'mon5i8j2s9xoho7':
        return spray;
      default:
        return PillKind.empty();
    }
  }
}

enum PillFrequencyType { daily, weekdays, onDemand }

extension PillFrequencyTypeX on PillFrequencyType {
  String get label {
    switch (this) {
      case PillFrequencyType.daily:
        return 'Ежедневно';
      case PillFrequencyType.weekdays:
        return 'По дням недели';
      case PillFrequencyType.onDemand:
        return 'По требованию';
    }
  }

  IconData get icon {
    switch (this) {
      case PillFrequencyType.daily:
        return Icons.repeat;
      case PillFrequencyType.weekdays:
        return Icons.calendar_view_week;
      case PillFrequencyType.onDemand:
        return Icons.alarm_on_outlined;
    }
  }
}

const _weekdayShort = {
  1: 'Пн',
  2: 'Вт',
  3: 'Ср',
  4: 'Чт',
  5: 'Пт',
  6: 'Сб',
  7: 'Вс',
};

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

  factory PillSchedule.fromJson(Map<String, dynamic> json) =>
      PillSchedule(hour: json['hour'] as int, minute: json['minute'] as int);

  @override
  bool operator ==(Object other) =>
      other is PillSchedule && other.hour == hour && other.minute == minute;

  @override
  int get hashCode => Object.hash(hour, minute);
}

class Pill implements PbEntity {
  static const codec = _PillReminderCodec();

  final String id;
  final String name;
  final PillKind? kind;

  /// Цвет иконки (ARGB int). null → используется акцентный цвет приложения.
  final int? color;
  final String dose; // e.g., "1 таблетка", "5 мл"
  final PillFrequencyType frequencyType;
  final List<int> weekdays; // 1=Пн..7=Вс; only for frequencyType.weekdays
  /// Ordered list of daily intake times. At least one entry is always present.
  final List<PillSchedule> schedules;
  final DateTime startDate;
  final DateTime? endDate;

  /// Legacy per-day taken flag (kept for backward compat reading old saves).
  final List<String> takenDates;

  /// Per-schedule taken state: dateKey → list of schedule indices that were taken.
  final Map<String, List<int>> takenSchedules;
  final String? eventId; // linked PetEvent for notifications

  const Pill({
    required this.id,
    required this.name,
    required this.kind,
    this.color,
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
      case PillFrequencyType.onDemand:
        // По требованию — всегда доступно для отметки, пока курс активен.
        return true;
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
      case PillFrequencyType.onDemand:
        return 'По требованию';
    }
  }

  // ── copyWith ──────────────────────────────────────────────────────────────

  Pill copyWith({
    String? name,
    PillKind? kind,
    int? color,
    bool clearColor = false,
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
  }) => Pill(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    color: clearColor ? null : (color ?? this.color),
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

  factory Pill.fromJson(Map<String, dynamic> json) {
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

    return Pill(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] != null ? PillKind.byId(json['kind'] as String) : null,
      color: _parseColor(json['color']),
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

  /// Tolerant parse of a stored colour: accepts int, num, or hex/decimal string.
  static int? _parseColor(dynamic raw) {
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is num) return raw.toInt();
    if (raw is String) {
      final s = raw.trim();
      if (s.isEmpty) return null;
      final hex = s.startsWith('#') ? s.substring(1) : s;
      return int.tryParse(hex, radix: 16) ?? int.tryParse(s);
    }
    return null;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'kind': kind?.id,
    'color': color,
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
    'kind': kind?.id,
    'color': color,
    "pet": ownerId,
    "dose": dose,
    "frequency": frequencyType.name,
    // weekdays в схеме — multi-select со строковыми значениями "1".."7".
    "weekdays": weekdays.map((w) => w.toString()).toList(),
    "start": startDate.toIso8601String(),
    "end": endDate?.toIso8601String(),
    // Времена приёма и история отметок (json-поля).
    "schedules": schedules.map((s) => s.toJson()).toList(),
    "taken_schedules": takenSchedules,
    "taken_dates": takenDates,
  };
}

class _PillReminderCodec extends PbCodec<Pill> {
  const _PillReminderCodec();

  @override
  Pill fromPocketBase(Map<String, dynamic> data) {
    // weekdays приходит как List<String> ("1".."7"). На всякий случай
    // поддерживаем и старый формат — строку "1, 2, 3".
    final rawWeekdays = data['weekdays'];
    final List<int> weekdays;
    if (rawWeekdays is List) {
      weekdays = rawWeekdays
          .map((s) => int.tryParse(s.toString().trim()))
          .whereType<int>()
          .toList();
    } else if (rawWeekdays is String && rawWeekdays.isNotEmpty) {
      weekdays = rawWeekdays
          .split(',')
          .map((s) => int.tryParse(s.trim()))
          .whereType<int>()
          .toList();
    } else {
      weekdays = <int>[];
    }

    // Времена приёма: json-список {hour, minute}. Если пусто — дефолт 09:00.
    final rawSchedules = data['schedules'];
    final schedules = (rawSchedules is List && rawSchedules.isNotEmpty)
        ? rawSchedules
              .map((s) => PillSchedule.fromJson(
                    (s as Map).map((k, v) => MapEntry(k.toString(), v)),
                  ))
              .toList()
        : const [PillSchedule(hour: 9, minute: 0)];

    return Pill(
      id: data['id'] as String,
      name: data['name'] as String,
      kind: data['kind'] != null && (data['kind'] as String).isNotEmpty
          ? PillKind.byId(data['kind'] as String)
          : null,
      color: Pill._parseColor(data['color']),
      dose: data['dose'] as String? ?? '',
      frequencyType: PillFrequencyType.values.firstWhere(
        (f) => f.name == data['frequency'],
        orElse: () => PillFrequencyType.daily,
      ),
      weekdays: weekdays,
      schedules: schedules,
      startDate: DateTime.parse(data['start'] as String),
      endDate: data['end'] != null && (data['end'] as String).isNotEmpty
          ? DateTime.tryParse(data['end'] as String)
          : null,
      takenDates:
          (data['taken_dates'] as List<dynamic>?)?.cast<String>() ?? const [],
      takenSchedules: Pill._parseTakenSchedules(data['taken_schedules']),
    );
  }
}
