import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/events_preview_block.dart';
import 'dart:core';

import '../secondary_pages/profile_page.dart';
import '../../../services/event_service.dart';
import '../../../theme/app_colors.dart';
import '../../../theme/widgets/draggable_scrollable_sheet.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenCalendar;
  final ValueChanged<DateTime> onOpenCalendarByEvent;

  const HomePage({
    super.key,
    required this.onOpenCalendar,
    required this.onOpenCalendarByEvent,
  });

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  PetEvent? _upcomingStarredEvent;
  PetProfile _profile = PetProfile();

  bool _isLoadingEvents = true;
  List<PetEvent> _events = [];

  @override
  void initState() {
    super.initState();
    _loadEvents();
    _loadProfile();
  }

  Future<void> _loadEvents() async {
    setState(() {
      _isLoadingEvents = true;
    });
    final events = await EventService().loadEvents();
    setState(() {
      _events = events
          .where(
            (e) =>
                e.dateTime.isAfter(DateTime.now()) ||
                e.dateTime.isAtSameMomentAs(DateTime.now()),
          )
          .toList();
      if (events.length > 1) {
        events.sort((a, b) => a.dateTime.compareTo(b.dateTime));
      }
      _upcomingStarredEvent = _events
          .where((e) => e.starred == true)
          .firstOrNull;
    });
    _isLoadingEvents = false;
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
    final description = _profileDescription();
    return Padding(
      padding: const EdgeInsets.all(16),
      child: ListView(
        children: [
          // хэдер профиля
          Row(
            children: [
              Expanded(
                flex: 1,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Theme.of(context).dividerColor,
                    ),
                    child: CircleAvatar(
                      radius: 36,
                      backgroundColor: Theme.of(
                        context,
                      ).scaffoldBackgroundColor,
                      backgroundImage: _profile.profileImage != null
                          ? FileImage(_profile.profileImage!)
                          : null,
                      child: _profile.profileImage == null
                          ? const Icon(
                              Icons.pets_outlined,
                              size: 36,
                              color: ThemeColors.border,
                            )
                          : Image.file(_profile.profileImage!),
                    ),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Card.outlined(
                  shape: cardBorder,
                  clipBehavior: Clip.antiAliasWithSaveLayer,
                  child: InkWell(
                    splashColor: Theme.of(context).splashColor,
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
                      child: InlineLoading(
                        isLoading: _isLoadingEvents,
                        child: ListTile(
                          title: Text(
                            _profile.name.isEmpty
                                ? "Загружаем..."
                                : _profile.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          subtitle: Text(
                            description.isEmpty
                                ? "Здесь будет имя и порода..."
                                : description,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
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
              splashColor: Theme.of(context).splashColor,
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: InlineLoading(
                  isLoading: _isLoadingEvents,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Здоровье',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 8),
                      Text('Последний осмотр: 10.09.2025', style: Theme.of(context).textTheme.bodySmall,),
                      Text('Активность: высокая', style: Theme.of(context).textTheme.bodySmall),
                      Text(
                        _profile.weightKg == null
                            ? ''
                            : '${_profile.weightKg!.toInt().toString()} кг',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
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
                  child: Text(
                    'Обновить вес',
                    style: Theme.of(context).textTheme.bodySmall,
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
                  child: Text(
                    'Заметка',
                    style: Theme.of(context).textTheme.bodySmall,
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
                  child: Text(
                    'Сводка',
                    style: Theme.of(context).textTheme.bodySmall,
                    textAlign: TextAlign.center,
                  ),
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
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.star_border_rounded,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary.withAlpha(128),
                    ),
                    SizedBox(width: 8),
                    Text(
                      'Нет ближайших важных событий',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary.withAlpha(128),
                        fontSize: 16,
                      ),
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
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: ThemeColors.border,
                onPressed: widget.onOpenCalendar,
              ),
            ],
          ),
          const SizedBox(height: 8),

          InlineLoading(
            isLoading: _isLoadingEvents,
            child: EventPreviewBlock(
              events: _events,
              onTap: (event) => _openEventSheet(context, event),
              onOpenCalendar: widget.onOpenCalendarByEvent,
            ),
          ),
        ],
      ),
    );
  }
}
