import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/events_preview_block.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';
import 'dart:core';

import 'package:pet_ai/pages/secondary_pages/profile_page.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_scrollable_sheet.dart';
import 'package:pet_ai/theme/widgets/health_action_button.dart';

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
  PetProfile? _profile;

  bool _isLoadingProfile = true;
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
    });
    _isLoadingEvents = false;
  }

  Future<void> _loadProfile() async {
    setState(() {
      _isLoadingProfile = true;
    });
    final profile = await ProfileService().loadProfile();
    if (profile != null) {
      setState(() {
        _isLoadingProfile = false;
        _profile = profile;
      });
    } else if (Navigator.of(context).mounted) {
      if (kDebugMode) print("Failed to load profile");
      Navigator.of(context).pushReplacementNamed('/registration');
    } else {
      throw Exception("Failed navigate to registration flow");
    }
  }

  String _profileDescription() {
    String description = _profile?.breed ?? "";
    if (_profile != null && _profile!.birthDate != null) {
      final duration = _profile!.birthDate?.difference(DateTime.now());
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

  void _openWeightHistory(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => UpdateWeightModal(profile: _profile!),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  void _openMoodHistory(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      builder: (_) => UpdateMoodModal(profile: _profile!),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  void _openNotes(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,

      builder: (_) => UpdateNotesModal(),
    );

    if (updated == true) {
      await _loadProfile();
    }
  }

  void _openProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetProfilePage()),
    );
    await _loadProfile();
  }

  @override
  Widget build(BuildContext context) {
    final description = _profileDescription();
    return SafeArea(
      child: Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            tileMode: TileMode.mirror,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              ThemeColors.gradientBegin.withAlpha(96),
              ThemeColors.gradientEnd.withAlpha(64),
            ],
          ),
        ),
        child: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Row(
                  children: [
                    InlineLoading(
                      isLoading: _isLoadingProfile,
                      child: CircleAvatar(
                        radius: 42,
                        backgroundColor: Colors.white.withValues(alpha: 0.3),
                        child: _profile?.profileImage == null
                            ? const Icon(
                                Icons.pets,
                                size: 40,
                                color: Colors.white,
                              )
                            : CircleAvatar(
                                radius: 40,
                                backgroundImage: FileImage(
                                  _profile!.profileImage!,
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(width: 16),

                    Expanded(
                      flex: 3,
                      child: GlassCard(
                        callback: () => _openProfile(context),
                        child: Center(
                          child: InlineLoading(
                            isLoading: _isLoadingProfile,
                            child: ListTile(
                              title: Row(children: [
                                if (_profile != null && _profile!.gender.icon != null)
                                  Icon(_profile!.gender.icon, color: ThemeColors.textPrimary),
                                const SizedBox(width: 3),
                                Text(
                                  _profile == null || _profile!.name.isEmpty
                                      ? "Загружаем..."
                                      : _profile!.name,
                                  style: Theme.of(context).textTheme.titleLarge,
                                )
                              ]),
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
                  ],
                ),

                const SizedBox(height: 16),

                // блок здоровья
                GlassCard(
                  callback: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      builder: (_) => const HealthSummaryModal(),
                    );
                  },
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      InlineLoading(
                        isLoading: _isLoadingProfile,
                        child: Padding(
                          padding: EdgeInsetsGeometry.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Здоровье',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Последний осмотр: 10.09.2025',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                'Активность: высокая',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                              Text(
                                _profile?.weightHistory.lastWeight == null
                                    ? 'Вес не зафиксирован'
                                    : '${_profile?.weightHistory.lastWeight.toString()} кг',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),

                      // быстрые действия
                      Padding(
                        padding: EdgeInsetsGeometry.only(left: 8, right: 8),
                        child: Row(
                          children: [
                            Expanded(
                              child: HealthActionButton(
                                icon: Icons.monitor_weight_outlined,
                                label: 'Вес',
                                onPressed: () => _openWeightHistory(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HealthActionButton(
                                icon: Icons.mood_outlined,
                                label: 'Настроение',
                                onPressed: () => _openMoodHistory(context),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: HealthActionButton(
                                icon: Icons.note_alt_outlined,
                                label: 'Заметка',
                                onPressed: () => _openNotes(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Ближайшие события',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    GlassCard(
                      callback: widget.onOpenCalendar,
                      child: Icon(
                        Icons.add_circle_outline,
                        color: ThemeColors.primary,
                      ),
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
          ),
        ),
      ),
    );
  }
}
