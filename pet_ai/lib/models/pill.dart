import 'package:flutter/material.dart';
import 'package:pet_satellite/models/remindable.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
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

/// Единица измерения дозы. Доступный набор единиц зависит от вида препарата
/// ([PillKind]) — см. [DoseUnit.forKind].
class DoseUnit {
  final String id;
  final String label; // краткая форма для отображения, напр. «таб.», «мл»

  const DoseUnit({required this.id, required this.label});

  static const none = DoseUnit(id: 'none', label: '');
  static const tablet = DoseUnit(id: 'tablet', label: 'таб.');
  static const capsule = DoseUnit(id: 'capsule', label: 'капс.');
  static const ml = DoseUnit(id: 'ml', label: 'мл');
  static const mg = DoseUnit(id: 'mg', label: 'мг');
  static const gram = DoseUnit(id: 'gram', label: 'г');
  static const drop = DoseUnit(id: 'drop', label: 'кап.');
  static const unit = DoseUnit(id: 'unit', label: 'ед.');
  static const spray = DoseUnit(id: 'spray', label: 'впрыск');
  static const application = DoseUnit(id: 'application', label: 'нанесение');
  static const piece = DoseUnit(id: 'piece', label: 'шт.');
  static const teaspoon = DoseUnit(id: 'teaspoon', label: 'ч.л.');

  static const all = <DoseUnit>[
    tablet,
    capsule,
    ml,
    mg,
    gram,
    drop,
    unit,
    spray,
    application,
    piece,
    teaspoon,
    none,
  ];

  static DoseUnit byId(String id) =>
      all.firstWhere((u) => u.id == id, orElse: () => none);

  /// Единицы, подходящие выбранному виду препарата. Первая — по умолчанию.
  /// Всегда заканчивается на [none] («другое») как запасным вариантом.
  static List<DoseUnit> forKind(PillKind? kind) {
    switch (kind?.id) {
      case 'c1855lfnv3bni66': // Таблетка
        return const [tablet, mg, piece, none];
      case 'qyamefo3gztqwg1': // Капсула
        return const [capsule, mg, piece, none];
      case 'rm4pf2ni3l99r4b': // Жидкость
        return const [ml, mg, none];
      case 'kepj0nk6qnccw77': // Капли
        return const [drop, ml, none];
      case 'unku1v40f48p4l4': // Инъекция
        return const [ml, unit, mg, none];
      case '2k0u98csxnvsh8o': // Ингалятор
        return const [spray, unit, none];
      case 'mon5i8j2s9xoho7': // Спрей
        return const [spray, application, none];
      case 's2akauj574a7mrx': // Порошок
        return const [mg, gram, teaspoon, none];
      case 'o21zqz6cfs3dcs4': // Гель
      case '3nyf1vbu009dn6x': // Мазь
      case 'ie1sziw80vagg4q': // Крем
        return const [application, gram, none];
      case '34lz4yydq52c0n0': // Лосьон
        return const [application, ml, none];
      case 'bf1o8009eycnzfr': // Пенка
        return const [application, none];
      case 'htv28sijgs6dagw': // Пластырь
        return const [piece, none];
      case 'lv3or9euunqavjq': // Препарат местного действия
        return const [application, piece, none];
      default:
        return const [tablet, ml, mg, drop, piece, unit, application, none];
    }
  }

  static String declensionByUnit(int count, DoseUnit unit) {
    switch (unit.id) {
      case 'spray':
        return declension(count, 'впрыск', 'впрыска', 'впрысков');
      case 'application':
        return declension(count, 'нанесение', 'нанесения', 'нанесений');
      default:
        return unit.label;
    }
  }

  @override
  bool operator ==(Object other) => other is DoseUnit && other.id == id;

  @override
  int get hashCode => id.hashCode;
}

/// Одна отметка приёма препарата «по требованию»: время и (опционально) доза.
class PillIntake {
  final DateTime time;
  final int doseValue; // 0 → доза не указана
  final DoseUnit doseUnit;

  const PillIntake({
    required this.time,
    this.doseValue = 0,
    this.doseUnit = DoseUnit.none,
  });

  String get timeLabel =>
      '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';

  String get doseLabel => doseValue == 0
      ? ''
      : '$doseValue ${DoseUnit.declensionByUnit(doseValue, doseUnit)}'
            .trimRight();

  Map<String, dynamic> toJson() => {
    'time': time.toIso8601String(),
    if (doseValue != 0) 'doseValue': doseValue,
    if (doseValue != 0) 'doseUnit': doseUnit.id,
  };

