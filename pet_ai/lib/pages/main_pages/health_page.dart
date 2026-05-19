import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/history.dart';
import 'package:pet_ai/models/pill_reminder.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/models/weight.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/pill_reminder_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/font_awesome_icons.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/food_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/mood_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/pill_reminder_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/treatment_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/weight_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:pet_ai/theme/widgets/weight_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => HealthPageState();
}

class HealthPageState extends State<HealthPage> {
  PetProfile? _profile;
  List<PetEvent> _events = [];
  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;

  String? _weightStatus;
  double? _weightDynamics;
  String? _moodStatus;
  String? _foodStatus;

  /// Ids of health badges the user has dismissed.
  Set<String> _dismissedBadgeIds = {};

  // Period for the inline weight chart
  HistoryPeriod _chartPeriod = HistoryPeriod.halfYear;

  @override
  void initState() {
    super.initState();
    _initScreen();
  }

  /// Called by [MainPage] via GlobalKey to reload data when the tab becomes active.
  void refresh() => _initScreen();

  String _dismissedKey(String petId) => 'dismissed_health_badges_$petId';

  Future<void> _saveDismissed(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedKey(petId),
      _dismissedBadgeIds.toList(),
    );
  }

  Future<void> _dismissBadge(String id) async {
    if (_profile == null) return;
    setState(() => _dismissedBadgeIds.add(id));
    await _saveDismissed(_profile!.id);
  }

  Future<void> _initScreen() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingEvents = true;
    });

    final profile = await ProfileService().loadActiveProfile();
    if (profile == null) {
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });

    final weightStatus = profile.weightHistory.lastWeightString();
    final weightDynamics = profile.weightHistory.weightDynamic();
    final foodStatus = await ProfileService().lastFoodString();
    final moodStatus = await ProfileService().lastMoodString();
    final events = await EventService().loadEvents(profile.id);
    final prefs = await SharedPreferences.getInstance();
    final dismissed = prefs.getStringList(_dismissedKey(profile.id)) ?? [];

    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoadingEvents = false;
      _weightStatus = weightStatus;
      _weightDynamics = weightDynamics;
      _foodStatus = foodStatus;
      _moodStatus = moodStatus;
      _dismissedBadgeIds = dismissed.toSet();
    });
  }

  // ── Sheet openers ──────────────────────────────────────────────────────────

  void _openWeightHistory(BuildContext context) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeightSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  void _openMoodHistory(BuildContext context) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  void _openFoodHistory(BuildContext context) async {
    if (_profile == null) return;
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

  void _openTreatments(
    BuildContext context, {
    TreatmentKind kind = TreatmentKind.rabies,
  }) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentSheet(profile: _profile!, presetKind: kind),
    );
    if (updated == true) await _initScreen();
  }

  void _openTreatment(BuildContext context, TreatmentEntry entry) async {
    if (_profile == null) return;
    final related =
        _profile!.treatmentHistory.entries
            .where(
              (e) =>
                  e.kind == entry.kind &&
                  (entry.kind != TreatmentKind.vaccine || e.name == entry.name),
            )
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));

    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentDetailSheet(
        profile: _profile!,
        kind: entry.kind,
        vaccineName: entry.kind == TreatmentKind.vaccine ? entry.name : null,
        entries: related,
        onDeleted: (deleted) {
          setState(() {
            _profile!.treatmentHistory.entries.removeWhere(
              (e) =>
                  e.date == deleted.date &&
                  e.kind == deleted.kind &&
                  e.name == deleted.name,
            );
          });
        },
      ),
    );
    if (updated == true) await _initScreen();
  }

  void _openPillReminders(BuildContext context) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PillReminderSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  void _openPillReminder(BuildContext context, PillReminder reminder) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PillDetailSheet(profile: _profile!, reminder: reminder),
    );
    if (updated == true && mounted) {
      // Refresh local list if the reminder was deleted inside
      final fresh = await ProfileService().loadProfile(_profile!.id);
      if (fresh != null && mounted) {
        setState(() {
          _profile!.pillReminders
            ..clear()
            ..addAll(fresh.pillReminders);
        });
      }
    }
  }

  void _openRecommendations(BuildContext context, List<HealthBadge> badges) {
    final visible = badges
        .where((b) => b.id == null || !_dismissedBadgeIds.contains(b.id))
        .toList();
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _RecommendationsSheet(
        badges: visible,
        onDismiss: _profile != null ? _dismissBadge : null,
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  /// Picks the single most relevant upcoming/overdue health event to surface
  /// in the alert banner. Only considers time-bound, health-related items:
  /// - [TreatmentEntry] records (all have a [nextDate])
  /// - [PetEvent] with category 'health'
  ///
  /// Sort order: overdue danger first (most overdue = earliest date first),
  /// then warning (soonest upcoming within remindBeforeDays / 7d),
  /// then info (any future event, nearest first).
  HealthBadge? _nextHealthAlert() {
    if (_profile == null) return null;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // Unified candidate record
    final candidates =
        <
          ({
            String title,
            String subtitle,
            DateTime date,
            HealthBadgeSeverity severity,
            IconData icon,
          })
        >[];

    // ── TreatmentEntry ─────────────────────────────────────────────────────
    for (final t in _profile!.treatmentHistory.entries) {
      final next = DateTime(t.nextDate.year, t.nextDate.month, t.nextDate.day);
      final daysLeft = next.difference(today).inDays;
      final HealthBadgeSeverity severity;
      final String subtitle;

      if (daysLeft < 0) {
        severity = HealthBadgeSeverity.danger;
        subtitle = 'Должно было быть ${formatSmartDate(t.nextDate)}';
      } else if (daysLeft <= t.remindBeforeDays) {
        severity = HealthBadgeSeverity.warning;
        subtitle = daysLeft == 0
            ? 'Сегодня'
            : 'Через $daysLeft ${declension(daysLeft, 'день', 'дня', 'дней')}';
      } else {
        severity = HealthBadgeSeverity.info;
        subtitle =
            'Через $daysLeft ${declension(daysLeft, 'день', 'дня', 'дней')} · '
            '${DateFormat('dd.MM.yyyy').format(t.nextDate)}';
      }

      candidates.add((
        title: t.displayName,
        subtitle: subtitle,
        date: next,
        severity: severity,
        icon: t.kind.icon,
      ));
    }

    // ── PetEvent (category: health, non-repeating) ────────────────────────
    for (final e in _events) {
      if (e.category.id != 'health') continue;
      if (e.repeat != RepeatInterval.none) {
        continue;
      } // repeating events don't become overdue
      final eventDay = DateTime(
        e.dateTime.year,
        e.dateTime.month,
        e.dateTime.day,
      );
      final daysLeft = eventDay.difference(today).inDays;
      final HealthBadgeSeverity severity;
      final String subtitle;

      if (daysLeft < 0) {
        severity = HealthBadgeSeverity.danger;
        subtitle = 'Должно было быть ${formatSmartDate(e.dateTime)}';
      } else if (daysLeft <= 7) {
        severity = HealthBadgeSeverity.warning;
        subtitle = daysLeft == 0
            ? 'Сегодня'
            : 'Через $daysLeft ${declension(daysLeft, 'день', 'дня', 'дней')}';
      } else {
        severity = HealthBadgeSeverity.info;
        subtitle =
            'Через $daysLeft ${declension(daysLeft, 'день', 'дня', 'дней')} · '
            '${DateFormat('dd.MM.yyyy').format(e.dateTime)}';
      }

      candidates.add((
        title: e.name,
        subtitle: subtitle,
        date: eventDay,
        severity: severity,
        icon: e.category.icon,
      ));
    }

    if (candidates.isEmpty) return null;

    // Sort: danger → warning → info; within same severity by date ascending
    // (overdue: most overdue = smallest date; upcoming: nearest = smallest date)
    const order = [
      HealthBadgeSeverity.danger,
      HealthBadgeSeverity.warning,
      HealthBadgeSeverity.info,
      HealthBadgeSeverity.ok,
    ];
    candidates.sort((a, b) {
      final si = order.indexOf(a.severity).compareTo(order.indexOf(b.severity));
      return si != 0 ? si : a.date.compareTo(b.date);
    });

    final top = candidates.first;
    return HealthBadge(
      title: top.title,
      subtitle: top.subtitle,
      severity: top.severity,
      icon: top.icon,
    );
  }

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;

    List<HealthBadge>? healthBadges;
    ({String caption, String label, ColorPalette palette, IconData icon})?
    healthScore;

    if (_profile != null && !_isLoadingEvents) {
      healthBadges = HealthAnalyzer.analyze(_profile!, _events);
      healthScore = HealthAnalyzer.score(healthBadges);
    }

    // Nearest time-bound health event (treatment nextDate or health category event)
    final topAlert = (!_isLoadingProfile && !_isLoadingEvents)
        ? _nextHealthAlert()
        : null;

    // Weight chart entries filtered by period
    final weightEntries =
        _profile?.weightHistory.filterByPeriod(_chartPeriod) ?? [];

    final activeReminders =
        _profile?.pillReminders.where((r) => r.isActive).toList()
          ?..sort((a, b) => a.name.compareTo(b.name));

    // TreatmentKind.values.map((kind) {
    //   final last = _profile!.treatmentHistory.lastOfKind(
    //     kind,
    //   );

    List<TreatmentEntry> activeTreatments = [];
    for (var kind in TreatmentKind.values) {
      final entry = _profile?.treatmentHistory.lastOfKind(kind);
      if (entry != null) {
        activeTreatments.add(entry);
      }
    }

    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 100),
          children: [
            // ── Header ───────────────────────────────────────────────────────
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Здоровье'),
                      if (_profile != null)
                        Text(
                          _profile!.name,
                          style: Theme.of(context).textTheme.headlineMedium!
                              .copyWith(
                                inherit: true,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                    ],
                  ),
                ),

                if (healthScore != null)
                  _HealthScoreBadge(
                    score: healthScore,
                    onTap: healthBadges != null
                        ? () => _openRecommendations(context, healthBadges!)
                        : null,
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Nearest upcoming health event ─────────────────────────────
            if (topAlert != null) ...[
              _AlertBanner(badge: topAlert),
              const SizedBox(height: 16),
            ],

            // ── Сегодня ───────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Сегодня',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),

            IntrinsicHeight(
              child: Row(
                spacing: 8,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _HealthActionButton(
                    callback: () => _openWeightHistory(context),
                    icon: FontAwesome.weight,
                    iconColor: ThemeColors.weightIconColor,
                    caption: _weightStatus,
                    bottomWidget: _weightDynamics != null
                        ? dynamicsBadge(
                            _weightDynamics!,
                            Theme.of(context).textTheme.bodySmall!,
                          )
                        : null,
                  ),
                  _HealthActionButton(
                    callback: () => _openMoodHistory(context),
                    icon: Icons.sentiment_very_satisfied_outlined,
                    iconColor: ThemeColors.moodIconColor,
                    caption: _moodStatus,
                    bottomWidget:
                        _profile != null &&
                            _profile!.moodHistory.lastEntry != null
                        ? Text(
                            formatSmartDate(
                              _profile!.moodHistory.lastEntry!.date,
                              pattern: 'd MMMM',
                            ),
                            style: Theme.of(context).textTheme.bodySmall!,
                          )
                        : null,
                  ),
                  _HealthActionButton(
                    callback: () => _openFoodHistory(context),
                    icon: Icons.fastfood,
                    iconColor: ThemeColors.foodIconColor,
                    caption: _foodStatus,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // ── Вес ──────────────────────────────────────────────────────────
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  children: [
                    _PageTitle('Вес'),
                    const SizedBox(width: 8),
                    Text('•', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(width: 4),
                    PopupMenuButton<HistoryPeriod>(
                      initialValue: _chartPeriod,
                      onSelected: (p) => setState(() => _chartPeriod = p),
                      itemBuilder: (_) =>
                          [
                                HistoryPeriod.month,
                                HistoryPeriod.halfYear,
                                HistoryPeriod.year,
                                HistoryPeriod.all,
                              ]
                              .map(
                                (p) => PopupMenuItem(
                                  value: p,
                                  child: Text(_periodLabel(p)),
                                ),
                              )
                              .toList(),
                      borderRadius: BorderRadius.circular(8),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const SizedBox(width: 4),
                          Text(
                            _periodLabel(_chartPeriod),
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  color: context
                                      .watch<AppearanceController>()
                                      .secondaryColor,
                                ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.expand_more,
                            size: 24,
                            color: context
                                .watch<AppearanceController>()
                                .secondaryColor,
                          ),
                          const SizedBox(width: 4),
                        ],
                      ),
                    ),
                  ],
                ),

                TextButton.icon(
                  onPressed: () => _openWeightHistory(context),
                  label: Text(
                    'Детали',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  icon: Icon(
                    Icons.chevron_right,
                    color: context.watch<AppearanceController>().secondaryColor,
                  ),
                  iconAlignment: IconAlignment.end,
                ),
              ],
            ),

            const SizedBox(height: 8),

            GlassPlate(
              child: Column(
                children: [
                  WeightChart(entries: weightEntries, height: 180),
                  if (_profile != null &&
                      _profile!.weightHistory.entries.length >= 3)
                    Padding(
                      padding: EdgeInsetsGeometry.symmetric(
                        vertical: 4,
                        horizontal: 8,
                      ),
                      child: _WeightSummaryRow(
                        history: _profile!.weightHistory,
                      ),
                    ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            Row(
              children: [
                Expanded(child: _PageTitle('Прививки и обработки')),
                TextButton.icon(
                  iconAlignment: IconAlignment.end,
                  label: Text(
                    'Добавить',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  icon: Icon(
                    Icons.chevron_right,
                    color: context.watch<AppearanceController>().secondaryColor,
                  ),
                  onPressed: _profile != null
                      ? () => _openTreatments(context)
                      : null,
                ),
              ],
            ),

            const SizedBox(height: 12),

            InlineLoading(
              isLoading: _isLoadingProfile,
              child: _profile == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: activeTreatments.map((entry) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: _TreatmentStatusTile(
                            kind: entry.kind,
                            lastEntry: entry,
                            onTap: () => _openTreatment(context, entry),
                          ),
                        );
                      }).toList(),
                    ),
            ),

            const SizedBox(height: 12),

            // ── Препараты ─────────────────────────────────────────────────
            Row(
              children: [
                Expanded(child: _PageTitle('Препараты')),
                if (activeReminders != null && activeReminders.isNotEmpty)
                  TextButton.icon(
                    iconAlignment: IconAlignment.end,
                    label: Text(
                      'Добавить',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    icon: Icon(
                      Icons.chevron_right,
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                    ),
                    onPressed: _profile != null
                        ? () => _openPillReminders(context)
                        : null,
                  ),
              ],
            ),

            const SizedBox(height: 4),

            InlineLoading(
              isLoading: _isLoadingProfile,
              child: _profile == null || activeReminders == null
                  ? const SizedBox.shrink()
                  : activeReminders.isEmpty
                  ? Column(
                      children: [
                        SizedBox(height: 32),
                        Icon(
                          Icons.healing_outlined,
                          size: 72,
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor
                              .withAlpha(60),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Нет препаратов.',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    inherit: true,
                                    color: context
                                        .watch<AppearanceController>()
                                        .secondaryColor
                                        .withAlpha(60),
                                  ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsetsGeometry.all(5),
                              ),
                              onPressed: () => {},
                              child: Text(
                                'Добавить',
                                style: Theme.of(context).textTheme.titleLarge!
                                    .copyWith(
                                      inherit: true,
                                      color: context
                                          .watch<AppearanceController>()
                                          .primaryColor
                                          .withAlpha(192),
                                    ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    )
                  : Column(
                      children: activeReminders
                          .map(
                            (r) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _PillReminderTile(
                                reminder: r,
                                petId: _profile!.id,
                                onReload: () => {},
                                onTap: () => _openPillReminder(context, r),
                              ),
                            ),
                          )
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  String _periodLabel(HistoryPeriod p) {
    switch (p) {
      case HistoryPeriod.month:
        return '1 мес';
      case HistoryPeriod.halfYear:
        return '6 мес';
      case HistoryPeriod.year:
        return 'Год';
      case HistoryPeriod.all:
        return 'Всё';
      default:
        return '';
    }
  }
}

// ─── Оценка здоровья (кнопка в заголовке) ────────────────────────────────────

class _HealthScoreBadge extends StatelessWidget {
  final ({String caption, String label, ColorPalette palette, IconData icon})
  score;
  final VoidCallback? onTap;

  const _HealthScoreBadge({required this.score, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: score.palette.mainColor.withAlpha(40),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: score.palette.mainColor.withAlpha(80),
            width: 1.5,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(score.icon, color: score.palette.darkShade, size: 18),
            const SizedBox(width: 6),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Оценка',
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    color: score.palette.darkShade.withAlpha(160),
                    fontWeight: FontWeight.w700,
                    fontSize: 10,
                  ),
                ),
                Text(
                  score.caption,
                  style: Theme.of(context).textTheme.titleSmall!.copyWith(
                    color: score.palette.darkShade,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.chevron_right,
              color: score.palette.darkShade.withAlpha(160),
              size: 16,
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Баннер самого важного алерта ────────────────────────────────────────────

class _AlertBanner extends StatelessWidget {
  final HealthBadge badge;

  const _AlertBanner({required this.badge});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () {},
      child: GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SoftRoundedIcon(
                icon: badge.icon ?? badge.severity.icon,
                color: badge.severity.palette.mainColor,
                size: 22,
              ),

              const SizedBox(width: 12),
              // Label + dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      badge.title,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    SizedBox(height: 2),
                    SoftGlassBadge(
                      color: badge.severity.palette.mainColor,
                      label: badge.subtitle,
                      selected: false,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Кнопка быстрого действия ─────────────────────────────────────────────────

class _HealthActionButton extends StatelessWidget {
  final VoidCallback callback;
  final IconData icon;
  final Color iconColor;
  final String? caption;
  final Widget? bottomWidget;

  const _HealthActionButton({
    required this.callback,
    required this.icon,
    required this.iconColor,
    required this.caption,
    this.bottomWidget,
  });

  @override
  Widget build(BuildContext context) {
    final softIcon = SoftRoundedIcon(icon: icon, color: iconColor, size: 18);

    return Expanded(
      child: GlassCard(
        padding: 16,
        callback: callback,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [softIcon]),
            const SizedBox(height: 8),
            if (caption != null)
              Text(
                caption!,
                textAlign: TextAlign.left,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium!.copyWith(inherit: true, fontSize: 16),
              ),

            if (bottomWidget != null) ...[
              const SizedBox(height: 6),
              bottomWidget!,
            ],
          ],
        ),
      ),
    );
  }
}

// ─── Компактная сводка по весу (bottomWidget для кнопки веса) ────────────────

class _WeightSummaryRow extends StatelessWidget {
  final WeightHistory history;

  const _WeightSummaryRow({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.entries.isEmpty) return const SizedBox.shrink();

    final weights = history.entries.map((e) => e.weight).toList();
    final minW = weights.reduce((a, b) => a < b ? a : b);
    final maxW = weights.reduce((a, b) => a > b ? a : b);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _StatChip(
          label: 'мин',
          value: '${minW.toStringAsFixed(1)} кг',
          color: ThemeColors.ok.mainColor,
        ),
        _StatChip(
          label: 'макс',
          value: '${maxW.toStringAsFixed(1)} кг',
          color: ThemeColors.warning.mainColor,
        ),
      ],
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: 9,
            color: color.withAlpha(160),
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          value,
          style: Theme.of(context).textTheme.bodySmall!.copyWith(
            fontSize: 10,
            color: color,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

// ─── Тайл статуса обработки/прививки ─────────────────────────────────────────

class _TreatmentStatusTile extends StatelessWidget {
  final TreatmentKind kind;
  final TreatmentEntry? lastEntry;
  final VoidCallback onTap;

  const _TreatmentStatusTile({
    required this.kind,
    required this.lastEntry,
    required this.onTap,
  });

  ({Color color, String label, IconData icon}) _statusInfo() {
    if (lastEntry == null) {
      return (
        color: ThemeColors.secondary,
        label: 'Не заполнено',
        icon: Icons.add_circle_outline,
      );
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final next = DateTime(
      lastEntry!.nextDate.year,
      lastEntry!.nextDate.month,
      lastEntry!.nextDate.day,
    );
    final daysLeft = next.difference(today).inDays;

    if (daysLeft < 0) {
      return (
        color: ThemeColors.danger.mainColor,
        label: 'Просрочено',
        icon: Icons.error_outline,
      );
    }
    if (daysLeft <= lastEntry!.remindBeforeDays) {
      return (
        color: ThemeColors.warning.mainColor,
        label: 'Скоро ($daysLeft дн.)',
        icon: Icons.warning_amber_rounded,
      );
    }
    return (
      color: ThemeColors.ok.mainColor,
      label: 'В норме',
      icon: Icons.check_circle_outline,
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = _statusInfo();

    return GestureDetector(
      onTap: onTap,
      child: GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SoftRoundedIcon(icon: kind.icon, color: kind.color, size: 22),

              const SizedBox(width: 12),
              // Label + dates
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      kind.label,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (lastEntry != null) ...[
                      const SizedBox(height: 2),
                      SoftGlassBadge(
                        color: status.color,
                        icon: status.icon,
                        label:
                            'Следующая ${DateFormat('d MMMM yyyy', 'ru-RU').format(lastEntry!.nextDate)}',
                        selected: false,
                      ),
                    ] else ...[
                      const SizedBox(height: 4),
                      SoftGlassBadge(
                        color: status.color,
                        icon: status.icon,
                        label: status.label,
                        selected: false,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Шит «Все рекомендации» ───────────────────────────────────────────────────

class _RecommendationsSheet extends StatefulWidget {
  final List<HealthBadge> badges;
  final Future<void> Function(String id)? onDismiss;

  const _RecommendationsSheet({required this.badges, this.onDismiss});

  @override
  State<_RecommendationsSheet> createState() => _RecommendationsSheetState();
}

class _RecommendationsSheetState extends State<_RecommendationsSheet> {
  late List<HealthBadge> _badges;

  @override
  void initState() {
    super.initState();
    _badges = List.from(widget.badges);
  }

  Future<void> _dismiss(HealthBadge badge) async {
    if (badge.id == null || widget.onDismiss == null) return;
    await widget.onDismiss!(badge.id!);
    if (mounted) {
      setState(() => _badges.removeWhere((b) => b.id == badge.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableSheet(
      title: 'Рекомендации',
      centerTitle: true,
      initialSize: 0.75,
      minSize: 0.4,
      maxSize: 1.0,
      onBack: () => Navigator.of(context).pop(),
      body: Column(
        children: _badges
            .map(
              (b) => HealthBadgeTile(
                badge: b,
                onDismiss: (b.id != null && widget.onDismiss != null)
                    ? () => _dismiss(b)
                    : null,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PageTitle extends StatelessWidget {
  final String title;

  const _PageTitle(this.title);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(title, style: Theme.of(context).textTheme.titleLarge),
    );
  }
}

// ─── Тайл таблетки ───────────────────────────────────────────────────────────

class _PillReminderTile extends StatefulWidget {
  final PillReminder reminder;
  final String petId;
  final VoidCallback onReload;
  final VoidCallback onTap;

  const _PillReminderTile({
    required this.reminder,
    required this.petId,
    required this.onReload,
    required this.onTap,
  });

  @override
  State<_PillReminderTile> createState() => _PillReminderTileState();
}

class _PillReminderTileState extends State<_PillReminderTile> {
  late bool _takenToday;

  @override
  void initState() {
    super.initState();
    _takenToday = widget.reminder.isTakenOnDay(DateTime.now());
  }

  @override
  void didUpdateWidget(_PillReminderTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    _takenToday = widget.reminder.isTakenOnDay(DateTime.now());
  }

  Future<void> _toggleTaken() async {
    final wasTaken = _takenToday;
    setState(() => _takenToday = !wasTaken);
    if (!wasTaken) {
      await PillReminderService().markTaken(
        petId: widget.petId,
        reminderId: widget.reminder.id,
        date: DateTime.now(),
      );
    } else {
      await PillReminderService().markUntaken(
        petId: widget.petId,
        reminderId: widget.reminder.id,
        date: DateTime.now(),
      );
    }
    widget.onReload();
  }

  ({Color color, String label, IconData icon})? _todayStatus() {
    final now = DateTime.now();
    if (!widget.reminder.isScheduledForDay(now)) return null;

    if (_takenToday) {
      return (
        color: ThemeColors.ok.mainColor,
        label: 'Принято',
        icon: Icons.check_circle_outline,
      );
    }

    final scheduled = DateTime(
      now.year,
      now.month,
      now.day,
      widget.reminder.hour,
      widget.reminder.minute,
    );
    if (now.isAfter(scheduled)) {
      return (
        color: ThemeColors.warning.mainColor,
        label: 'Пропущено',
        icon: Icons.warning_amber_rounded,
      );
    }
    return (
      color: ThemeColors.info.mainColor,
      label: 'Сегодня в ${widget.reminder.timeLabel}',
      icon: Icons.access_time,
    );
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final scheduledToday = widget.reminder.isScheduledForDay(now);
    final status = _todayStatus();
    final accent = context.watch<AppearanceController>().primaryColor;

    return GestureDetector(
      onTap: widget.onTap,
      child: GlassPlate(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SoftRoundedIcon(
                icon: Icons.medication_outlined,
                color: accent,
                size: 22,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.reminder.name,
                      style: Theme.of(context).textTheme.titleSmall!.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    if (status != null)
                      SoftGlassBadge(
                        color: status.color,
                        icon: status.icon,
                        label: status.label,
                        selected: false,
                      )
                    else
                      _NextScheduledBadge(reminder: widget.reminder),
                  ],
                ),
              ),
              if (scheduledToday)
                GestureDetector(
                  onTap: _toggleTaken,
                  behavior: HitTestBehavior.opaque,
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: Icon(
                      _takenToday
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _takenToday
                          ? ThemeColors.ok.mainColor
                          : ThemeColors.secondary,
                      size: 26,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NextScheduledBadge extends StatelessWidget {
  final PillReminder reminder;

  const _NextScheduledBadge({required this.reminder});

  @override
  Widget build(BuildContext context) {
    final next = reminder.nextScheduledDate();
    final label = next != null
        ? 'Следующий ${formatSmartDate(next, pattern: 'd MMMM')}'
        : reminder.frequencyLabel;
    return SoftGlassBadge(
      color: ThemeColors.secondary,
      icon: Icons.schedule,
      label: label,
      selected: false,
    );
  }
}
