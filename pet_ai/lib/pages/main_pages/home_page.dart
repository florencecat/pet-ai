import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'dart:core';

import '../secondary_pages/profile_page.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_styles.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenCalendar;

  const HomePage({super.key, required this.onOpenCalendar});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PetEvent> _events = [];
  PetProfile _profile = PetProfile();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadProfile();
  }

  Future<void> _loadEvents() async {
    final events = await EventService().loadEvents();
    events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    setState(() => _events = events);
  }

  Future<void> _loadProfile() async {
    _profile = await ProfileService().loadProfile();
  }

  String _profileDescription() {
    String description = _profile.breed;
    if (_profile.birthDate != null) {
      final duration = _profile.birthDate?.difference(DateTime.now());
      if (duration == null) {
        return description;
      } else {
        return '$description - ${ProfileService().formatAge(duration)}';
      }
    }
    return description;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [

          Row(
            children: [
              Expanded(
                flex: 1,
                child: const Icon(
                  Icons.pets_outlined,
                  size: 40,
                  color: Colors.teal,
                ),
              ),
              Expanded(
                flex: 3,
                child: Card.outlined(
                  shape: cardBorder,
                  clipBehavior: Clip.antiAlias,
                  child: InkWell(
                    splashColor: Colors.blue.withAlpha(50),
                    onTap: () async {
                      final added = await Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const PetProfilePage()),
                      );
                    },
                    child: Padding(
                      padding: EdgeInsetsGeometry.all(5),
                      child: ListTile(
                        title: Text(
                          _profile.name,
                          style: Theme.of(context).textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w500),
                        ),
                        subtitle: Text(_profileDescription()),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // --- Карточка со здоровьем (улучшенная) ---
          Card.outlined(
            shape: cardBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: Colors.blue.withAlpha(50),
              onTap: () {
                debugPrint('Card tapped.');
              },
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Здоровье',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text('Последний осмотр: 10.09.2025'),
                    Text('${_profile.weightKg!.toInt().toString()} кг'),
                    const Text('Активность: высокая'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // --- Кнопки действий ---
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // TODO: реализовать обновление веса
                  },
                  child: const Text(
                    'Обновить вес',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24, child: VerticalDivider(thickness: 1)),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // TODO: первая заглушка
                  },
                  child: const Text(
                    'Добавить заметку',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              const SizedBox(height: 24, child: VerticalDivider(thickness: 1)),
              Expanded(
                child: TextButton(
                  onPressed: () {
                    // TODO: вторая заглушка
                  },
                  child: const Text('Сводка', textAlign: TextAlign.center),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          Card.outlined(
            shape: cardBorder,
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              splashColor: Colors.blue.withAlpha(50),
              onTap: () {
                debugPrint('Card tapped.');
              },
              child: Padding(
                padding: EdgeInsetsGeometry.all(4),
                child: ListTile(
                  title: const Text('Напоминания'),
                  subtitle: const Text('Следующая вакцина: 15.10.2025'),
                  trailing: IconButton(
                    onPressed: () {},
                    icon: Icon(Icons.notifications_active_outlined),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Ближайшие события',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.teal.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                onPressed: widget.onOpenCalendar,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (_events.isEmpty) const Text('Нет запланированных событий.'),
          if (_events.isNotEmpty)
            Card.outlined(
              shape: cardBorder,
              child: Column(
                children: _events.take(3).map((event) {
                  final formattedDate = DateFormat(
                    'dd.MM.yyyy – HH:mm',
                  ).format(event.dateTime);
                  return Column(
                    children: [
                      ListTile(
                        leading: const Icon(Icons.event, color: Colors.teal),
                        title: Text(event.name),
                        subtitle: Text(formattedDate),
                        trailing: IconButton(
                          onPressed: () {},
                          icon: Icon(Icons.chevron_right),
                        ),
                      ),
                      if (event != _events.last) const Divider(height: 0),
                    ],
                  );
                }).toList(),
              ),
            ),
        ],
      ),
    );
  }
}