  factory PillIntake.fromJson(Map<String, dynamic> json) {
    // Legacy: ранние сборки хранили дозу строкой в ключе 'dose'.
    final legacy = json['dose'] as String?;
    if (json['doseValue'] == null && legacy != null && legacy.isNotEmpty) {
      final (value, unit) = Pill.legacyParseDose(legacy);
      return PillIntake(
        time: DateTime.parse(json['time'] as String),
        doseValue: value,
        doseUnit: unit,
      );
    }
    return PillIntake(
      time: DateTime.parse(json['time'] as String),
      doseValue: (json['doseValue'] as num?)?.toInt() ?? 0,
      doseUnit: json['doseUnit'] != null
          ? DoseUnit.byId(json['doseUnit'] as String)
          : DoseUnit.none,
    );
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

class Pill with Remindable implements PbEntity {
  static const codec = _PillReminderCodec();

  final String id;
  final String name;
  final PillKind? kind;

  /// Цвет иконки (ARGB int). null → используется акцентный цвет приложения.
  final int? color;
  final int doseValue; // 0 → доза не указана
  final DoseUnit doseUnit;
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

  /// Журнал приёмов для вида «по требованию» (каждый приём — время + доза).
  /// Для остальных видов всегда пустой.
  final List<PillIntake> intakes;
  final String? eventId; // linked PetEvent for notifications

  /// «Напомнить за» до каждого приёма (по умолчанию — точно во время приёма).
  @override
  final int remindBeforeValue;
  @override
  final RemindBeforeVariant remindBeforeVariant;

  @override
  bool operator ==(Object other) {
    if (other is Pill) return id == other.id;
    return false;
  }

  @override
  int get hashCode => id.hashCode;

  const Pill({
    required this.id,
    required this.name,
    required this.kind,
    this.color,
    this.doseValue = 0,
    this.doseUnit = DoseUnit.none,
    required this.frequencyType,
    required this.weekdays,
    required this.schedules,
    required this.startDate,
    this.endDate,
    required this.takenDates,
    this.takenSchedules = const {},
    this.intakes = const [],
    this.eventId,
    this.remindBeforeValue = 0,
    this.remindBeforeVariant = RemindBeforeVariant.minutes,
  });

  // ── Backward-compat accessors ─────────────────────────────────────────────

  int get hour => schedules.isNotEmpty ? schedules.first.hour : 9;
  int get minute => schedules.isNotEmpty ? schedules.first.minute : 0;

  // ── Computed properties ───────────────────────────────────────────────────

  /// Доза в человекочитаемом виде, напр. «2 таб.», «3 впрыска». Пусто, если
  /// доза не задана.
  String get doseLabel => doseValue == 0
      ? ''
      : '$doseValue ${DoseUnit.declensionByUnit(doseValue, doseUnit)}'
            .trimRight();

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

  /// Отметки приёма «по требованию» за [day], отсортированные по времени.
  List<PillIntake> intakesOnDay(DateTime day) {
    final result =
        intakes
            .where(
              (i) =>
                  i.time.year == day.year &&
                  i.time.month == day.month &&
                  i.time.day == day.day,
            )
            .toList()
          ..sort((a, b) => a.time.compareTo(b.time));
    return result;
  }

  /// Returns true when every schedule for [day] is marked as taken.
  bool isTakenOnDay(DateTime day) {
    final key = dateKey(day);
    if (frequencyType == PillFrequencyType.onDemand) {
      if (intakesOnDay(day).isNotEmpty) return true;
      return takenDates.contains(key); // legacy on-demand saves
    }
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
    if (frequencyType == PillFrequencyType.onDemand) {
      final c = intakesOnDay(day).length;
      if (c > 0) return c;
      return takenDates.contains(key) ? 1 : 0; // legacy on-demand saves
    }
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
    int? doseValue,
    DoseUnit? doseUnit,
    PillFrequencyType? frequencyType,
    List<int>? weekdays,
    List<PillSchedule>? schedules,
    DateTime? startDate,
    DateTime? endDate,
    bool clearEndDate = false,
    List<String>? takenDates,
    Map<String, List<int>>? takenSchedules,
    List<PillIntake>? intakes,
    String? eventId,
    int? remindBeforeValue,
    RemindBeforeVariant? remindBeforeVariant,
  }) => Pill(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    color: clearColor ? null : (color ?? this.color),
    doseValue: doseValue ?? this.doseValue,
    doseUnit: doseUnit ?? this.doseUnit,
    frequencyType: frequencyType ?? this.frequencyType,
    weekdays: weekdays ?? this.weekdays,
    schedules: schedules ?? this.schedules,
    startDate: startDate ?? this.startDate,
    endDate: clearEndDate ? null : (endDate ?? this.endDate),
    takenDates: takenDates ?? this.takenDates,
    takenSchedules: takenSchedules ?? this.takenSchedules,
    intakes: intakes ?? this.intakes,
    eventId: eventId ?? this.eventId,
    remindBeforeValue: remindBeforeValue ?? this.remindBeforeValue,
    remindBeforeVariant: remindBeforeVariant ?? this.remindBeforeVariant,
  );

  // ── Serialization ─────────────────────────────────────────────────────────

  /// Migration-only: разбирает legacy-строку дозы (напр. «1 таблетка», «5 мл»)
  /// в структурированную пару значение+единица. Используется лишь при чтении
  /// старых сохранений; новые данные всегда хранят [doseValue]/[doseUnit].
  static (int value, DoseUnit unit) legacyParseDose(String dose) {
    final match = RegExp(r'^\s*([0-9]+)\s*(.*)$').firstMatch(dose);
    if (match == null) return (0, DoseUnit.none);
    final value = int.tryParse(match.group(1)!) ?? 0;
    final rest = match.group(2)!.trim().toLowerCase();
    if (rest.isEmpty) return (value, DoseUnit.none);
    final unit = DoseUnit.all.firstWhere(
      (u) => u.id != 'none' && rest.startsWith(u.label.toLowerCase()),
      orElse: () => DoseUnit.none,
    );
    return (value, unit);
  }

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

    final frequencyType = PillFrequencyType.values.firstWhere(
      (f) => f.name == json['frequencyType'],
      orElse: () => PillFrequencyType.daily,
    );
    final takenDates =
        (json['takenDates'] as List<dynamic>?)?.cast<String>() ?? const [];

    return Pill(
      id: json['id'] as String,
      name: json['name'] as String,
      kind: json['kind'] != null ? PillKind.byId(json['kind'] as String) : null,
      color: _parseColor(json['color']),
      doseValue: _parseDoseValue(json['doseValue'], json['dose']),
      doseUnit: _parseDoseUnit(json['doseUnit'], json['dose']),
      frequencyType: frequencyType,
      weekdays: (json['weekdays'] as List<dynamic>?)?.cast<int>() ?? [],
      schedules: schedules,
      startDate: DateTime.parse(json['startDate'] as String),
      endDate: json['endDate'] != null
          ? DateTime.parse(json['endDate'] as String)
          : null,
      takenDates: takenDates,
      takenSchedules: _parseTakenSchedules(json['takenSchedules']),
      intakes: _parseIntakes(json['intakes'], frequencyType, takenDates),
      eventId: json['eventId'] as String?,
      remindBeforeValue: json['remindBeforeValue'] as int? ?? 0,
      remindBeforeVariant: RemindBeforeVariant.values.firstWhere(
        (v) => v.name == (json['remindBeforeVariant'] as String?),
        orElse: () => RemindBeforeVariant.minutes,
      ),
    );
  }

