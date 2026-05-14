import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/pages/secondary_pages/settings_page.dart';
import 'package:pet_ai/services/file_storage_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/font_awesome_icons.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/skeleton.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/note_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:pet_ai/pages/secondary_pages/profile_page.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/file_upload_sheet.dart';
import 'package:provider/provider.dart';

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
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  PetProfile? _profile;
  bool? _multipleProfiles;

  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;
  List<PetEvent> _allEvents = [];
  int _filesCount = 0;
  int _notesCount = 0;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  /// Called by [MainPage] via GlobalKey whenever the home tab becomes active,
  /// so that data added on other tabs (events, notes, etc.) is reflected here.
  void refresh() => _initScreen();

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
        throw Exception('Failed navigate to registration flow');
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

    final filesCount = await FileStorageService().documentsCount(profile.id);
    final notesCount = _profile?.noteHistory.entries.length;

    setState(() {
      _allEvents = events;
      _isLoadingEvents = false;
      _filesCount = filesCount;
      _notesCount = notesCount ?? 0;
    });
  }

  String _profileDescription() {
    String description = _profile?.breed ?? '';
    if (_profile != null && _profile!.birthDate != null) {
      final duration = _profile!.birthDate!.difference(DateTime.now());
      return '$description · ${formatPetAge(duration)}';
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
      builder: (_) => EventSheet(event: event),
    );
    if (updated == true) await _initScreen();
  }

  void _openNotes(BuildContext context) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  void _openDocuments(BuildContext context) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const FileUploadSheet(),
    );
    await _initScreen();
  }

  void _openVetCard(BuildContext context) {
    if (_profile == null) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _VetCardSheet(profile: _profile!, events: _allEvents),
    );
  }

  void _openProfile(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const PetProfilePage()),
    );
    await _initScreen();
  }

  void _openSettings(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsPage()),
    );
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

  // ── Данные для таймлайна ──────────────────────────────────────────────────

  List<_TimelineItem> _buildUpcomingItems() {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));
    final items = <_TimelineItem>[];

    for (final e in _allEvents) {
      if (e.repeat == RepeatInterval.none) {
        if (e.dateTime.isAfter(now) && e.dateTime.isBefore(in30Days)) {
          items.add(
            _TimelineItem(
              date: e.dateTime,
              title: e.name,
              subtitle: e.category.name,
              icon: e.category.icon,
              color: e.category.color,
              event: e,
            ),
          );
        }
      } else {
        // Для повторяющихся показываем как "ближайшее"
        final base = DateTime(
          e.dateTime.year,
          e.dateTime.month,
          e.dateTime.day,
        );
        final today = DateTime(now.year, now.month, now.day);
        if (!base.isAfter(in30Days)) {
          // Найдём первое вхождение от сегодня в ближайшие 30 дней
          for (int d = 0; d < 30; d++) {
            final day = today.add(Duration(days: d));
            if (e.occursOn(day) && !e.isCompletedOn(day)) {
              items.add(
                _TimelineItem(
                  date: DateTime(
                    day.year,
                    day.month,
                    day.day,
                    e.dateTime.hour,
                    e.dateTime.minute,
                  ),
                  title: e.name,
                  subtitle: '${e.category.name} · повторяется',
                  icon: e.category.icon,
                  color: e.category.color,
                  event: e,
                ),
              );
              break;
            }
          }
        }
      }
    }

    items.sort((a, b) => a.date.compareTo(b.date));
    return items;
  }

  List<_TimelineItem> _buildHistoryItems() {
    final items = <_TimelineItem>[];

    // Completed events
    for (final event in _allEvents) {
      for (final dateStr in event.completedDates) {
        final parts = dateStr.split('-');
        if (parts.length == 3) {
          final date = DateTime(
            int.tryParse(parts[0]) ?? 0,
            int.tryParse(parts[1]) ?? 0,
            int.tryParse(parts[2]) ?? 0,
          );
          if (date.isBefore(DateTime.now())) {
            items.add(
              _TimelineItem(
                date: date,
                title: event.name,
                subtitle: 'Выполнено · ${event.category.name}',
                icon: Icons.check_circle_outline,
                color: event.category.color,
                isCompleted: true,
                event: event,
              ),
            );
          }
        }
      }
    }

    // Birthday
    if (_profile?.birthDate != null) {
      final birthday = _profile!.birthDate!;
      final now = DateTime.now();
      var thisBirthday = DateTime(now.year, birthday.month, birthday.day);
      if (thisBirthday.isAfter(now)) {
        thisBirthday = DateTime(now.year - 1, birthday.month, birthday.day);
      }
      final age = thisBirthday.year - birthday.year;
      items.add(
        _TimelineItem(
          date: thisBirthday,
          title: 'День рождения ${_profile!.name}',
          subtitle: '$age ${_yearsWord(age)}',
          icon: Icons.cake_outlined,
          color: Colors.pink.shade300,
          isBirthday: true,
        ),
      );
    }

    items.sort((a, b) => b.date.compareTo(a.date));
    return items;
  }

  static String _yearsWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'лет';
    if (mod10 == 1) return 'год';
    if (mod10 >= 2 && mod10 <= 4) return 'года';
    return 'лет';
  }

  @override
  Widget build(BuildContext context) {
    final description = _profileDescription();
    final topPadding = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 100),
          children: [
            Row(
              children: [
                Expanded(
                  child: _isLoadingProfile
                      ? Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: const [
                            SkeletonText(width: 90, height: 13),
                            SizedBox(height: 7),
                            SkeletonText(width: 200, height: 22),
                          ],
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Доброе утро,'),
                            Text(
                              'как там ${_profile!.name}?🐾',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    inherit: true,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 22,
                                  ),
                            ),
                          ],
                        ),
                ),
                // Кнопка настроек
                GlassCard(
                  callback: () => _openSettings(context),
                  child: Icon(
                    Icons.settings_outlined,
                    color: context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(180),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            GlassCard(
              padding: 0,
              callback: () => _openProfile(context),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        Expanded(
                          flex: 1,
                          child: GestureDetector(
                            onTap: _isLoadingProfile
                                ? null
                                : () => _showProfileSwitcher(context),
                            child: _isLoadingProfile
                                ? Center(
                                    child: SkeletonBox(
                                      width: 66,
                                      height: 66,
                                      borderRadius: 33,
                                    ),
                                  )
                                : Stack(
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

                        Expanded(
                          flex: 4,
                          child: _isLoadingProfile
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: const [
                                      SkeletonText(width: 130, height: 18),
                                      SizedBox(height: 8),
                                      SkeletonText(width: 170, height: 13),
                                    ],
                                  ),
                                )
                              : ListTile(
                                  title: Row(
                                    spacing: 6,
                                    children: [
                                      Text(
                                        _profile == null || _profile!.name.isEmpty
                                            ? 'Без имени'
                                            : _profile!.name,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleLarge,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      if (_profile != null &&
                                          _profile!.gender.icon != null)
                                        Container(
                                          decoration: BoxDecoration(
                                            shape: BoxShape.circle,
                                            color: _profile!.gender.color,
                                          ),
                                          child: Padding(
                                            padding: EdgeInsetsGeometry.all(2),
                                            child: Icon(
                                              _profile!.gender.icon,
                                              size: 18,
                                              color: context
                                                  .watch<AppearanceController>()
                                                  .secondaryColor,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  subtitle: Text(
                                    description.isEmpty
                                        ? 'Порода и возраст'
                                        : description,
                                    style: Theme.of(context).textTheme.bodySmall,
                                  ),
                                ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            GlassCard(
              callback: () => _openVetCard(context),
              child: ListTile(
                minTileHeight: 50,
                leading: SoftRoundedIcon(
                  icon: FontAwesome.medkit,
                  color: ThemeColors.vetCardIconColor,
                ),
                title: Text(
                  'Карточка для ветеринара',
                  style: Theme.of(context).textTheme.titleMedium
                ),
                subtitle: Text(
                  'Прививки, вес, аллергии и другие важные сведения',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                titleTextStyle: Theme.of(context).textTheme.bodySmall,
                trailing: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.watch<AppearanceController>().secondaryColor,
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Файлы и заметки ────────────────────────────────────────────
            Row(
              spacing: 16,
              children: [
                Expanded(
                  child: GlassPlate(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            spacing: 6,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SoftRoundedIcon(
                                icon: FontAwesome.file_alt,
                                color: ThemeColors.filesIconColor,
                              ),
                              Text(
                                'Файлы',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _filesCount > 0
                                    ? '$_filesCount ${declension(_filesCount, 'файл', 'файла', 'файлов')}'
                                    : 'Пока нет файлов',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      inherit: true,
                                      color: context
                                          .watch<AppearanceController>()
                                          .secondaryColor
                                          .withAlpha(128),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: _SmallActionButton(
                            icon: Icons.add_circle_outline,
                            label: 'Добавить',
                            onPressed: () => _openDocuments(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GlassPlate(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(10),
                          child: Column(
                            spacing: 6,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SoftRoundedIcon(
                                icon: FontAwesome.notes_medical,
                                color: ThemeColors.notesIconColor,
                              ),
                              Text(
                                'Заметка',
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                _notesCount > 0
                                    ? '$_notesCount ${declension(_notesCount, 'заметка', 'заметки', 'заметок')}'
                                    : 'Пока нет заметок',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      inherit: true,
                                      color: context
                                          .watch<AppearanceController>()
                                          .secondaryColor
                                          .withAlpha(128),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          child: _SmallActionButton(
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

            // ── Таймлайн ────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'История питомца',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                TextButton(
                  onPressed: widget.onOpenCalendar,
                  child: Row(
                    children: [
                      Text(
                        'Все события',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                      Icon(
                        Icons.chevron_right,
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor,
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            InlineLoading(
              isLoading: _isLoadingEvents,
              child: _PetTimeline(
                upcomingItems: _buildUpcomingItems(),
                historyItems: _buildHistoryItems(),
                onEventTap: (item) {
                  if (item.event != null) {
                    _openEventSheet(context, item.event!);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Таймлайн ────────────────────────────────────────────────────────────────

class _TimelineItem {
  final DateTime date;
  final String title;
  final String? subtitle;
  final IconData icon;
  final Color color;
  final bool isCompleted;
  final bool isBirthday;
  final PetEvent? event;

  const _TimelineItem({
    required this.date,
    required this.title,
    this.subtitle,
    required this.icon,
    required this.color,
    this.isCompleted = false,
    this.isBirthday = false,
    this.event,
  });
}

class _PetTimeline extends StatelessWidget {
  final List<_TimelineItem> upcomingItems;
  final List<_TimelineItem> historyItems;
  final ValueChanged<_TimelineItem> onEventTap;

  final double _timelineColWidth = 56;

  const _PetTimeline({
    required this.upcomingItems,
    required this.historyItems,
    required this.onEventTap,
  });

  @override
  Widget build(BuildContext context) {
    if (upcomingItems.isEmpty && historyItems.isEmpty) {
      return GlassPlate(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Нет событий. Добавьте первое событие через календарь.',
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

    final widgets = <Widget>[];

    // ── Ближайшие события (следующие 30 дней) ──
    if (upcomingItems.isEmpty) {
      widgets.add(_buildEmptySection(context, 'Нет событий в ближайший месяц'));
    } else {
      for (int i = 0; i < upcomingItems.length; i++) {
        final item = upcomingItems[i];
        final isLast = i == upcomingItems.length - 1 && historyItems.isEmpty;
        widgets.add(_buildItem(context, item, isLast: isLast));
      }
    }

    // ── Разделитель ──
    if (historyItems.isNotEmpty) {
      widgets.add(_buildSeparator(context));

      for (int i = 0; i < historyItems.length; i++) {
        final item = historyItems[i];
        final isLast = i == historyItems.length - 1;
        widgets.add(const SizedBox(height: 4));
        widgets.add(_buildItem(context, item, isLast: isLast));
      }
    }

    return Column(children: widgets);
  }

  Widget _buildEmptySection(BuildContext context, String message) {
    return IntrinsicHeight(
      child: Row(
        children: [
          _LineColumn(showLine: true, dot: false),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context
                    .watch<AppearanceController>()
                    .secondaryColor
                    .withAlpha(192),
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeparator(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: _timelineColWidth,
          child: Column(
            children: [
              Container(
                width: 2,
                height: 12,
                color: context.watch<AppearanceController>().secondaryColor,
              ),
              Text(
                '···',
                style: TextStyle(
                  color: context.watch<AppearanceController>().secondaryColor,
                  fontSize: 18,
                  height: 1,
                ),
              ),
              Container(
                width: 2,
                height: 12,
                color: context.watch<AppearanceController>().secondaryColor,
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          'События за последний год',
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            color: context.watch<AppearanceController>().secondaryColor,
          ),
        ),
      ],
    );
  }

  Widget _buildItem(
    BuildContext context,
    _TimelineItem item, {
    bool isLast = false,
  }) {
    final dateLabel = formatSmartDate(item.date, pattern: 'd MMMM');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Левая колонка: дата + линия
          SizedBox(
            width: _timelineColWidth,
            child: Column(
              children: [
                // Дата
                Text(
                  dateLabel,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    fontSize: 11,
                    height: 1.2,
                    color: item.isCompleted
                        ? context.watch<AppearanceController>().secondaryColor
                        : item.color.withAlpha(200),
                    fontWeight: item.isCompleted
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                // Точка
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: item.isCompleted
                        ? context.watch<AppearanceController>().secondaryColor
                        : item.color,
                    border: Border.all(
                      color: item.isCompleted
                          ? context.watch<AppearanceController>().secondaryColor
                          : item.color.withAlpha(80),
                      width: 2,
                    ),
                  ),
                ),
                // Линия вниз
                if (!isLast)
                  Expanded(
                    child: Center(
                      child: Container(
                        decoration: item.isCompleted
                            ? null
                            : BoxDecoration(
                                gradient: LinearGradient(
                                  begin: AlignmentGeometry.topCenter,
                                  end: AlignmentGeometry.bottomCenter,
                                  colors: [
                                    item.color,
                                    context
                                        .watch<AppearanceController>()
                                        .secondaryColor,
                                  ],
                                ),
                              ),
                        width: 2,
                        color: item.isCompleted
                            ? context
                                  .watch<AppearanceController>()
                                  .secondaryColor
                            : null,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // Правая колонка: карточка
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: GestureDetector(
                onTap: item.event != null || item.isBirthday
                    ? () => onEventTap(item)
                    : null,
                child: GlassPlate(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    child: Row(
                      children: [
                        SoftRoundedIcon(
                          icon: item.icon,
                          color: item.isCompleted
                              ? item.color.withAlpha(160)
                              : item.color,
                          size: 16,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: Theme.of(context).textTheme.titleSmall!
                                    .copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: item.isCompleted
                                          ? Colors.grey.shade600
                                          : null,
                                      decoration: item.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              if (item.subtitle != null)
                                Text(
                                  item.subtitle!,
                                  style: Theme.of(context).textTheme.bodySmall!
                                      .copyWith(color: Colors.grey.shade500),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineColumn extends StatelessWidget {
  final bool showLine;
  final bool dot;

  const _LineColumn({this.showLine = false, this.dot = true});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 56,
      child: Column(
        children: [
          if (dot)
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.watch<AppearanceController>().secondaryColor,
              ),
            ),
          if (showLine)
            Expanded(
              child: Center(
                child: Container(
                  width: 2,
                  color: context.watch<AppearanceController>().secondaryColor,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Маленькая кнопка действия ───────────────────────────────────────────────

class _SmallActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _SmallActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      callback: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: 6,
          children: [
            Icon(
              icon,
              size: 16,
              color: context.watch<AppearanceController>().secondaryColor,
            ),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall!.copyWith(
                color: context.watch<AppearanceController>().secondaryColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Переключатель профилей ───────────────────────────────────────────────────

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
                        : context
                              .watch<AppearanceController>()
                              .primaryColor
                              .withAlpha(38),
                    backgroundImage: profile.profileImage != null
                        ? FileImage(profile.profileImage!)
                        : null,
                    child: profile.profileImage == null
                        ? Icon(
                            Icons.pets,
                            size: 20,
                            color: isActive
                                ? Colors.white
                                : context
                                      .watch<AppearanceController>()
                                      .primaryColor,
                          )
                        : null,
                  ),
                  title: Text(
                    profile.name.isEmpty ? 'Без имени' : profile.name,
                    style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isActive
                          ? Colors.white
                          : context
                                .watch<AppearanceController>()
                                .secondaryColor,
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
                          : context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(153),
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
                    Icon(
                      Icons.add_circle_outline,
                      color: context.watch<AppearanceController>().primaryColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Добавить питомца',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor,
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

// ─── Карточка для ветеринара ──────────────────────────────────────────────────

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
          _sectionTitle(context, 'Настроение за последнюю неделю'),
          _buildMoodWeek(context),

          const SizedBox(height: 16),
          _sectionTitle(context, 'Прививки и обработки'),
          _buildTreatments(context),

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
      textColor = ThemeColors.ok.mainColor;
    } else if (value.startsWith('-')) {
      textColor = ThemeColors.warning.mainColor;
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
                color: context
                    .watch<AppearanceController>()
                    .secondaryColor
                    .withAlpha(153),
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
    final recent = entries.length > 5
        ? entries.sublist(entries.length - 5)
        : entries;
    final diff = recent.last.weight - recent.first.weight;
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
              color: context
                  .watch<AppearanceController>()
                  .secondaryColor
                  .withAlpha(153),
            ),
          ),
        ),
      );
    }

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
                                .copyWith(
                                  color: context
                                      .watch<AppearanceController>()
                                      .secondaryColor,
                                ),
                          ),
                        ),
                        Text(
                          formatSmartDate(t.date),
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: context
                                    .watch<AppearanceController>()
                                    .secondaryColor
                                    .withAlpha(153),
                              ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '→ ${formatSmartDate(t.nextDate)}',
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: t.nextDate.isBefore(DateTime.now())
                                    ? HealthBadgeSeverity.danger.palette.mainColor
                                    : context
                                          .watch<AppearanceController>()
                                          .secondaryColor
                                          .withAlpha(153),
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
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor
                              .withAlpha(153),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          n.note,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodySmall!
                              .copyWith(
                                color: context
                                    .watch<AppearanceController>()
                                    .secondaryColor,
                              ),
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
