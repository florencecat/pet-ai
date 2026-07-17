import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/history_filter.dart';
import 'package:pet_satellite/pages/secondary_pages/settings_page.dart';
import 'package:pet_satellite/services/file_storage_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/services/user_profile_service.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/font_awesome_icons.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/skeleton.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/birthday_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/note_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/home_pet_avatar.dart';
import 'package:pet_satellite/theme/widgets/pinnable_header_view.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/pages/secondary_pages/pet_profile_page.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/event_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/file_upload_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/history_filter_sheet.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class HomePage extends StatefulWidget {
  final VoidCallback onOpenCalendar;
  final ValueChanged<DateTime> onOpenCalendarByEvent;

  const HomePage({
    super.key,
    required this.onOpenCalendar,
    required this.onOpenCalendarByEvent,
  });

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  Pet? _profile;
  UserProfile? _user;
  bool? _multipleProfiles;

  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;
  List<Event> _allEvents = [];
  int _filesCount = 0;
  int _notesCount = 0;
  HistoryFilter _filter = const HistoryFilter.defaults();

  // Пока аватар раскрыт в оверлей — прячем шеврон-переключатель, чтобы он не
  // «висел в воздухе» (он не часть Hero и остаётся на месте во время полёта).
  bool _avatarExpanded = false;

  @override
  void initState() {
    super.initState();
    _initScreen();
    HistoryFilter.load().then((f) {
      if (mounted) setState(() => _filter = f);
    });
  }

  /// Called by [MainPage] via GlobalKey whenever the home tab becomes active,
  /// so that data added on other tabs (events, notes, etc.) is reflected here.
  void refresh() => _initScreen();

  Future<void> _initScreen() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingEvents = true;
    });

    final user = await UserProfileService().load();
    final profile = await PetProfileService().loadActiveProfile();

    if (profile == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/registration');
      } else {
        throw Exception('Failed navigate to registration flow');
      }
      return;
    }

    final multipleProfiles = await PetProfileService().hasMultipleProfiles();

    setState(() {
      _user = user;
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

  static String _timeGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) return 'Доброе утро';
    if (hour >= 12 && hour < 17) return 'Добрый день';
    if (hour >= 17 && hour < 22) return 'Добрый вечер';
    return 'Доброй ночи';
  }

  void _openEventSheet(BuildContext context, Event event) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => EventSheet(event: event),
    );
    // Обновляем безусловно: отметка «Выполнено» сохраняется сразу, но лист
    // при закрытии (свайп/назад) не возвращает результат.
    if (mounted) await _initScreen();
  }

  void _openBirthdaySheet(BuildContext context) {
    if (_profile?.birthDate == null) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => BirthdaySheet(profile: _profile!),
    );
  }

  void _openHistoryFilter(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => HistoryFilterSheet(
        filter: _filter,
        onChanged: (f) => setState(() => _filter = f),
      ),
    );
  }

  void _openNotes(BuildContext context) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => NoteSheet(profile: _profile!),
    );
    await _initScreen();
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
    await _initScreen();
  }

  /// Нажатие по аватарке: раскрытие в центр с анимацией. Возвращает true, если
  /// фото поменяли — тогда обновляем экран.
  Future<void> _onAvatarTap() async {
    final pet = _profile;
    if (pet == null) return;
    setState(() => _avatarExpanded = true); // скрыть шеврон на время полёта
    final changed = await showPetAvatarExpand(context, pet);
    if (!mounted) return;
    setState(() => _avatarExpanded = false); // вернулись — показать снова
    if (changed == true) await _initScreen();
  }

  void _showProfileSwitcher(BuildContext context) async {
    final profiles = await PetProfileService().loadAllProfiles();
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

    // Обновление вкладок, палитры и контекста чата вешать сюда не нужно: и
    // регистрация, и setActiveProfile сигналят о смене активного питомца, а
    // MainPage на этот сигнал обновляет всё разом (_onProfileSwitched).
    if (result == '__create_new__') {
      if (context.mounted) await Navigator.pushNamed(context, '/registration');
    } else {
      await PetProfileService().setActiveProfile(result);
    }
  }

  // ── Данные для таймлайна ──────────────────────────────────────────────────

  List<_TimelineItem> _buildUpcomingItems() {
    final now = DateTime.now();
    final in30Days = now.add(const Duration(days: 30));
    final items = <_TimelineItem>[];

    for (final e in _allEvents) {
      // Pill/treatment events are shown on the health page by default; on the
      // timeline only when explicitly enabled in the history filter.
      if (e.fromPill && !_filter.upcomingPills) continue;
      if (e.fromTreatment && !_filter.upcomingTreatments) continue;

      if (e.repeat == RepeatInterval.none) {
        if (!e.isCompletedOn(e.dateTime) &&
            e.dateTime.isAfter(now) &&
            e.dateTime.isBefore(in30Days)) {
          items.add(
            _TimelineItem(
              date: e.dateTime,
              title: e.name,
              subtitle: e.category.name,
              icon: e.style.icon,
              color: e.style.color ?? e.category.color,
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
                  icon: e.style.icon,
                  color:
                      e.style.color ??
                      context.watch<AppearanceController>().primaryColor,
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

    // Completed events (exclude pill/treatment auto-events — they clutter the
    // timeline and are shown on the health page).
    if (_filter.completedEvents) {
      for (final event in _allEvents) {
        if (event.fromPill || event.fromTreatment) continue;
        for (final dateStr in event.completedDates) {
          final parts = dateStr.split('-');
          if (parts.length == 3) {
            final date = DateTime(
              int.tryParse(parts[0]) ?? 0,
              int.tryParse(parts[1]) ?? 0,
              int.tryParse(parts[2]) ?? 0,
            );
            if (event.isCompletedOn(date) || date.isBefore(DateTime.now())) {
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
    }

    // Missed events — прошедшие вхождения (за 30 дней), не отмеченные выполненными.
    if (_filter.missedEvents) {
      items.addAll(_buildMissedItems());
    }

    // Birthday (automatic event)
    if (_filter.automaticEvents && _profile?.birthDate != null) {
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

  /// Прошедшие (за последние 30 дней) вхождения событий, не отмеченные
  /// выполненными.
  List<_TimelineItem> _buildMissedItems() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final items = <_TimelineItem>[];

    for (final e in _allEvents) {
      if (e.fromNote) continue;

      if (e.repeat == RepeatInterval.none) {
        final cutoff = today.subtract(const Duration(days: 30));
        if (e.dateTime.isBefore(now) &&
            !e.dateTime.isBefore(cutoff) &&
            !e.isCompletedOn(e.dateTime)) {
          items.add(_missedItem(e, e.dateTime));
        }
      } else {
        // Для повторяющихся — прошедшие дни (сегодняшнее вхождение уже учтено
        // секцией «предстоящие»).
        for (int d = 1; d <= 30; d++) {
          final day = today.subtract(Duration(days: d));
          if (!e.occursOn(day) || e.isCompletedOn(day)) continue;
          items.add(
            _missedItem(
              e,
              DateTime(
                day.year,
                day.month,
                day.day,
                e.dateTime.hour,
                e.dateTime.minute,
              ),
            ),
          );
        }
      }
    }
    return items;
  }

  _TimelineItem _missedItem(Event e, DateTime date) => _TimelineItem(
    date: date,
    title: e.name,
    subtitle: 'Пропущено · ${e.category.name}',
    icon: Icons.cancel_outlined,
    color: ThemeColors.warning.mainColor,
    event: e,
  );

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
    // Аватар адаптируется под ширину экрана (больше на планшетах), в разумных
    // пределах.
    final double avatarDiameter = (MediaQuery.sizeOf(context).width * 0.2)
        .clamp(76.0, 128.0)
        .toDouble();

    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: PinnableHeaderView(
          header: Row(
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
                          Text(
                            _user != null
                                ? '${_timeGreeting()}, ${_user!.name}!'
                                : '${_timeGreeting()},',
                            style: context.subtitleMediumStyle,
                          ),
                          Text(
                            'как там ${_profile!.name}?🐾',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  inherit: true,
                                  fontWeight: FontWeight.w900,
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
          children: [
            GlassCard(
              padding: 0,
              callback: () => _openProfile(context),
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      children: [
                        _isLoadingProfile
                            ? SkeletonBox(
                                width: avatarDiameter,
                                height: avatarDiameter,
                                borderRadius: avatarDiameter / 2,
                              )
                            : HomePetAvatar(
                                pet: _profile!,
                                diameter: avatarDiameter,
                                multipleProfiles: _multipleProfiles ?? false,
                                showSwitcher: !_avatarExpanded,
                                onTapAvatar: _onAvatarTap,
                                onTapSwitcher: () =>
                                    _showProfileSwitcher(context),
                              ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _isLoadingProfile
                              ? Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 10,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: const [
                                      SkeletonText(width: 130, height: 18),
                                      SizedBox(height: 8),
                                      SkeletonText(width: 170, height: 13),
                                    ],
                                  ),
                                )
                              : PetProfileService().buildProfileDescription(
                                  context,
                                  _profile,
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
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                subtitle: Text(
                  'Прививки, вес, аллергии и другие важные сведения',
                  style: context.subtitleStyle,
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
                  child: GlassCard(
                    callback: () => _openDocuments(context),
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
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: GlassCard(
                    callback: () => _openNotes(context),
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
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Таймлайн ────────────────────────────────────────────────────
        FittedBox(
          child:
          Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  spacing: 4,
                  children: [
                    Text(
                      'История питомца',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    IconButton(
                      onPressed: () => _openHistoryFilter(context),
                      icon: Icon(
                        Icons.tune,
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor,
                      ),
                      tooltip: 'Что показывать',
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
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
            )),

            const SizedBox(height: 12),

            InlineLoading(
              isLoading: _isLoadingEvents,
              child: _PetTimeline(
                upcomingItems: _buildUpcomingItems(),
                historyItems: _buildHistoryItems(),
                onEventTap: (item) {
                  if (item.isBirthday) {
                    _openBirthdaySheet(context);
                  } else if (item.event != null) {
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
  final Event? event;

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

      // ── Прошедшие события ──
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
          _LineColumn(showLine: true, dot: true),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: context.subtitleStyle)),
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
    final hasTime = item.date.hour != 0 || item.date.minute != 0;
    final timeLabel = hasTime ? DateFormat('HH:mm').format(item.date) : null;

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
                    height: 1.2,
                    color: item.isCompleted
                        ? context.watch<AppearanceController>().secondaryColor
                        : item.color.withAlpha(200),
                    fontWeight: item.isCompleted
                        ? FontWeight.w400
                        : FontWeight.w600,
                  ),
                ),
                if (timeLabel != null)
                  Text(
                    timeLabel,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      height: 1.1,
                      color: item.isCompleted
                          ? context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(150)
                          : item.color.withAlpha(150),
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
              child: Pressable(
                onTap: item.event != null || item.isBirthday
                    ? () => onEventTap(item)
                    : null,
                haptic: HapticStrength.light,
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

// ─── Переключатель профилей ───────────────────────────────────────────────────

class _ProfileSwitcherSheet extends StatelessWidget {
  final List<Pet> profiles;
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
                color: isActive ? profile.palette.mainColor : Colors.white,
                child: Pressable(
                  haptic: HapticStrength.selection,
                  onTap: isActive
                      ? () => Navigator.pop(context)
                      : () => Navigator.pop(context, profile.id),
                  child: PetProfileService().buildProfileDescription(
                    context,
                    profile,
                    leading: PetProfileService().buildProfileAvatar(
                      context,
                      profile,
                      size: 22,
                    ),
                    trailing: isActive
                        ? const Icon(Icons.check_circle, color: Colors.white)
                        : null,
                    titleTheme: Theme.of(context).textTheme.bodyLarge!.copyWith(
                      color: isActive
                          ? Colors.white
                          : context
                                .watch<AppearanceController>()
                                .secondaryColor,
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w400,
                    ),
                    subTitleTheme: Theme.of(context).textTheme.bodySmall!
                        .copyWith(
                          color: isActive
                              ? Colors.white.withAlpha(204)
                              : context
                                    .watch<AppearanceController>()
                                    .secondaryColor
                                    .withAlpha(153),
                        ),
                  ),
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

class _VetCardSheet extends StatelessWidget {
  final Pet profile;
  final List<Event> events;

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
                  _infoRow(context, 'Имя', profile.name),
                  _infoRow(context, 'Вид', profile.species.name),
                  _infoRow(
                    context,
                    'Порода',
                    profile.breed.isEmpty ? '—' : profile.breed.name,
                  ),
                  _infoRow(context, 'Пол', profile.gender.caption),
                  _infoRow(context, 'Возраст', _formatAge()),
                  _infoRow(context, 'Дата рождения', _formatBirthDate()),
                  if (profile.allergies.isNotEmpty)
                    _infoRow(context, 'Аллергии', profile.allergies),
                  if (profile.chronicConditions.isNotEmpty)
                    _infoRow(
                      context,
                      'Хронические заболевания',
                      profile.chronicConditions,
                    ),
                  if (profile.vetClinic.isNotEmpty)
                    _infoRow(context, 'Ветеринар', profile.vetClinic),
                  _infoRow(context, 'Стерилизация', _formatCastration()),
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
          _sectionTitle(context, 'Таблетки'),
          _buildPills(context),

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

  String _formatCastration() {
    if (!profile.castrated) return 'Нет';
    if (profile.castratedDate != null) {
      return 'Да, ${DateFormat('MMMM yyyy', 'ru_RU').format(profile.castratedDate!)}';
    }
    return 'Да';
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
            return SoftGlassBadge(
              color: context.watch<AppearanceController>().secondaryColor,
              size: 10,
              label:
                  '${DateFormat('dd.MM').format(entry.date)} ${entry.dayPart.label} — ${entry.mood.label}',
              icon: entry.mood.icon,
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildPills(BuildContext context) {
    final pills = profile.pillReminders;
    if (pills.isEmpty) {
      return GlassPlate(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            'Нет записей о таблетках',
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
        padding: const EdgeInsets.all(16),
        child: Column(
          children: pills
              .map(
                (p) => Padding(
                  padding: const EdgeInsets.only(left: 4, bottom: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        spacing: 10,
                        children: [
                          if (p.kind != null)
                            Icon(
                              p.kind!.icon,
                              size: 14,
                              color: p.color != null
                                  ? Color(p.color!)
                                  : context
                                        .watch<AppearanceController>()
                                        .secondaryColor,
                            ),
                          Text(
                            p.name,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  color: context
                                      .watch<AppearanceController>()
                                      .secondaryColor,
                                ),
                          ),
                          Text(p.timeLabel,
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                              color: context
                                  .watch<AppearanceController>()
                                  .secondaryColor.withAlpha(128),
                            ),)
                        ],
                      ),
                      Row(
                        children: [
                          Text(
                            formatSmartDate(p.startDate),
                            style: Theme.of(context).textTheme.bodySmall!
                                .copyWith(
                                  color: context
                                      .watch<AppearanceController>()
                                      .secondaryColor
                                      .withAlpha(153),
                                ),
                          ),
                          const SizedBox(width: 8),
                          if (p.endDate != null)
                            Text(
                              '→ ${formatSmartDate(p.endDate!)}',
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(
                                    color: context
                                        .watch<AppearanceController>()
                                        .secondaryColor
                                        .withAlpha(153),
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                        ],
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
                            t.name,
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
                                color: context
                                    .watch<AppearanceController>()
                                    .secondaryColor
                                    .withAlpha(153),
                                fontWeight: FontWeight.w700,
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
