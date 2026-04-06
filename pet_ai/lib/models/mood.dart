import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:pet_ai/models/history.dart';

// Настроение
enum PetMood {
  happy,
  calm,
  sad,
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
      case PetMood.sad:
        return "Грустный";
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
      case PetMood.sad:
        return 2;
      case PetMood.calm:
        return 3;
      case PetMood.playful:
        return 4;
      case PetMood.happy:
        return 5;
    }
  }

  IconData get icon {
    switch (this) {
      case PetMood.sick:
        return Icons.sick_outlined;
      case PetMood.sad:
        return Icons.sentiment_very_dissatisfied;
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
  @override
  final DateTime date;
  final PetMood mood;

  MoodEntry({
    required this.date,
    required this.mood,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      date: DateTime.parse(json["date"]),
      mood: PetMood.values.firstWhere(
            (e) => e.name == json["mood"],
      ),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "date": date.toIso8601String(),
    "mood": mood.name,
  };
}

class MoodHistory extends History<MoodEntry> {
  MoodHistory({required super.entries});
  MoodHistory.empty() : super.empty();

  bool hasTodayEntry() {
    final now = DateTime.now();

    return entries.any((e) =>
    e.date.year == now.year &&
        e.date.month == now.month &&
        e.date.day == now.day);
  }

  static final moodSerializer = HistorySerializer<MoodEntry>(
    fromJson: MoodEntry.fromJson,
  );
}