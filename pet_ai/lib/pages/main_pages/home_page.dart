import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/events_preview_block.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';
import 'package:pet_ai/pages/secondary_pages/profile_page.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_scrollable_sheet.dart';
import 'package:pet_ai/theme/widgets/health_action_button.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenCalendar;
  final ValueChanged<DateTime> onOpenCalendarByEvent;
  final VoidCallback? onProfileSwitched;

  const HomePage({
    super.key,
    required this.onOpenCalendar,
    required this.onOpenCalendarByEvent,
    this.onProfileSwitched,
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
    _initScreen();
  }

  Future<void> _initScreen() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingEvents = true;
    });

    final profile = await ProfileService().loadActiveProfile();

    if (profile == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/registration');
      } else {
        throw Exception("Failed navigate to registration flow");
      }
      return; // прерываем — дальше работать не с чем
    }

    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });

    // Профиль есть — загружаем события
    final events = await EventService().loadEvents(profile.id);

    if (!mounted) return;

    setState(() {
      _events = events
          .where(
            (e) =>
        e.dateTime.isAfter(DateTime.now()) ||
            e.dateTime.isAtSameMomentAs(DateTime.now()),
      )
          .toList()
        ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
      _isLoadingEvents = false;
    });
  }

  String _profileDescription() {
    String description = _profile?.breed ?? "";
    if (_profile != null && _profile!.birthDate != null) {
      final duration = _profile!.birthDate!.difference(DateTime.now());
      return '$description - ${formatPetAge(duration)}';
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
      await _initScreen();
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
      await _initScreen();
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
      await _initScreen();
    }
  }

  void _openNotes(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,

      builder: (_) => UpdateNotesModal(profile: _profile!),
    );

    if (updated == true) {
      await _initScreen();
    }
  }

  void _openProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetProfilePage()),
    );
    await _initScreen();
  }

  void _showProfileSwitcher(BuildContext context) async {
    final profiles = await ProfileService().loadAllProfiles();
    final activeId = _profile?.id;

    if (!mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ProfileSwitcherSheet(
        profiles: profiles,
        activeId: activeId,
      ),
    );

    if (result == null) return;

    if (result == '__create_new__') {
      if (mounted) {
        await Navigator.pushNamed(context, '/registration');
        // After returning from registration, refresh
        widget.onProfileSwitched?.call();
      }
    } else {
      await ProfileService().setActiveProfile(result);
      widget.onProfileSwitched?.call();
      await _initScreen();
    }
  }

  @override
  Widget build(BuildContext context) {
    final description = _profileDescription();
    final topPadding = MediaQuery.of(context).padding.top;
    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: pageGradientDecoration,
        child: ListView(
            padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
            children: [
                Row(
                  children: [
                    GestureDetector(
                      onTap: () => _showProfileSwitcher(context),
                      child: InlineLoading(
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
      );
  }
}

// ─── Profile Switcher Bottom Sheet ─────────────────────────────────────────

class _ProfileSwitcherSheet extends StatelessWidget {
  final List<PetProfile> profiles;
  final String? activeId;

  const _ProfileSwitcherSheet({
    required this.profiles,
    required this.activeId,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: ThemeColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.grey.shade400,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Text(
            'Профили питомцев',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),

          ...profiles.map((profile) {
            final isActive = profile.id == activeId;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: GlassPlate(
                color: isActive ? ThemeColors.primary : Colors.white,
                child: ListTile(
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: isActive
                        ? Colors.white.withAlpha(77)
                        : ThemeColors.primary.withAlpha(38),
                    backgroundImage: profile.profileImage != null
                        ? FileImage(profile.profileImage!)
                        : null,
                    child: profile.profileImage == null
                        ? Icon(
                            Icons.pets,
                            size: 20,
                            color: isActive ? Colors.white : ThemeColors.primary,
                          )
                        : null,
                  ),
                  title: Text(
                    profile.name.isEmpty ? 'Без имени' : profile.name,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isActive ? Colors.white : ThemeColors.textPrimary,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                  subtitle: Text(
                    profile.breed.isEmpty ? profile.species.name : profile.breed,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: isActive
                          ? Colors.white.withAlpha(204)
                          : ThemeColors.textPrimary.withAlpha(153),
                    ),
                  ),
                  trailing: isActive
                      ? const Icon(Icons.check_circle, color: Colors.white)
                      : null,
                  onTap: isActive
                      ? () => Navigator.pop(context)
                      : () => Navigator.pop(context, profile.id),
                ),
              ),
            );
          }),

          const SizedBox(height: 8),

          SizedBox(
            width: double.infinity,
            child: GlassCard(
              callback: () => Navigator.pop(context, '__create_new__'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.add_circle_outline, color: ThemeColors.primary),
                    const SizedBox(width: 8),
                    Text(
                      'Добавить питомца',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: ThemeColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
