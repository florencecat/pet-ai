import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';

enum MealTime { morning, afternoon, evening, night }

extension MealTimeX on MealTime {
  String get label {
    switch (this) {
      case MealTime.morning:
        return 'Утро';
      case MealTime.afternoon:
        return 'День';
      case MealTime.evening:
        return 'Вечер';
      case MealTime.night:
        return 'Ночь';
    }
  }

  IconData get icon {
    switch (this) {
      case MealTime.morning:
        return Icons.wb_sunny_outlined;
      case MealTime.afternoon:
        return Icons.wb_sunny;
      case MealTime.evening:
        return Icons.nights_stay_outlined;
      case MealTime.night:
        return Icons.bedtime_outlined;
    }
  }
}

class MealEntry implements BaseEntry {
  @override
  final DateTime date;
  final MealTime mealTime;
  final int appetiteScore; // 1–5
  final int grams;

  MealEntry({
    required this.date,
    required this.mealTime,
    required this.appetiteScore,
    required this.grams,
  });

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      date: DateTime.parse(json['date'] as String),
      mealTime: MealTime.values.firstWhere(
        (e) => e.name == json['mealTime'],
        orElse: () => MealTime.morning,
      ),
      appetiteScore: json['appetiteScore'] as int,
      grams: json['grams'] as int,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'mealTime': mealTime.name,
    'appetiteScore': appetiteScore,
    'grams': grams,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'pet': ownerId,
    'date': date.toIso8601String(),
    'day_part': mealTime.name,
    'score': appetiteScore,
    'grams': grams,
  };
}

class MealHistory extends History<MealEntry> {
  MealHistory({required super.entries});
  MealHistory.empty() : super.empty();

  static final foodSerializer = HistorySerializer<MealEntry>(
    fromJson: MealEntry.fromJson,
  );
}
