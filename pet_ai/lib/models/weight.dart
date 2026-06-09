import 'package:pet_satellite/models/history.dart';

class WeightEntry implements BaseEntry {
  @override
  final DateTime date;
  final double weight;

  WeightEntry({required this.date, required this.weight});

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'weight': weight};
  }

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'pet': ownerId,
    'date': date.toIso8601String(),
    'weight': weight,
  };
}

class WeightHistory extends History<WeightEntry> {
  WeightHistory({required super.entries});
  WeightHistory.empty() : super.empty();

  /// Добавляет или заменяет запись веса за сегодня (макс. одна в день).
  void addWeight(double weight) {
    final now = DateTime.now();
    final todayIdx = entries.indexWhere(
      (e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day,
    );

    final entry = WeightEntry(
      date: now,
      weight: double.parse(weight.toStringAsFixed(1)),
    );

    if (todayIdx >= 0) {
      entries[todayIdx] = entry;
    } else {
      add(entry);
    }
  }

  /// Есть ли запись за сегодня.
  bool hasTodayEntry() {
    final now = DateTime.now();
    return entries.any(
      (e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day,
    );
  }

  String lastWeightString() {
    if (lastWeight != null) {
      return "${lastWeight!.toStringAsFixed(1)} кг";
    } else {
      return "Нет данных";
    }
  }

  double? weightDynamic() {
    if (entries.length < 2) {
      return null;
    } else {
      return entries[entries.length - 1].weight -
          entries[entries.length - 2].weight;
    }
  }

  double? get lastWeight => lastEntry?.weight;

  static final weightSerializer = HistorySerializer<WeightEntry>(
    fromJson: WeightEntry.fromJson,
  );
}
