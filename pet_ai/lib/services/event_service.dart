import 'dart:convert';
import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class EventCategory {
  final String id;
  final String name;
  final String description;
  final int colorValue;
  final IconData icon;

  const EventCategory({
    required this.id,
    required this.name,
    required this.description,
    required this.colorValue,
    required this.icon,
  });

  Color get color => Color(colorValue);
}

class EventCategories {
  static const empty = EventCategory(
    id: 'empty',
    name: '',
    description: '',
    colorValue: 0,
    icon: Icons.pets
  );

  static const health = EventCategory(
    id: 'health',
    name: 'Здоровье',
    description: 'Визиты к врачу, прививки',
    colorValue: 0xFFE53935,
    icon: Icons.medical_information
  );

  static const grooming = EventCategory(
    id: 'grooming',
    name: 'Груминг',
    description: 'Стрижка, купание',
    colorValue: 0xFF1E88E5,
    icon: Icons.wash
  );

  static const food = EventCategory(
    id: 'food',
    name: 'Питание',
    description: 'Кормление, добавки',
    colorValue: 0xFF43A047,
    icon: Icons.feed
  );

  static const all = [
    empty,
    health,
    grooming,
    food,
  ];

  static EventCategory byId(String id) {
    return all.firstWhere((c) => c.id == id);
  }
}

class PetEvent {
  final String id;
  String name;
  EventCategory category;
  DateTime dateTime;

  PetEvent({required this.name, required this.category, required this.dateTime})
    : id = UniqueKey().toString();

  PetEvent.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
  });

  PetEvent.empty() : id = UniqueKey().toString(), name = "", category = EventCategories.empty, dateTime = DateTime.now();

  void assign(String? name, EventCategory? category, DateTime? dateTime)
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
