import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'dart:core';

import '../secondary_pages/profile_page.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_styles.dart';
import '../../../theme/widgets/draggable_scrollable_sheet.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenCalendar;

  const HomePage({super.key, required this.onOpenCalendar});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<PetEvent> _events = [];
  PetEvent? _upcomingStarredEvent;
  PetProfile _profile = PetProfile();

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadProfile();
  }

  Future<void> _loadEvents() async {
    final events = await EventService().loadEvents();
    if (events.length > 1) {
      events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
    }
    setState(() {
      _events = events;
      _upcomingStarredEvent = _events
          .where((e) => e.starred == true)
          .firstOrNull;
    });
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

  void eventSheetCallback() async {
    await _loadEvents();
    setState(() {});
  }

  void _openEventSheet(BuildContext context, PetEvent event) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventDraggableSheet(event: event),
    );

    if (updated == true) {
      await _loadEvents();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // хэдер профиля
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
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: InkWell(
                    splashColor: Colors.blue.withAlpha(50),
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const PetProfilePage(),
                        ),
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

          // блок здоровья
          Card.outlined(
            shape: cardBorder,
            clipBehavior: Clip.antiAliasWithSaveLayer,
            child: InkWell(
              splashColor: Colors.blue.withAlpha(50),
              onTap: () {},
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
                    Text(
                      _profile.weightKg == null
                          ? ''
                          : '${_profile.weightKg!.toInt().toString()} кг',
                    ),
                    const Text('Активность: высокая'),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // быстрые действия
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
                  child: const Text('Заметка', textAlign: TextAlign.center),
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

          // ближайшее важное напоминание
          if (_upcomingStarredEvent != null)
            Card.outlined(
              shape: cardBorder,
              clipBehavior: Clip.antiAliasWithSaveLayer,
              child: InkWell(
                splashColor: Colors.blue.withAlpha(50),
                onTap: () {
                  debugPrint('Card tapped.');
                },
                child: Padding(
                  padding: EdgeInsetsGeometry.all(4),
                  child: ListTile(
                    leading: Icon(
                      _upcomingStarredEvent!.category.icon,
                      color: _upcomingStarredEvent!.category.color,
                    ),
                    title: Text(_upcomingStarredEvent!.name),
                    subtitle: Text(
                      DateFormat(
                        'dd.MM.yyyy – HH:mm',
                      ).format(_upcomingStarredEvent!.dateTime),
                    ),
                    trailing: IconButton(
                      onPressed: () {},
                      icon: Icon(Icons.notifications_active_outlined),
                    ),
                  ),
                ),
              ),
            )
          else
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.05,
              child: const Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 18,
                      color: secondaryColor,
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Нет ближайших важных событий',
                      style: TextStyle(color: secondaryColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),

          // ближайшие события
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
          if (_events.isEmpty)
            SizedBox(
              height: MediaQuery.of(context).size.height * 0.35,
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.pets_sharp, size: 72, color: secondaryColor),
                    SizedBox(height: 12),
                    Text(
                      'Нет запланированных событий',
                      style: TextStyle(color: secondaryColor, fontSize: 16),
                    ),
                  ],
                ),
              ),
            ),
          if (_events.isNotEmpty)
            Card.outlined(
              shape: cardBorder,
              child: Column(
                children: _events
                    .where(
                      (e) =>
                          e.dateTime.isAfter(DateTime.now()) ||
                          e.dateTime.isAtSameMomentAs(DateTime.now()),
                    )
                    .take(4)
                    .map((event) {
                      return Column(
                        children: [
                          ListTile(
                            leading: Icon(
                              event.category.icon,
                              color: event.category.color,
                            ),
                            title: Text(event.name),
                            subtitle: Text(
                              DateFormat(
                                'dd.MM.yyyy – HH:mm',
                              ).format(event.dateTime),
                            ),
                            trailing: IconButton(
                              onPressed: () => _openEventSheet(context, event),
                              icon: Icon(Icons.chevron_right),
                            ),
                          ),
                          if (event != _events.last) const Divider(height: 0),
                        ],
                      );
                    })
                    .toList(),
              ),
            ),
        ],
      ),
    );
  }
}