  /// Parses the on-demand intake log. Falls back to migrating legacy on-demand
  /// saves (which only stored per-day dateKeys in [takenDates]).
  static List<PillIntake> _parseIntakes(
    dynamic raw,
    PillFrequencyType frequencyType,
    List<String> legacyTakenDates,
  ) {
    if (raw is List) {
      return raw
          .map((e) => PillIntake.fromJson((e as Map).cast<String, dynamic>()))
          .toList();
    }
    if (frequencyType == PillFrequencyType.onDemand) {
      return legacyTakenDates
          .map((k) => DateTime.tryParse(k))
          .whereType<DateTime>()
          .map((d) => PillIntake(time: d))
          .toList();
    }
    return const [];
  }

  static Map<String, List<int>> _parseTakenSchedules(dynamic raw) {
    if (raw == null) return {};
    final map = raw as Map<String, dynamic>;
    return map.map((k, v) => MapEntry(k, (v as List<dynamic>).cast<int>()));
  }

  /// Reads the dose value, preferring the structured [doseValue] key and
  /// falling back to migrating a legacy free-text [dose] string.
  static int _parseDoseValue(dynamic rawValue, dynamic legacyDose) {
    if (rawValue is num) return rawValue.toInt();
    if (legacyDose is String && legacyDose.isNotEmpty) {
      return legacyParseDose(legacyDose).$1;
    }
    return 0;
  }

