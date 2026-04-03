import 'package:pet_ai/models/history.dart';

enum WeightPeriod { month, year, all }

class WeightEntry implements BaseEntry {
  @override
  final DateTime date;
  final double weight;

  WeightEntry({
    required this.date,
    required this.weight,
  });

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {
      'date': date.toIso8601String(),
      'weight': weight,
    };
  }
}

class WeightHistory extends History<WeightEntry> {
  WeightHistory({required super.entries});
  WeightHistory.empty() : super.empty();

  void addWeight(double weight) {
    add(
      WeightEntry(
        date: DateTime.now(),
        weight: double.parse(weight.toStringAsFixed(1)),
      ),
    );
  }

  double? get lastWeight => lastEntry?.weight;
}