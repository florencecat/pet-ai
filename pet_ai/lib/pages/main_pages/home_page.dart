import 'package:flutter/material.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/mood_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/note_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/weight_sheet.dart';
import 'package:pet_ai/theme/widgets/events_preview_block.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:pet_ai/pages/secondary_pages/profile_page.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/file_upload_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/files_history_sheet.dart';
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
  bool? _multipleProfiles;

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
      return;
    }

    final multipleProfiles = await ProfileService().hasMultipleProfiles();

    setState(() {
      _profile = profile;
      _multipleProfiles = multipleProfiles;
      _isLoadingProfile = false;
    });

    final events = await EventService().loadEvents(profile.id);

    if (!mounted) return;

    final now = DateTime.now();

    // Просроченные: не повторяющиеся, дата в прошлом, не выполнены
    final overdue = events.where((e) => e.isOverdue).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime)); // свежие сначала

    // Предстоящие: повторяющиеся или дата ≥ сейчас
    final upcoming =
        events
            .where(
              (e) =>
                  e.repeat != RepeatInterval.none ||
                  e.dateTime.isAfter(now) ||
                  e.dateTime.isAtSameMomentAs(now),
            )
            .toList()
          ..sort((a, b) => a.dateTime.compareTo(b.dateTime));

    setState(() {
      _events = [...overdue, ...upcoming];
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

  /// Компактная сводка из 1–2 наиболее важных бейджей здоровья
  /// для отображения в карточке «Здоровье» на главной.
  List<Widget> _buildHealthSummary() {
    if (_profile == null) return const [];

    final badges = HealthAnalyzer.analyze(_profile!, _events);
    // Сортируем по убыванию серьёзности
    badges.sort((a, b) => b.severity.index.compareTo(a.severity.index));
    final top = badges.take(3).toList();

    return top
        .map(
          (b) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                GlassBadge(
                  icon: Icon(
                    b.icon ?? b.severity.icon,
                    size: 16,
                    color: b.severity.color,
                  ),
                  name: b.title,
                  color: b.severity.color,
                ),
              ],
            ),
          ),
        )
        .toList();
  }

  void _openEventSheet(BuildContext context, PetEvent event) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event),
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
      backgroundColor: Colors.transparent,
      builder: (_) => WeightSheet(profile: _profile!),
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
      backgroundColor: Colors.transparent,
      builder: (_) => MoodSheet(profile: _profile!),
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
      backgroundColor: Colors.transparent,
      builder: (_) => NoteSheet(profile: _profile!),
    );

    if (updated == true) {
      await _initScreen();
    }
  }

  void _openFileUpload(BuildContext context) async {
    final uploaded = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FileUploadSheet(),
    );
    if (uploaded == true) await _initScreen();
  }

  void _openFilesHistory(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FilesHistorySheet(),
    );
    await _initScreen();
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

    if (!context.mounted) return;

    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) =>
          _ProfileSwitcherSheet(profiles: profiles, activeId: activeId),
    );

    if (result == null) return;

    if (result == '__create_new__') {
      if (context.mounted) {
        await Navigator.pushNamed(context, '/registration');
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
    final profileColor = _profile?.color ?? ThemeColors.primary;

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
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(3),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: profileColor, width: 2.5),
                            boxShadow: [
                              BoxShadow(
                                color: profileColor.withAlpha(80),
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: CircleAvatar(
                            radius: 37,
                            backgroundColor: Colors.white.withValues(
                              alpha: 0.3,
                            ),
                            child: _profile?.profileImage == null
                                ? const Icon(
                                    Icons.pets,
                                    size: 38,
                                    color: Colors.white,
                                  )
                                : CircleAvatar(
                                    radius: 38,
                                    backgroundImage: FileImage(
                                      _profile!.profileImage!,
                                    ),
                                  ),
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 0,
                          child: Container(
                            width: 22,
                            height: 22,
                            decoration: BoxDecoration(
                              color: profileColor,
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                            ),
                            child: Icon(
                              _multipleProfiles == true
                                  ? Icons.expand_more_rounded
                                  : Icons.add,
                              size: 14,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ],
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
                          title: Row(
                            children: [
                              if (_profile != null &&
                                  _profile!.gender.icon != null)
                                Icon(
                                  _profile!.gender.icon,
                                  color: ThemeColors.textPrimary,
                                ),
                              const SizedBox(width: 3),
                              Text(
                                _profile == null || _profile!.name.isEmpty
                                    ? "Загружаем..."
                                    : _profile!.name,
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                            ],
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
              ],
            ),

            const SizedBox(height: 16),

            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: GlassCard(
                    callback: () => _openFilesHistory(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsetsGeometry.all(10),
                          child: Column(
                            spacing: 6,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Файлы',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Документы, справки и другое',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: HomeActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Добавить',
                            onPressed: () => _openFileUpload(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GlassCard(
                    callback: () => _openFilesHistory(context),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: EdgeInsetsGeometry.all(10),
                          child: Column(
                            spacing: 6,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Заметка',
                                style: Theme.of(context).textTheme.titleLarge,
                              ),
                              Text(
                                'Зафиксируйте важное событие',
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: HomeActionButton(
                            icon: Icons.note_add_outlined,
                            label: 'Записать',
                            onPressed: () => _openNotes(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // блок здоровья
            GlassCard(
              callback: () async {
                await showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  enableDrag: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const HealthSummaryModal(),
                );
                await _initScreen();
              },
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InlineLoading(
                    isLoading: _isLoadingProfile || _isLoadingEvents,
                    child: Padding(
                      padding: EdgeInsetsGeometry.all(10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Здоровье',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 8),
                          ..._buildHealthSummary(),
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
                          child: HomeActionButton(
                            icon: Icons.monitor_weight_outlined,
                            label: 'Вес',
                            onPressed: () => _openWeightHistory(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HomeActionButton(
                            icon: Icons.mood_outlined,
                            label: 'Настроение',
                            onPressed: () => _openMoodHistory(context),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: HomeActionButton(
                            icon: Icons.note_alt_outlined,
                            label: 'Питание',
                            onPressed: () {},
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
                Row(
                  children: [
                    GlassCard(
                      callback: widget.onOpenCalendar,
                      child: Icon(
                        Icons.notifications,
                        color: ThemeColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassCard(
                      callback: widget.onOpenCalendar,
                      child: Icon(
                        Icons.add_circle_outline,
                        color: ThemeColors.primary,
                      ),
                    ),
                  ],
                ),
              ],
            ),

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

class _ProfileSwitcherSheet extends StatelessWidget {
  final List<PetProfile> profiles;
  final String? activeId;

  const _ProfileSwitcherSheet({required this.profiles, required this.activeId});

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
                color: isActive ? profile.color : Colors.white,
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
                            color: isActive
                                ? Colors.white
                                : ThemeColors.primary,
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
                    profile.breed.isEmpty
                        ? profile.species.name
                        : profile.breed,
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

          const SizedBox(height: 16),

          SizedBox(
            width: double.infinity,
            child: GlassCard(
              callback: () => Navigator.pop(context, '__create_new__'),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.add_circle_outline,
                      color: ThemeColors.primary,
                    ),
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
