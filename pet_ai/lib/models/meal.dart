import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';

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

// ─── Тип питания ──────────────────────────────────────────────────────────────

/// Категория корма в дневнике питания. Натуральное питание — основной кейс
/// дневника; остальные типы позволяют не смешивать готовые корма с «натуралкой».
enum FoodKind { natural, dry, wet, treat }

extension FoodKindX on FoodKind {
  String get label {
    switch (this) {
      case FoodKind.natural:
        return 'Натуралка';
      case FoodKind.dry:
        return 'Сухой корм';
      case FoodKind.wet:
        return 'Влажный корм';
      case FoodKind.treat:
        return 'Лакомство';
    }
  }

  IconData get icon {
    switch (this) {
      case FoodKind.natural:
        return Icons.set_meal_outlined;
      case FoodKind.dry:
        return Icons.grain;
      case FoodKind.wet:
        return Icons.ramen_dining_outlined;
      case FoodKind.treat:
        return Icons.cookie_outlined;
    }
  }

  Color get color {
    switch (this) {
      case FoodKind.natural:
        return const Color(0xFF66BB6A);
      case FoodKind.dry:
        return const Color(0xFFFFA726);
      case FoodKind.wet:
        return const Color(0xFF42A5F5);
      case FoodKind.treat:
        return const Color(0xFFAB47BC);
    }
  }

  /// Предустановленные подсказки названий для автодополнения по типу корма.
  List<String> get presetFoods {
    switch (this) {
      case FoodKind.natural:
        return const [
          'Курица',
          'Индейка',
          'Говядина',
          'Телятина',
          'Кролик',
          'Рубец говяжий',
          'Куриные сердечки',
          'Печень',
          'Творог',
          'Кефир',
          'Рис',
          'Гречка',
          'Морковь',
          'Тыква',
          'Кабачок',
          'Яйцо',
          'Лосось',
          'Треска',
          'Сардина',
        ];
      case FoodKind.dry:
        return const [
          'Royal Canin',
          'Acana',
          'Orijen',
          'Grandorf',
          'Brit Care',
          'Pro Plan',
          "Hill's",
          'Monge',
          'Farmina',
          'Go!',
          'ProBalance',
          'Wellness',
        ];
      case FoodKind.wet:
        return const [
          'Royal Canin (пауч)',
          'Sheba',
          'Gourmet',
          'Felix',
          'Pro Plan (влажный)',
          'Animonda',
          'Berkley',
          'Brit (пауч)',
        ];
      case FoodKind.treat:
        return const [
          'Лакомство',
          'Сыр',
          'Кусочек курицы',
          'Дентал-палочка',
          'Сушёное мясо',
          'Витаминная подушечка',
        ];
    }
  }

  static FoodKind fromName(String? name) => FoodKind.values.firstWhere(
    (e) => e.name == name,
    orElse: () => FoodKind.natural,
  );
}

class MealEntry implements BaseEntry {
  static const codec = _MealEntryCodec();

  @override
  final String id;
  @override
  final DateTime date;
  final MealTime mealTime;
  final int appetiteScore; // 1–5
  final int grams;

  /// Название корма/блюда. Может быть пустым у старых записей.
  final String foodName;

  /// Тип питания (натуралка / сухой / влажный / лакомство).
  final FoodKind kind;

  MealEntry({
    String? id,
    required this.date,
    required this.mealTime,
    required this.appetiteScore,
    required this.grams,
    this.foodName = '',
    this.kind = FoodKind.natural,
  }) : id = id ?? generateId();

  MealEntry copyWith({
    DateTime? date,
    MealTime? mealTime,
    int? appetiteScore,
    int? grams,
    String? foodName,
    FoodKind? kind,
  }) => MealEntry(
    id: id,
    date: date ?? this.date,
    mealTime: mealTime ?? this.mealTime,
    appetiteScore: appetiteScore ?? this.appetiteScore,
    grams: grams ?? this.grams,
    foodName: foodName ?? this.foodName,
    kind: kind ?? this.kind,
  );

  factory MealEntry.fromJson(Map<String, dynamic> json) {
    return MealEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date'] as String),
      mealTime: MealTime.values.firstWhere(
        (e) => e.name == json['mealTime'],
        orElse: () => MealTime.morning,
      ),
      appetiteScore: json['appetiteScore'] as int,
      grams: json['grams'] as int,
      foodName: (json['foodName'] as String?) ?? '',
      kind: FoodKindX.fromName(json['kind'] as String?),
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'mealTime': mealTime.name,
    'appetiteScore': appetiteScore,
    'grams': grams,
    'foodName': foodName,
    'kind': kind.name,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'pet': ownerId,
    'date': date.toIso8601String(),
    'day_part': mealTime.name,
    'score': appetiteScore,
    'grams': grams,
    'food': foodName,
    'kind': kind.name,
  };
}

class _MealEntryCodec extends PbCodec<MealEntry> {
  const _MealEntryCodec();

  @override
  MealEntry fromPocketBase(Map<String, dynamic> data) => MealEntry(
    id: data['id'] as String?,
    date: DateTime.parse(data['date'] as String),
    mealTime: MealTime.values.firstWhere(
      (e) => e.name == data['day_part'],
      orElse: () => MealTime.morning,
    ),
    appetiteScore: (data['score'] as num).toInt(),
    grams: (data['grams'] as num).toInt(),
    foodName: (data['food'] as String?) ?? '',
    kind: FoodKindX.fromName(data['kind'] as String?),
  );
}

class MealHistory extends History<MealEntry> {
  MealHistory({required super.entries});
  MealHistory.empty() : super.empty();

  /// Добавляет новую запись питания или, если запись с таким [id] уже есть
  /// (редактирование), заменяет её. В один приём пищи можно записать несколько
  /// блюд — каждое блюдо это отдельная запись со своим id.
  MealEntry addOrReplace(MealEntry entry) {
    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      entries[idx] = entry;
    } else {
      add(entry);
    }
    return entry;
  }

  /// Список ранее введённых названий корма, от недавних к старым, без
  /// повторов (без учёта регистра). Используется для автодополнения —
  /// дневник «запоминает» названия так же, как профиль запоминает города.
  List<String> recentFoodNames({FoodKind? kind}) {
    final sorted = [...entries]..sort((a, b) => b.date.compareTo(a.date));
    final seen = <String>{};
    final result = <String>[];
    for (final e in sorted) {
      if (kind != null && e.kind != kind) continue;
      final name = e.foodName.trim();
      if (name.isEmpty) continue;
      final key = name.toLowerCase();
      if (seen.add(key)) result.add(name);
    }
    return result;
  }

  /// Подсказки автодополнения для поля названия корма: сперва то, что
  /// пользователь уже вводил (по этому типу корма), затем предустановленный
  /// список для данного типа. Отфильтровано по [query] и обрезано до [limit].
  List<String> foodSuggestions({
    required FoodKind kind,
    required String query,
    int limit = 6,
  }) {
    final q = query.trim().toLowerCase();
    final seen = <String>{};
    final ordered = <String>[];
    void addAll(Iterable<String> names) {
      for (final n in names) {
        final key = n.toLowerCase();
        if (seen.add(key)) ordered.add(n);
      }
    }

    addAll(recentFoodNames(kind: kind));
    addAll(kind.presetFoods);

    final filtered = q.isEmpty
        ? ordered
        : ordered.where((n) => n.toLowerCase().contains(q)).toList();
    return filtered.take(limit).toList();
  }

  static final foodSerializer = HistorySerializer<MealEntry>(
    fromJson: MealEntry.fromJson,
  );
}
