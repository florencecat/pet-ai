import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_service.dart';

enum RepeatInterval { none, daily, weekly, monthly }

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
    icon: Icons.pets,
  );

  static const health = EventCategory(
    id: 'health',
    name: 'Здоровье',
    description: 'Визиты к врачу, прививки',
    colorValue: 0xFFE53935,
    icon: Icons.medical_information,
  );

  static const grooming = EventCategory(
    id: 'grooming',
    name: 'Груминг',
    description: 'Стрижка, купание',
    colorValue: 0xFF1E88E5,
    icon: Icons.wash,
  );

  static const food = EventCategory(
    id: 'food',
    name: 'Питание',
    description: 'Кормление, добавки',
    colorValue: 0xFF43A047,
    icon: Icons.feed,
  );

  static const all = [empty, health, grooming, food];

  static EventCategory byId(String id) {
    return all.firstWhere((c) => c.id == id);
  }
}

class PetEvent {
  final String id;
  String name;
  EventCategory category;
  DateTime dateTime;
  bool starred;
  RepeatInterval repeat;
  int remindBeforeMinutes;

  PetEvent({required this.name, required this.category, required this.dateTime, this.repeat = RepeatInterval.none, this.remindBeforeMinutes = 0})
    : id = UniqueKey().toString(),
      starred = false;

  PetEvent.deserialize({
    required this.id,
    required this.name,
    required this.category,
    required this.dateTime,
    required this.starred,
    required this.repeat,
    required this.remindBeforeMinutes,
  });

  PetEvent.empty()
    : id = UniqueKey().toString(),
      name = "",
      category = EventCategories.empty,
      dateTime = DateTime.now(),
      starred = false,
      repeat = RepeatInterval.none,
      remindBeforeMinutes = 0;

  void assign(
    String? name,
    EventCategory? category,
    DateTime? dateTime,
    RepeatInterval? repeat,
    int? remindBeforeMinutes
  ) {
    this.name = name ?? this.name;
    this.category = category ?? this.category;
    this.dateTime = dateTime ?? this.dateTime;
    this.repeat = repeat ?? this.repeat;
    this.remindBeforeMinutes = remindBeforeMinutes ?? this.remindBeforeMinutes;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'category': category.id,
    'dateTime': dateTime.toIso8601String(),
    'starred': starred,
    'repeat': repeat.index,
    'remindBeforeMinutes': remindBeforeMinutes,
  };

  factory PetEvent.fromJson(Map<String, dynamic> json) => PetEvent.deserialize(
    id: json['id'],
    name: json['name'],
    category: EventCategories.byId(json['category']),
    dateTime: DateTime.parse(json['dateTime']),
    starred: json['starred'],
    repeat: RepeatInterval.values[json['repeat'] ?? 0],
    remindBeforeMinutes: json['remindBeforeMinutes'] ?? 0,
  );
}

class EventService {
  static const _eventKey = 'pet_events';

  Future<List<PetEvent>> loadEvents() async {
    final data = await SharedPreferencesAsync().getStringList(_eventKey) ?? [];
    return data.map((e) => PetEvent.fromJson(jsonDecode(e))).toList();
  }

  Future<void> createEvent(PetEvent event) async {
    final events = await loadEvents();
    events.add(event);
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_eventKey, encoded);

    await NotificationService().scheduleEventNotification(event);
  }

  Future<void> saveEvent(PetEvent event) async {
    final events = await loadEvents();
    final index = events.indexWhere((e) => e.id == event.id);
    if (index < 0) return;

    events[index] = event;
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_eventKey, encoded);

    await NotificationService().cancelNotification(event.id);
    await NotificationService().scheduleEventNotification(event);
  }

  Future<void> deleteEvent(PetEvent event) async {
    final events = await loadEvents();
    events.removeWhere((e) => e.id == event.id);
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_eventKey, encoded);

    await NotificationService().cancelNotification(event.id);
  }

  Future<void> clearEvents() async {
    final events = await loadEvents();
    for (var event in events) {
      await NotificationService().cancelNotification(event.id);
    }
    await SharedPreferencesAsync().remove(_eventKey);
  }
}

class NoteModal extends StatelessWidget {
  const NoteModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Заметка", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 20),
          const Text("Функция появится позже."),
        ],
      ),
    );
  }
}
