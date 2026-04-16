import 'package:flutter/material.dart';
import 'package:pet_ai/models/history.dart';

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

class FoodEntry implements BaseEntry {
  @override
  final DateTime date;
  final MealTime mealTime;
  final int appetiteScore; // 1–5
  final int grams;

  FoodEntry({
    required this.date,
    required this.mealTime,
    required this.appetiteScore,
    required this.grams,
  });

  factory FoodEntry.fromJson(Map<String, dynamic> json) {
    return FoodEntry(
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
}

class FoodHistory extends History<FoodEntry> {
  FoodHistory({required super.entries});
  FoodHistory.empty() : super.empty();

  static final foodSerializer = HistorySerializer<FoodEntry>(
    fromJson: FoodEntry.fromJson,
  );
}
