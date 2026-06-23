import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';

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
    id: 'lb18x8wz0uav3zs',
    label: 'Рвота',
    icon: Icons.sick_outlined,
    colorValue: 0xFFE53935,
  );
  static const diarrhea = SymptomTag(
    id: '65invddq8bmt3fm',
    label: 'Жидкий стул',
    icon: Icons.warning_amber_rounded,
    colorValue: 0xFFFF8F00,
  );
  static const refusedFood = SymptomTag(
    id: '2zxi8jlzyh649wm',
    label: 'Отказ от еды',
    icon: Icons.no_food_outlined,
    colorValue: 0xFFF57F17,
  );
  static const lethargy = SymptomTag(
    id: 'woakc6ce2ka3d41',
    label: 'Вялость',
    icon: Icons.bedtime_outlined,
    colorValue: 0xFF1565C0,
  );
  static const sneezing = SymptomTag(
    id: '1hk0ae4mfip81xu',
    label: 'Чихание',
    icon: Icons.air_outlined,
    colorValue: 0xFF6A1B9A,
  );
  static const coughing = SymptomTag(
    id: '6xstbg23me36gxw',
    label: 'Кашель',
    icon: Icons.masks_outlined,
    colorValue: 0xFF558B2F,
  );
  static const scratching = SymptomTag(
    id: '0at5r8rjmubktl7',
    label: 'Расчёсывается',
    icon: Icons.touch_app_outlined,
    colorValue: 0xFF00838F,
  );
  static const limping = SymptomTag(
    id: 'qsjy1av39qa33xq',
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
  static const codec = _NoteEntryCodec();

  @override
  final String id;
  @override
  final DateTime date;
  final String note;

  /// Если заметка создана по предустановленному симптому — его id, иначе null.
  final String? symptomId;

  NoteEntry({
    String? id,
    required this.date,
    required this.note,
    this.symptomId,
  }) : id = id ?? generateId();

  SymptomTag? get symptomTag =>
      symptomId != null ? SymptomTags.byId(symptomId!) : null;

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      id: json['id'] as String?,
      date: DateTime.parse(json['date']),
      note: json['note'],
      symptomId: json['symptomId'] as String?,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toIso8601String(),
    'note': note,
    if (symptomId != null) 'symptomId': symptomId,
  };

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'pet': ownerId,
    'date': date.toIso8601String(),
    'note': note,
    if (symptomId != null) 'symptom': symptomId,
  };
}

class _NoteEntryCodec extends PbCodec<NoteEntry> {
  const _NoteEntryCodec();

  @override
  NoteEntry fromPocketBase(Map<String, dynamic> data) => NoteEntry(
    id: data['id'] as String?,
    date: DateTime.parse(data['date'] as String),
    note: data['note'] as String,
    symptomId: data['symptom'] as String?,
  );
}

class NoteHistory extends History<NoteEntry> {
  NoteHistory({required super.entries});
  NoteHistory.empty() : super.empty();

  Future<void> addNote(String text, {String? symptomId}) async {
    final date = DateTime.now();
    final entry = NoteEntry(date: date, note: text, symptomId: symptomId);
    add(entry);

    final profileId = await PetService().getActiveProfileId();
    if (profileId != null) {
      final eventFromNote = Event.fromNote(
        name: text,
        dateTime: date,
        symptomTag: symptomId,
      );
      eventFromNote.petIds.add(profileId);
      await EventService().createEvent(eventFromNote);
    } else if (kDebugMode) {
      print('addNote: failed to get active profileId');
    }
  }

  static final noteSerializer = HistorySerializer<NoteEntry>(
    fromJson: NoteEntry.fromJson,
  );
}
