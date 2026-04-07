import 'package:pet_ai/models/history.dart';

class NoteEntry implements BaseEntry {
  @override
  final DateTime date;
  final String note;

  NoteEntry({
    required this.date,
    required this.note,
  });

  factory NoteEntry.fromJson(Map<String, dynamic> json) {
    return NoteEntry(
      date: DateTime.parse(json["date"]),
      note: json["note"],
    );
  }

  @override
  Map<String, dynamic> toJson() => {
    "date": date.toIso8601String(),
    "note": note,
  };
}

class NoteHistory extends History<NoteEntry> {
  NoteHistory({required super.entries});
  NoteHistory.empty() : super.empty();

  void addNote(String text) {
    final entry = NoteEntry(date: DateTime.now(), note: text);
    add(entry);
  }

  static final noteSerializer = HistorySerializer<NoteEntry>(
    fromJson: NoteEntry.fromJson,
  );
}