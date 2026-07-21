import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';

/// Время суток прогулки. Четыре варианта — как на макете (Утро/День/Вечер/Ночь).
enum WalkTime { morning, afternoon, evening, night }

extension WalkTimeX on WalkTime {
  String get label {
    switch (this) {
      case WalkTime.morning:
        return 'Утро';
      case WalkTime.afternoon:
        return 'День';
      case WalkTime.evening:
        return 'Вечер';
      case WalkTime.night:
        return 'Ночь';
    }
  }

  IconData get icon {
    switch (this) {
      case WalkTime.morning:
        return Icons.wb_twilight;
      case WalkTime.afternoon:
        return Icons.wb_sunny_outlined;
      case WalkTime.evening:
        return Icons.nights_stay_outlined;
      case WalkTime.night:
        return Icons.bedtime_outlined;
    }
  }

  static WalkTime fromHour(int hour) {
    if (hour < 5) return WalkTime.night;
    if (hour < 12) return WalkTime.morning;
    if (hour < 17) return WalkTime.afternoon;
    if (hour < 22) return WalkTime.evening;
    return WalkTime.night;
  }

  static WalkTime now() => fromHour(DateTime.now().hour);

  static WalkTime fromName(String? name) => WalkTime.values.firstWhere(
    (e) => e.name == name,
    orElse: () => WalkTime.morning,
  );
}

/// Характер прогулки — «Как прошла» на макете. Мультивыбор: у одной прогулки
/// может быть несколько меток (напр. «Активная, игры с собаками»).
enum WalkActivity { active, calm, dogGames, training }

extension WalkActivityX on WalkActivity {
  String get label {
    switch (this) {
      case WalkActivity.active:
        return 'Активная';
      case WalkActivity.calm:
        return 'Спокойная';
      case WalkActivity.dogGames:
        return 'Игры с собаками';
      case WalkActivity.training:
        return 'Дрессировка';
    }
  }

  IconData get icon {
    switch (this) {
      case WalkActivity.active:
        return Icons.bolt;
      case WalkActivity.calm:
        return Icons.cloud_outlined;
      case WalkActivity.dogGames:
        return Icons.sports_baseball_outlined;
      case WalkActivity.training:
        return Icons.school_outlined;
    }
  }

  static WalkActivity? fromName(String? name) {
    for (final a in WalkActivity.values) {
      if (a.name == name) return a;
    }
    return null;
  }

  /// Разбирает список имён меток (из JSON/PocketBase) в набор [WalkActivity],
  /// молча отбрасывая незнакомые значения.
  static List<WalkActivity> listFromNames(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .map((e) => fromName(e?.toString()))
        .whereType<WalkActivity>()
        .toList();
  }
}

class WalkEntry implements BaseEntry {
  static const codec = _WalkEntryCodec();

  @override
  final String id;
  @override
  final DateTime date;

  /// Длительность прогулки в минутах.
  final int durationMinutes;

  final WalkTime walkTime;

  /// Метки характера прогулки (может быть несколько или ни одной).
  final List<WalkActivity> activities;

  WalkEntry({
    String? id,
    required this.date,
    required this.durationMinutes,
    required this.walkTime,
    this.activities = const [],
  }) : id = id ?? generateId();

  WalkEntry copyWith({
    DateTime? date,
    int? durationMinutes,
    WalkTime? walkTime,
    List<WalkActivity>? activities,
  }) => WalkEntry(
    id: id,
    date: date ?? this.date,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    walkTime: walkTime ?? this.walkTime,
    activities: activities ?? this.activities,
  );

  /// Человекочитаемый список меток: «Активная, игры с собаками».
  /// Первая метка — с заглавной, остальные строчными, как на макете.
  String get activitiesLabel {
    if (activities.isEmpty) return '';
    final parts = <String>[];
    for (var i = 0; i < activities.length; i++) {
      final label = activities[i].label;
      parts.add(i == 0 ? label : label.toLowerCase());
    }
    return parts.join(', ');
  }

  factory WalkEntry.fromJson(Map<String, dynamic> json) {
    return WalkEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      durationMinutes: (json['durationMinutes'] as num?)?.toInt() ?? 0,
      walkTime: WalkTimeX.fromName(json['walkTime'] as String?),
      activities: WalkActivityX.listFromNames(json['activities']),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'durationMinutes': durationMinutes,
    'walkTime': walkTime.name,
    'activities': activities.map((a) => a.name).toList(),
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'pet': ownerId,
    'date': date.toIso8601String(),
    'minutes': durationMinutes,
    'day_part': walkTime.name,
    'activities': activities.map((a) => a.name).toList(),
  };
}

class _WalkEntryCodec extends PbCodec<WalkEntry> {
  const _WalkEntryCodec();

  @override
  WalkEntry fromPocketBase(Map<String, dynamic> data) => WalkEntry(
    id: data['id'] as String?,
    date: DateTime.parse(data['date'] as String),
    durationMinutes: (data['minutes'] as num?)?.toInt() ?? 0,
    walkTime: WalkTimeX.fromName(data['day_part'] as String?),
    activities: WalkActivityX.listFromNames(data['activities']),
  );
}

