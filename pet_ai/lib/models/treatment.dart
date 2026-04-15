import 'package:flutter/material.dart';
import 'package:pet_ai/models/history.dart';

/// Тип медицинского мероприятия
enum TreatmentKind {
  rabies,      // Прививка от бешенства
  ticks,       // Обработка от клещей и блох
  worms,       // Обработка от глистов
  vaccine,     // Прочая прививка (название вводит пользователь)
}

extension TreatmentKindX on TreatmentKind {
  String get label {
    switch (this) {
      case TreatmentKind.rabies:
        return 'Прививка от бешенства';
      case TreatmentKind.ticks:
        return 'Обработка от клещей и блох';
      case TreatmentKind.worms:
        return 'Обработка от глистов';
      case TreatmentKind.vaccine:
        return 'Прививка';
    }
  }

  String get shortLabel {
    switch (this) {
      case TreatmentKind.rabies:
        return 'Бешенство';
      case TreatmentKind.ticks:
        return 'Клещи/блохи';
      case TreatmentKind.worms:
        return 'Глисты';
      case TreatmentKind.vaccine:
        return 'Прививка';
    }
  }

  IconData get icon {
    switch (this) {
      case TreatmentKind.rabies:
        return Icons.coronavirus_outlined;
      case TreatmentKind.ticks:
        return Icons.bug_report_outlined;
      case TreatmentKind.worms:
        return Icons.medical_services_outlined;
      case TreatmentKind.vaccine:
        return Icons.vaccines;
    }
  }

  Color get color {
    switch (this) {
      case TreatmentKind.rabies:
        return const Color(0xFFD32F2F);
      case TreatmentKind.ticks:
        return const Color(0xFF8E24AA);
      case TreatmentKind.worms:
        return const Color(0xFF00897B);
      case TreatmentKind.vaccine:
        return const Color(0xFF1976D2);
    }
  }

  /// Стандартный интервал до следующего такого мероприятия
  Duration get defaultInterval {
    switch (this) {
      case TreatmentKind.rabies:
        return const Duration(days: 365);
      case TreatmentKind.ticks:
        return const Duration(days: 30);
      case TreatmentKind.worms:
        return const Duration(days: 90);
      case TreatmentKind.vaccine:
        return const Duration(days: 365);
    }
  }
}

class TreatmentEntry implements BaseEntry {
  @override
  final DateTime date;
  final TreatmentKind kind;
  /// Имя для kind=vaccine; для остальных — пусто/служебное.
  final String name;
  /// Дата следующего такого мероприятия. Пользователь может задать сам
  /// или принять значение по умолчанию.
  final DateTime nextDate;
  /// За сколько дней до nextDate напоминать.
  final int remindBeforeDays;
  /// id связанного PetEvent (для возможной отмены/перепланирования).
  final String? eventId;

  TreatmentEntry({
    required this.date,
    required this.kind,
    required this.nextDate,
    this.name = '',
    this.remindBeforeDays = 7,
    this.eventId,
  });

  String get displayName {
    if (kind == TreatmentKind.vaccine && name.isNotEmpty) {
      return 'Прививка: $name';
    }
    return kind.label;
  }

  factory TreatmentEntry.fromJson(Map<String, dynamic> json) {
    return TreatmentEntry(
      date: DateTime.parse(json['date'] as String),
      kind: TreatmentKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => TreatmentKind.vaccine,
      ),
      name: json['name'] as String? ?? '',
      nextDate: DateTime.parse(json['nextDate'] as String),
      remindBeforeDays: json['remindBeforeDays'] as int? ?? 7,
      eventId: json['eventId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String(),
    'kind': kind.name,
    'name': name,
    'nextDate': nextDate.toIso8601String(),
    'remindBeforeDays': remindBeforeDays,
    'eventId': eventId,
  };
}

class TreatmentHistory extends History<TreatmentEntry> {
  TreatmentHistory({required super.entries});
  TreatmentHistory.empty() : super.empty();

  /// Последняя запись указанного типа (по [TreatmentKind]).
  /// Для kind=vaccine можно ограничить названием.
  TreatmentEntry? lastOfKind(TreatmentKind kind, {String? name}) {
    final filtered = entries.where((e) {
      if (e.kind != kind) return false;
      if (name != null && e.name != name) return false;
      return true;
    }).toList();
    if (filtered.isEmpty) return null;
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered.first;
  }

  /// Все записи указанного типа, отсортированные по дате (новые сначала).
  List<TreatmentEntry> ofKind(TreatmentKind kind) {
    final filtered = entries.where((e) => e.kind == kind).toList();
    filtered.sort((a, b) => b.date.compareTo(a.date));
    return filtered;
  }

  static final treatmentSerializer = HistorySerializer<TreatmentEntry>(
    fromJson: TreatmentEntry.fromJson,
  );
}
