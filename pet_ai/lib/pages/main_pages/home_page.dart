import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/font_awesome_icons.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/mood_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/note_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/weight_sheet.dart';
import 'package:pet_ai/theme/widgets/events_preview_block.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:pet_ai/pages/secondary_pages/profile_page.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/file_upload_sheet.dart';
import 'package:provider/provider.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/files_history_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/food_sheet.dart';
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
  List<PetEvent> _allEvents = [];

  late String? _weightStatus = "...";
  late String? _moodStatus = "...";
  late String? _foodStatus = "...";

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

    final weightStatus = await ProfileService().lastWeightString();
    final foodStatus = await ProfileService().lastFoodString();
    final moodStatus = await ProfileService().lastMoodString();

    setState(() {
      _profile = profile;
      _multipleProfiles = multipleProfiles;
      _isLoadingProfile = false;

      _weightStatus = weightStatus;
      _foodStatus = foodStatus;
      _moodStatus = moodStatus;
    });

    final events = await EventService().loadEvents(profile.id);

    if (!mounted) return;

    final display = _filterEvents(events);

    setState(() {
      _allEvents = events;
      _events = display;
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

  List<PetEvent> _filterEvents(List<PetEvent> events) {
    final now = DateTime.now();
    bool notVaccination(PetEvent e) => e.category.id != 'vaccination';
    final overdue = events.where((e) => e.isOverdue && notVaccination(e)).toList()
      ..sort((a, b) => b.dateTime.compareTo(a.dateTime));
    final upcoming = events
        .where(
          (e) =>
              notVaccination(e) &&
              (e.repeat != RepeatInterval.none ||
                  e.dateTime.isAfter(now) ||
                  e.dateTime.isAtSameMomentAs(now)),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return [...overdue, ...upcoming];
  }

  List<Widget> _buildHealthSummary(List<HealthBadge> badges, ({String caption, String label, Color color, IconData icon}) score) {
    final top = (badges.toList()..sort((a, b) => b.severity.index.compareTo(a.severity.index))).take(2).toList();

    return [
      Text(
        score.caption,
        style: Theme.of(
          context,
        ).textTheme.titleLarge!.copyWith(inherit: true, color: score.color),
      ),
      const SizedBox(height: 16),
      ...top.map(
        (b) => Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              SoftGlassBadge(
                icon: b.icon ?? b.severity.icon,
                label: b.title,
                color: b.severity.color,
                selected: false,
              ),
            ],
          ),
        ),
      ),
    ];
  }

  Widget _buildHealthScore(({String caption, String label, Color color, IconData icon}) s) {

    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: s.color.withAlpha(40),
        border: Border.all(color: s.color.withAlpha(120), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(s.icon, size: 20, color: s.color),
          Text(
            s.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: s.color,
            ),
          ),
        ],
      ),
    );
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

  void _editEvent(BuildContext context, PetEvent event) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet.edit(event: event),
    );
    if (updated == true) await _initScreen();
  }

  Future<void> _deleteEvent(BuildContext context, PetEvent event) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить событие?'),
        content: Text(
          '«${event.name}» будет удалено без возможности восстановления.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.dangerZone),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await EventService().deleteEvent(event);
    if (mounted) await _initScreen();
  }

  /// Отмечает событие выполненным и через [_kCompletionDelay] убирает его
  /// из списка с плавным обновлением (без мигания спиннера).
  static const _kCompletionDelay = Duration(seconds: 3);
  final Set<String> _completionPending = {};

  void _onEventCompletedChanged(
    BuildContext context,
    PetEvent event,
    bool completed,
  ) async {
    if (_profile == null) return;
    await EventService().toggleCompleted(_profile!.id, event, event.dateTime);

    setState(() => _completionPending.add(event.id));

    await Future.delayed(_kCompletionDelay);
    if (!mounted) return;

    // Silently reload without showing the loading spinner
    final events = await EventService().loadEvents(_profile!.id);
    if (!mounted) return;

    setState(() {
      _allEvents = events;
      _events = _filterEvents(events);
      _completionPending.remove(event.id);
    });
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

  void _openFoodHistory(BuildContext context) async {
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  void _openVetCard(BuildContext context) {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VetCardSheet(profile: _profile!, events: _events),
    );
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

    List<HealthBadge>? healthBadges;
    ({String caption, String label, Color color, IconData icon})? healthScore;
    List<Color>? healthGradient;
    if (_profile != null && !_isLoadingEvents) {
      healthBadges = HealthAnalyzer.analyze(_profile!, _allEvents);
      healthScore = HealthAnalyzer.score(healthBadges);
      healthGradient = [Colors.transparent, healthScore.color.withAlpha(72)];
    }

    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 16),
          children: [
            GlassCard(
              padding: 0,
              callback: () => _openProfile(context),
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsetsGeometry.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
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
                                      border: Border.all(
                                        color: context
                                            .watch<AppearanceController>()
                                            .primaryColor,
                                        width: 2.5,
                                      ),
                                      boxShadow: [
                                        BoxShadow(
                                          color: context
                                              .watch<AppearanceController>()
                                              .primaryColor
                                              .withAlpha(80),
                                          blurRadius: 10,
                                          spreadRadius: 1,
                                        ),
                                      ],
                                    ),
                                    child: CircleAvatar(
                                      radius: 30,
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
                                        color: context
                                            .watch<AppearanceController>()
                                            .primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: Colors.white,
                                          width: 2,
                                        ),
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
                        ),

                        Expanded(
                          flex: 3,
                          child: Center(
                            child: InlineLoading(
                              isLoading: _isLoadingProfile,
                              child: ListTile(
                                title: Row(
                                  spacing: 4,
                                  children: [
                                    if (_profile != null &&
                                        _profile!.gender.icon != null)
                                      Icon(
                                        _profile!.gender.icon,
                                        color: context.watch<AppearanceController>().secondaryColor,
                                      ),
                                    Expanded(
                                      child: Text(
                                        _profile == null ||
                                                _profile!.name.isEmpty
                                            ? "Загружаем..."
                                            : _profile!.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
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
                      ],
                    ),
                  ),

                  const Divider(height: 2, color: Colors.black12),

                  ListTile(
                    minTileHeight: 50,
                    title: Row(
                      spacing: 8,
                      children: [
                        Icon(
                          FontAwesome.medkit,
                          size: 20,
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor,
                        ),
                        Text("Карточка для ветеринара"),
                      ],
                    ),
                    titleTextStyle: Theme.of(context).textTheme.bodySmall,
                    trailing: Icon(
                      Icons.chevron_right,
                      size: 20,
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                    ),
                    onTap: () => _openVetCard(context),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // быстрые действия
            Row(
              spacing: 8,
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _HomeActionButton(
                  callback: () => _openWeightHistory(context),
                  emoji: "⚖️",
                  category: "Вес",
                  caption: _weightStatus,
                ),
                _HomeActionButton(
                  callback: () => _openMoodHistory(context),
                  emoji: "😊",
                  category: "Настроение",
                  caption: _moodStatus,
                ),
                _HomeActionButton(
                  callback: () => _openFoodHistory(context),
                  emoji: "🥣",
                  category: "Питание",
                  caption: _foodStatus,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // блок здоровья
            GlassCard(
              transparent: false,
              gradientColors: healthGradient,
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
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Левая часть — заголовок + бейджи
                          Expanded(
                            flex: 4,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Здоровье',
                                  style: Theme.of(context).textTheme.titleSmall,
                                ),
                                if (healthBadges != null && healthScore != null)
                                  ..._buildHealthSummary(healthBadges, healthScore),
                              ],
                            ),
                          ),
                          Expanded(
                            flex: 1,
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (healthScore != null) _buildHealthScore(healthScore),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
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
                    callback: () {},
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
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    GlassCard(
                      callback: widget.onOpenCalendar,
                      child: Icon(
                        Icons.add_circle_outline,
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor,
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
                onEdit: (event) => _editEvent(context, event),
                onDelete: (event) => _deleteEvent(context, event),
                onCompletedChanged: (event, completed) =>
                    _onEventCompletedChanged(context, event, completed),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeActionButton extends StatelessWidget {
  final VoidCallback callback;
  final String emoji;
  final String category;
  final String? caption;

  const _HomeActionButton({
    required this.callback,
    required this.emoji,
    required this.category,
    required this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GlassCard(
        callback: callback,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsGeometry.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    emoji,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      inherit: true,
                      fontSize: 26,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    category,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      inherit: true,
                      fontSize: 10,
                    ),
                  ),
                  ?caption != null
                      ? Text(
                          caption!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(inherit: true, fontSize: 11),
                        )
                      : null,
                ],
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
                color: isActive
                    ? context.watch<AppearanceController>().primaryColor
                    : Colors.white,
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
                      color: isActive ? Colors.white : context.watch<AppearanceController>().secondaryColor,
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
                          : context.watch<AppearanceController>().secondaryColor.withAlpha(153),
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

// ─── Карточка для ветеринара ────────────────────────────────────────────────

class _VetCardSheet extends StatelessWidget {
  final PetProfile profile;
  final List<PetEvent> events;

  const _VetCardSheet({required this.profile, required this.events});

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: 'Карточка для ветеринара',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.85,
      minSize: 0.5,
      maxSize: 1.0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Основная информация ──────────────────────────────────────
          _sectionTitle(context, 'Основная информация'),
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(
                    context,
                    'Имя',
                    profile.name.isEmpty ? '—' : profile.name,
                  ),
                  _infoRow(context, 'Вид', profile.species.name),
                  _infoRow(
                    context,
                    'Порода',
                    profile.breed.isEmpty ? '—' : profile.breed,
                  ),
                  _infoRow(context, 'Пол', profile.gender.caption),
                  _infoRow(context, 'Возраст', _formatAge()),
                  _infoRow(context, 'Дата рождения', _formatBirthDate()),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Вес ──────────────────────────────────────────────────────
          _sectionTitle(context, 'Вес'),
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _infoRow(
                    context,
                    'Текущий вес',
                    profile.weightHistory.lastWeight != null
                        ? '${profile.weightHistory.lastWeight!.toStringAsFixed(1)} кг'
                        : 'Нет данных',
                  ),
                  if (profile.weightHistory.lastEntry != null)
                    _infoRow(
                      context,
                      'Дата взвешивания',
                      formatSmartDate(profile.weightHistory.lastEntry!.date),
                    ),
                  _buildWeightDynamics(context),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── Настроение за неделю ─────────────────────────────────────
          _sectionTitle(context, 'Настроение за последнюю неделю'),
          _buildMoodWeek(context),

          const SizedBox(height: 16),

          // ── Прививки и обработки ─────────────────────────────────────
          _sectionTitle(context, 'Прививки и обработки'),
          _buildTreatments(context),

          // ── Заметки ──────────────────────────────────────────────────
          if (profile.noteHistory.entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            _sectionTitle(context, 'Важные заметки'),
            _buildNotes(context),
          ],

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: Theme.of(
          context,
        ).textTheme.titleMedium!.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }

  Widget _infoRow(BuildContext context, String label, String value) {
    Color textColor = context.watch<AppearanceController>().secondaryColor;
    if (value.startsWith('+')) {
      textColor = ThemeColors.ok;
    } else if (value.startsWith('-')) {
      textColor = ThemeColors.warning;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: context.watch<AppearanceController>().secondaryColor.withAlpha(153),
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _formatAge() {
    if (profile.birthDate == null) return 'Нет данных';
    final duration = profile.birthDate!.difference(DateTime.now());
    return formatPetAge(duration);
  }

  String _formatBirthDate() {
    if (profile.birthDate == null) return 'Нет данных';
    return DateFormat('dd.MM.yyyy', 'ru').format(profile.birthDate!);
  }

  Widget _buildWeightDynamics(BuildContext context) {
    final entries = profile.weightHistory.entries;
    if (entries.length < 2) {
      return _infoRow(context, 'Динамика', 'Недостаточно данных');
    }

    // Последние 5 записей
    final recent = entries.length > 5
        ? entries.sublist(entries.length - 5)
        : entries;

    final first = recent.first.weight;
    final last = recent.last.weight;
    final diff = last - first;
    final sign = diff > 0 ? '+' : '';
    final trend = diff.abs() < 0.05
        ? 'Стабильный'
        : '$sign${diff.toStringAsFixed(1)} кг';

    return _infoRow(context, 'Динамика', trend);
  }

  Widget _buildMoodWeek(BuildContext context) {
    final now = DateTime.now();
    final weekAgo = now.subtract(const Duration(days: 7));
    final recentMoods =
        profile.moodHistory.entries
            .where((e) => e.date.isAfter(weekAgo))
            .toList()
          ..sort((a, b) => a.date.compareTo(b.date));

    if (recentMoods.isEmpty) {
      return GlassPlate(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Нет записей за последнюю неделю',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: context
                  .watch<AppearanceController>()
                  .secondaryColor
                  .withAlpha(153),
            ),
          ),
        ),
      );
    }

    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: recentMoods.map((entry) {
            return Chip(
              avatar: Icon(entry.mood.icon, size: 16),
              label: Text(
                '${DateFormat('dd.MM').format(entry.date)} '
                '${entry.dayPart.label} — ${entry.mood.label}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              visualDensity: VisualDensity.compact,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildTreatments(BuildContext context) {
    final treatments = profile.treatmentHistory.entries;
    if (treatments.isEmpty) {
      return GlassPlate(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Нет записей о прививках и обработках',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: context.watch<AppearanceController>().secondaryColor.withAlpha(153),
            ),
          ),
        ),
      );
    }

    // Группируем по виду
    final grouped = <TreatmentKind, List<TreatmentEntry>>{};
    for (final t in treatments) {
      grouped.putIfAbsent(t.kind, () => []).add(t);
    }

    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: grouped.entries.map((group) {
            final kind = group.key;
            final items = group.value..sort((a, b) => b.date.compareTo(a.date));

            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(kind.icon, size: 18, color: kind.color),
                    const SizedBox(width: 6),
                    Text(
                      kind.label,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ...items.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(left: 24, bottom: 4),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            t.displayName,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(color: context.watch<AppearanceController>().secondaryColor),
                          ),
                        ),
                        Text(
                          formatSmartDate(t.date),
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: context.watch<AppearanceController>().secondaryColor.withAlpha(153),
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '→ ${formatSmartDate(t.nextDate)}',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: t.nextDate.isBefore(DateTime.now())
                                    ? HealthBadgeSeverity.danger.color
                                    : context.watch<AppearanceController>().secondaryColor.withAlpha(153),
                                fontWeight: t.nextDate.isBefore(DateTime.now())
                                    ? FontWeight.w700
                                    : FontWeight.w400,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildNotes(BuildContext context) {
    // Показываем последние 5 заметок
    final notes = profile.noteHistory.entries.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    final recent = notes.take(5).toList();

    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recent
              .map(
                (n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        formatSmartDate(n.date),
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: context.watch<AppearanceController>().secondaryColor.withAlpha(153),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          n.note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(color: context.watch<AppearanceController>().secondaryColor),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
