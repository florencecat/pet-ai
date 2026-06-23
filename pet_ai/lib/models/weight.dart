import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';

class WeightEntry implements BaseEntry {
  static const codec = _WeightEntryCodec();

  @override
  final String id;
  @override
  final DateTime date;
  final double weight;

  WeightEntry({String? id, required this.date, required this.weight})
    : id = id ?? generateId();

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  @override
  Map<String, dynamic> toJson() {
    return {'id': id, 'date': date.toIso8601String(), 'weight': weight};
  }

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'pet': ownerId,
    'date': date.toIso8601String(),
    'weight': weight,
  };
}

class _WeightEntryCodec extends PbCodec<WeightEntry> {
  const _WeightEntryCodec();

  @override
  WeightEntry fromPocketBase(Map<String, dynamic> data) => WeightEntry(
    id: data['id'] as String?,
    date: DateTime.parse(data['date'] as String),
    weight: (data['weight'] as num).toDouble(),
  );
}

class WeightHistory extends History<WeightEntry> {
  WeightHistory({required super.entries});
  WeightHistory.empty() : super.empty();

  /// Добавляет или заменяет запись веса за сегодня (макс. одна в день).
  /// Возвращает фактически сохранённую запись (для пуша в облако).
  WeightEntry addWeight(double weight) {
    final now = DateTime.now();
    final todayIdx = entries.indexWhere(
      (e) =>
          e.date.year == now.year &&
          e.date.month == now.month &&
          e.date.day == now.day,
    );

    final entry = WeightEntry(
      // Сохраняем id существующей записи за сегодня, чтобы апсерт в облаке
      // обновлял ту же запись, а не плодил дубликаты.
      id: todayIdx >= 0 ? entries[todayIdx].id : null,
      date: now,
      weight: double.parse(weight.toStringAsFixed(1)),
    );

    if (todayIdx >= 0) {
      entries[todayIdx] = entry;
    } else {
      add(entry);
    }
    return entry;
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
      return "${lastWeight!.toStringAsFixed(
          lastWeight! - lastWeight!.floorToDouble() < 1e-12 ? 0 : 1
      )} кг";
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