/// Один столбик графика прогулок: подпись, суммарные минуты за период и
/// пометка «подсветить» (текущий день/период). Цвет столбика выбирает виджет.
class WalkBucket {
  final String label;
  final int minutes;
  final bool highlight;

  const WalkBucket({
    required this.label,
    required this.minutes,
    this.highlight = false,
  });
}

class WalkHistory extends History<WalkEntry> {
  WalkHistory({required super.entries});
  WalkHistory.empty() : super.empty();

  static bool _sameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  /// Добавляет новую прогулку или заменяет существующую с тем же [id]
  /// (редактирование). Возвращает фактически сохранённую запись.
  WalkEntry addOrReplace(WalkEntry entry) {
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      add(entry);
    }
    return entry;
  }

  List<WalkEntry> entriesOn(DateTime day) =>
      entries.where((e) => _sameDay(e.date, day)).toList();

  int get todayCount => entriesOn(DateTime.now()).length;

  int get todayMinutes => entriesOn(
    DateTime.now(),
  ).fold(0, (sum, e) => sum + e.durationMinutes);

  bool get hasAnyToday => todayCount > 0;

  /// Средние минуты прогулок в день по дням, где были прогулки, за последние
  /// [days] дней. Возвращает 0, если данных нет.
  int averageDailyMinutes({int days = 30}) {
    final now = DateTime.now();
    final start = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: days - 1));
    final perDay = <DateTime, int>{};
    for (final e in entries) {
      final day = DateTime(e.date.year, e.date.month, e.date.day);
      if (day.isBefore(start)) continue;
      perDay[day] = (perDay[day] ?? 0) + e.durationMinutes;
    }
    if (perDay.isEmpty) return 0;
    final total = perDay.values.fold(0, (a, b) => a + b);
    return (total / perDay.length).round();
  }

  /// Разница минут за сегодня и среднего в день (для бейджа «+10 мин к среднему»).
  int get deltaToAverageToday => todayMinutes - averageDailyMinutes();

  /// Столбики графика для выбранного периода.
  ///  • week  — 7 дней текущей недели (Пн…Вс), подпись — день недели,
  ///    подсвечен сегодняшний день;
  ///  • month — по неделям текущего месяца, подпись — числа диапазона;
  ///  • иначе — по месяцам (последние 12), подпись — месяц.
  List<WalkBucket> buckets(HistoryPeriod period) {
    switch (period) {
      case HistoryPeriod.week:
      case HistoryPeriod.day:
        return _weekBuckets();
      case HistoryPeriod.month:
        return _monthBuckets();
      case HistoryPeriod.halfYear:
      case HistoryPeriod.year:
      case HistoryPeriod.all:
        return _monthlyBuckets();
    }
  }

  static const _weekdayLabels = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
  static const _monthLabels = [
    'Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн',
    'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек',
  ];

  List<WalkBucket> _weekBuckets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monday = today.subtract(Duration(days: today.weekday - 1));
    return List.generate(7, (i) {
      final day = monday.add(Duration(days: i));
      final minutes = entriesOn(day).fold(0, (s, e) => s + e.durationMinutes);
      return WalkBucket(
        label: _weekdayLabels[i],
        minutes: minutes,
        highlight: _sameDay(day, today),
      );
    });
  }

  List<WalkBucket> _monthBuckets() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    final buckets = <WalkBucket>[];
    for (var startDay = 1; startDay <= daysInMonth; startDay += 7) {
      final endDay = (startDay + 6).clamp(1, daysInMonth);
      var minutes = 0;
      var containsToday = false;
      for (var d = startDay; d <= endDay; d++) {
        final day = DateTime(now.year, now.month, d);
        minutes += entriesOn(day).fold(0, (s, e) => s + e.durationMinutes);
        if (_sameDay(day, today)) containsToday = true;
      }
      buckets.add(
        WalkBucket(
          label: '$startDay–$endDay',
          minutes: minutes,
          highlight: containsToday,
        ),
      );
    }
    return buckets;
  }

  List<WalkBucket> _monthlyBuckets() {
    final now = DateTime.now();
    final buckets = <WalkBucket>[];
    for (var i = 11; i >= 0; i--) {
      final month = DateTime(now.year, now.month - i, 1);
      final minutes = entries
          .where(
            (e) => e.date.year == month.year && e.date.month == month.month,
          )
          .fold(0, (s, e) => s + e.durationMinutes);
      buckets.add(
        WalkBucket(
          label: _monthLabels[month.month - 1],
          minutes: minutes,
          highlight: month.year == now.year && month.month == now.month,
        ),
      );
    }
    return buckets;
  }

  static final walkSerializer = HistorySerializer<WalkEntry>(
    fromJson: WalkEntry.fromJson,
  );
}
