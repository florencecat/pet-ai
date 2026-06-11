import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';

/// Время суток для записи настроения / питания.
enum DayPart { morning, afternoon, evening }

extension DayPartX on DayPart {
  String get label {
    switch (this) {
      case DayPart.morning:
        return 'Утро';
      case DayPart.afternoon:
        return 'День';
      case DayPart.evening:
        return 'Вечер';
    }
  }

  IconData get icon {
    switch (this) {
      case DayPart.morning:
        return Icons.wb_sunny_outlined;
      case DayPart.afternoon:
        return Icons.light_mode_outlined;
      case DayPart.evening:
        return Icons.nightlight_outlined;
    }
  }

  /// Текущее время суток на основе часа.
  static DayPart fromHour(int hour) {
    if (hour < 12) return DayPart.morning;
    if (hour < 18) return DayPart.afternoon;
    return DayPart.evening;
  }

  static DayPart now() => fromHour(DateTime.now().hour);
}

// Настроение
enum PetMood {
  happy,
  calm,
  sick,
  playful,
}

extension PetMoodX on PetMood {
  String get label {
    switch (this) {
      case PetMood.happy:
        return "Счастлив";
      case PetMood.calm:
        return "Спокойный";
      case PetMood.sick:
        return "Болеет";
      case PetMood.playful:
        return "Игривый";
    }
  }

  int get value {
    switch (this) {
      case PetMood.sick:
        return 1;
      case PetMood.calm:
        return 2;
      case PetMood.playful:
        return 3;
      case PetMood.happy:
        return 4;
    }
  }

  IconData get icon {
    switch (this) {
      case PetMood.sick:
        return Icons.sick_outlined;
      case PetMood.calm:
        return Icons.sentiment_neutral;
      case PetMood.playful:
        return Icons.sports_baseball_outlined;
      case PetMood.happy:
        return Icons.sentiment_very_satisfied;
    }
  }
}

class MoodEntry implements BaseEntry {
  static const codec = _MoodEntryCodec();

  @override
  final DateTime date;
  final PetMood mood;
  final DayPart dayPart;

  MoodEntry({
    required this.date,
    required this.mood,
    required this.dayPart,
  });

  /// Обратная совместимость: если dayPart не сохранён — угадываем по часу.
  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    final date = DateTime.parse(json["date"]);
    return MoodEntry(
      date: date,
      mood: PetMood.values.firstWhere((e) => e.name == json["mood"]),
      dayPart: json["dayPart"] != null
          ? DayPart.values.firstWhere(
              (e) => e.name == json["dayPart"],
              orElse: () => DayPartX.fromHour(date.hour),
            )
          : DayPartX.fromHour(date.hour),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "date": date.toIso8601String(),
    "mood": mood.name,
    "dayPart": dayPart.name,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'pet': ownerId,
    "date": date.toIso8601String(),
    "mood": mood.name,
    "day_part": dayPart.name,
  };
}

class _MoodEntryCodec extends PbCodec<MoodEntry> {
  const _MoodEntryCodec();

  @override
  MoodEntry fromPocketBase(Map<String, dynamic> data) {
    final date = DateTime.parse(data['date'] as String);
    return MoodEntry(
      date: date,
      mood: PetMood.values.firstWhere(
        (e) => e.name == data['mood'],
        orElse: () => PetMood.calm,
      ),
      dayPart: data['day_part'] != null
          ? DayPart.values.firstWhere(
              (e) => e.name == data['day_part'],
              orElse: () => DayPartX.fromHour(date.hour),
            )
          : DayPartX.fromHour(date.hour),
    );
  }
}

class MoodHistory extends History<MoodEntry> {
  MoodHistory({required super.entries});
  MoodHistory.empty() : super.empty();

  /// Последняя запись настроения: сортировка сначала по календарной дате,
  /// затем по времени суток (утро → день → вечер), затем по точному времени.
  /// Так в виджете здоровья показывается актуальное «дата + время суток».
  @override
  MoodEntry? get lastEntry {
    if (entries.isEmpty) return null;
    return entries.reduce((a, b) => _compare(a, b) >= 0 ? a : b);
  }

  /// Возвращает записи, отсортированные по (дата, время суток, время).
  List<MoodEntry> get sortedByDateAndPart =>
      [...entries]..sort(_compare);

  static int _compare(MoodEntry a, MoodEntry b) {
    final ad = DateTime(a.date.year, a.date.month, a.date.day);
    final bd = DateTime(b.date.year, b.date.month, b.date.day);
    final byDay = ad.compareTo(bd);
    if (byDay != 0) return byDay;
    final byPart = a.dayPart.index.compareTo(b.dayPart.index);
    if (byPart != 0) return byPart;
    return a.date.compareTo(b.date);
  }

  bool hasTodayEntry() {
    final now = DateTime.now();
    return entries.any((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
  }

  /// Проверяет, есть ли запись за сегодня с указанным временем суток.
  bool hasTodayEntryForPart(DayPart part) {
    final now = DateTime.now();
    return entries.any((e) =>
        e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day &&
        e.dayPart == part);
  }

  static final moodSerializer = HistorySerializer<MoodEntry>(
    fromJson: MoodEntry.fromJson,
  );
}
