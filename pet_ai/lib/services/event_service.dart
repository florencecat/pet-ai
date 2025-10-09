import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PetEvent {
  final String name;
  final String category;
  final DateTime dateTime;

  PetEvent({
    required this.name,
    required this.category,
    required this.dateTime,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'category': category,
    'dateTime': dateTime.toIso8601String(),
  };

  factory PetEvent.fromJson(Map<String, dynamic> json) => PetEvent(
    name: json['name'],
    category: json['category'],
    dateTime: DateTime.parse(json['dateTime']),
  );
}

class EventService {
  static const _key = 'pet_events';

  Future<List<PetEvent>> loadEvents() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(_key) ?? [];
    return data.map((e) => PetEvent.fromJson(jsonDecode(e))).toList();
  }

  Future<void> saveEvent(PetEvent event) async {
    final prefs = await SharedPreferences.getInstance();
    final events = await loadEvents();
    events.add(event);
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_key, encoded);
  }
}