  static DoseUnit _parseDoseUnit(dynamic rawUnit, dynamic legacyDose) {
    if (rawUnit is String && rawUnit.isNotEmpty) return DoseUnit.byId(rawUnit);
    if (legacyDose is String && legacyDose.isNotEmpty) {
      return legacyParseDose(legacyDose).$2;
    }
    return DoseUnit.none;
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
    'doseValue': doseValue,
    'doseUnit': doseUnit.id,
    // Legacy-зеркало для старых сборок, читающих строковую дозу.
    'dose': doseLabel,
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
    'intakes': intakes.map((i) => i.toJson()).toList(),
    'eventId': eventId,
    'remindBeforeValue': remindBeforeValue,
    'remindBeforeVariant': remindBeforeVariant.name,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    "id": id,
    "name": name,
    'kind': kind?.id,
    'color': color,
    "pet": ownerId,
    "dose_value": doseValue,
    "dose_unit": doseUnit.id,
    // Legacy-зеркало (human-readable) для старых клиентов.
    "dose": doseLabel,
    "frequency": frequencyType.name,
    // weekdays в схеме — multi-select со строковыми значениями "1".."7".
    "weekdays": weekdays.map((w) => w.toString()).toList(),
    "start": startDate.toIso8601String(),
    "end": endDate?.toIso8601String(),
    // Времена приёма и история отметок (json-поля).
    "schedules": schedules.map((s) => s.toJson()).toList(),
    "taken_schedules": takenSchedules,
    // Для «по требованию» в taken_dates лежит журнал приёмов (объекты
    // {time, dose}); для остальных видов — список dateKey-строк.
    "taken_dates": frequencyType == PillFrequencyType.onDemand
        ? intakes.map((i) => i.toJson()).toList()
        : takenDates,
    'remind_before_value': remindBeforeValue,
    'remind_before_variant': remindBeforeVariant.name,
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
              .map(
                (s) => PillSchedule.fromJson(
                  (s as Map).map((k, v) => MapEntry(k.toString(), v)),
                ),
              )
              .toList()
        : const [PillSchedule(hour: 9, minute: 0)];

    final frequencyType = PillFrequencyType.values.firstWhere(
      (f) => f.name == data['frequency'],
      orElse: () => PillFrequencyType.daily,
    );

    // taken_dates: для «по требованию» — журнал приёмов (объекты {time, dose}),
    // для остальных видов — список dateKey-строк. Поддерживаем оба формата и
    // миграцию старых on-demand-записей (строки → приём в полночь).
    final rawTakenDates = data['taken_dates'] as List<dynamic>? ?? const [];
    final List<String> takenDates;
    final List<PillIntake> intakes;
    if (frequencyType == PillFrequencyType.onDemand) {
      takenDates = const [];
      intakes = rawTakenDates
          .map((e) {
            if (e is Map) {
              return PillIntake.fromJson(e.cast<String, dynamic>());
            }
            final d = DateTime.tryParse(e.toString());
            return d != null ? PillIntake(time: d) : null;
          })
          .whereType<PillIntake>()
          .toList();
    } else {
      takenDates = rawTakenDates.map((e) => e.toString()).toList();
      intakes = const [];
    }

    return Pill(
      id: data['id'] as String,
      name: data['name'] as String,
      kind: data['kind'] != null && (data['kind'] as String).isNotEmpty
          ? PillKind.byId(data['kind'] as String)
          : null,
      color: Pill._parseColor(data['color']),
      doseValue: Pill._parseDoseValue(data['dose_value'], data['dose']),
      doseUnit: Pill._parseDoseUnit(data['dose_unit'], data['dose']),
      frequencyType: frequencyType,
      weekdays: weekdays,
      schedules: schedules,
      startDate: DateTime.parse(data['start'] as String),
      endDate: data['end'] != null && (data['end'] as String).isNotEmpty
          ? DateTime.tryParse(data['end'] as String)
          : null,
      takenDates: takenDates,
      takenSchedules: Pill._parseTakenSchedules(data['taken_schedules']),
      intakes: intakes,
      remindBeforeValue: (data['remind_before_value'] as num?)?.toInt() ?? 0,
      remindBeforeVariant: RemindBeforeVariant.values.firstWhere(
        (v) => v.name == (data['remind_before_variant'] as String?),
        orElse: () => RemindBeforeVariant.minutes,
      ),
    );
  }
}
