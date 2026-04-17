import 'package:flutter/material.dart';
import 'package:pet_ai/models/history.dart';

// ─── Предустановленные симптомы ──────────────────────────────────────────────

class SymptomTag {
  final String id;
  final String label;
  final IconData icon;
  final int colorValue;

  const SymptomTag({
    required this.id,
    required this.label,
    required this.icon,
    required this.colorValue,
  });

  Color get color => Color(colorValue);
}

class SymptomTags {
  static const vomiting = SymptomTag(
    id: 'vomiting',
    label: 'Рвота',
    icon: Icons.sick_outlined,
    colorValue: 0xFFE53935,
  );
  static const diarrhea = SymptomTag(
    id: 'diarrhea',
    label: 'Жидкий стул',
    icon: Icons.warning_amber_rounded,
    colorValue: 0xFFFF8F00,
  );
  static const refusedFood = SymptomTag(
    id: 'refused_food',
    label: 'Отказ от еды',
    icon: Icons.no_food_outlined,
    colorValue: 0xFFF57F17,
  );
  static const lethargy = SymptomTag(
    id: 'lethargy',
    label: 'Вялость',
    icon: Icons.bedtime_outlined,
    colorValue: 0xFF1565C0,
  );
  static const sneezing = SymptomTag(
    id: 'sneezing',
    label: 'Чихание',
    icon: Icons.air_outlined,
    colorValue: 0xFF6A1B9A,
  );
  static const coughing = SymptomTag(
    id: 'coughing',
    label: 'Кашель',
    icon: Icons.masks_outlined,
    colorValue: 0xFF558B2F,
  );
  static const scratching = SymptomTag(
    id: 'scratching',
    label: 'Расчёсывается',
    icon: Icons.touch_app_outlined,
    colorValue: 0xFF00838F,
  );
  static const limping = SymptomTag(
    id: 'limping',
    label: 'Хромает',
    icon: Icons.accessible_forward_outlined,
    colorValue: 0xFF4E342E,
  );

  static const all = [
    vomiting,
    diarrhea,
    refusedFood,
    lethargy,
    sneezing,
    coughing,
    scratching,
    limping,
  ];

  static SymptomTag? byId(String id) {
    try {
      return all.firstWhere((t) => t.id == id);
    } catch (_) {
      return null;
    }
  }
}

// ─── Модель записи ────────────────────────────────────────────────────────────

class NoteEntry implements BaseEntry {
  @override
  final DateTime date;
  final String note;

  /// Если заметка создана по предустановленному симптому — его id, иначе null.
  final String? symptomId;

  NoteEntry({
    required this.date,
    required this.note,
    this.symptomId,
  });

  SymptomTag? get symptomTag =>
      symptomId != null ? SymptomTags.byId(symptomId!) : null;

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      date: DateTime.parse(json['date']),
      note: json['note'],
      symptomId: json['symptomId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'note': note,
        if (symptomId != null) 'symptomId': symptomId,
      };
}

class NoteHistory extends History<NoteEntry> {
  NoteHistory({required super.entries});
  NoteHistory.empty() : super.empty();

  void addNote(String text, {String? symptomId}) {
    final entry = NoteEntry(
      date: DateTime.now(),
      note: text,
      symptomId: symptomId,
    );
    add(entry);
  }

  static final noteSerializer = HistorySerializer<NoteEntry>(
    fromJson: NoteEntry.fromJson,
  );
}
