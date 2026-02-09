import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetEvent {
  final String? id;
  String name;
  String category;
  DateTime dateTime;

  PetEvent({required this.name, required this.category, required this.dateTime})
    : id = UniqueKey().toString();

  PetEvent.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
  });

  PetEvent.empty() : id = UniqueKey().toString(), name = "", category = "", dateTime = DateTime.now();

  void assign(String? name, String? category, DateTime? dateTime)
  {
    this.name = name ?? this.name;
    this.category = category ?? this.category;
    this.dateTime = dateTime ?? this.dateTime;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category,
    'dateTime': dateTime.toIso8601String(),
  };

  factory PetEvent.fromJson(Map<String, dynamic> json) => PetEvent.deserialize(
    id: json['id'],
    name: json['name'],
    category: json['category'],
    dateTime: DateTime.parse(json['dateTime']),
  );
}

class EventService {
  static const _key = 'pet_events';

  Future<List<PetEvent>> loadEvents() async {
    final data = await SharedPreferencesAsync().getStringList(_key) ?? [];
    return data.map((e) => PetEvent.fromJson(jsonDecode(e))).toList();
  }

  Future<void> createEvent(PetEvent event) async {
    final events = await loadEvents();
    events.add(event);
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_key, encoded);
  }

  Future<void> saveEvent(PetEvent event) async {
    final events = await loadEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index < 0) return;

    events[index] = event;
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_key, encoded);
  }

  Future<void> deleteEvent(PetEvent event) async {
    final events = await loadEvents();
    events.removeWhere((e) => e.id == event.id);
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_key, encoded);
  }

  Future<void> clearEvents() async {
    await SharedPreferencesAsync().remove(_key);
  }
}
