import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/health_service.dart';
import 'package:pet_satellite/services/pill_reminder_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/font_awesome_icons.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/food_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/mood_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/pill_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/treatment_sheet.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/weight_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/weight_chart.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class HealthPage extends StatefulWidget {
  final VoidCallback? onHealthChanged;
  const HealthPage({super.key, this.onHealthChanged});

  @override
  State<HealthPage> createState() => HealthPageState();
}

class HealthPageState extends State<HealthPage> {
  Pet? _profile;
  List<Event> _events = [];
  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;

  String? _weightStatus;
  double? _weightDynamics;
  String? _moodStatus;
  String? _foodStatus;

  /// Ids of health badges the user has dismissed.
  Set<String> _dismissedBadgeIds = {};

  List<HealthBadge> _healthBadges = [];

  // Period for the inline weight chart
  HistoryPeriod _chartPeriod = HistoryPeriod.halfYear;

  bool _weightExpanded = true;
  bool _treatmentsExpanded = true;
  bool _pillsExpanded = true;

  static const _kWeightExpanded = 'health_section_weight';
  static const _kTreatmentsExpanded = 'health_section_treatments';
  static const _kPillsExpanded = 'health_section_pills';

  @override
  void initState() {
    super.initState();
    _loadSectionStates();
    _initScreen();
  }

  Future<void> _loadSectionStates() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _weightExpanded = prefs.getBool(_kWeightExpanded) ?? true;
      _treatmentsExpanded = prefs.getBool(_kTreatmentsExpanded) ?? true;
      _pillsExpanded = prefs.getBool(_kPillsExpanded) ?? true;
    });
  }

  Future<void> _saveSectionState(String key, bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(key, value);
  }

  /// Called by [MainPage] via GlobalKey to reload data when the tab becomes active.
  void refresh() => _initScreen();

  Future<void> _dismissBadge(String id) async {
    if (_profile == null) return;
    final wasOk = _isOkScore(_healthBadges);
    _dismissedBadgeIds.add(id);
    await HealthAnalyzer.saveDismissed(
      _dismissedBadgeIds.toList(),
      _profile!.id,
    );
    // Re-analyze so the "Всё в порядке" badge appears automatically when
    // nothing else remains.
    final newBadges = await HealthAnalyzer.analyze(_profile!, _events);
    if (!mounted) return;
    setState(() => _healthBadges = newBadges);
    widget.onHealthChanged?.call();
    if (!wasOk && _isOkScore(newBadges)) {
      _playCelebration();
    }
  }

  bool _isOkScore(List<HealthBadge> badges) {
    final danger = badges
        .where((b) => b.severity == HealthBadgeSeverity.danger)
        .length;
    final warning = badges
        .where((b) => b.severity == HealthBadgeSeverity.warning)
        .length;
    return danger == 0 && warning < 3;
  }

  void _playCelebration() {
    HapticFeedback.mediumImpact();
    final overlay = Overlay.of(context, rootOverlay: true);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _HealthCelebrationOverlay(
        color: ThemeColors.ok.mainColor,
        onDone: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  Future<void> _initScreen() async {
    setState(() {
      _isLoadingProfile = true;
      _isLoadingEvents = true;
    });

    final profile = await PetService().loadActiveProfile();
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
    final foodStatus = await PetService().lastFoodString();
    final moodStatus = await PetService().lastMoodString();
    final events = await EventService().loadEvents(profile.id);
    final dismissedBadgeIds = await HealthAnalyzer.loadDismissed(_profile!.id);
    final healthBadges = await HealthAnalyzer.analyze(_profile!, events);

    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoadingEvents = false;
      _weightStatus = weightStatus;
      _weightDynamics = weightDynamics;
      _foodStatus = foodStatus;
      _moodStatus = moodStatus;
      _dismissedBadgeIds = dismissedBadgeIds.toSet();
      _healthBadges = healthBadges;
    });
  }

  // ── Sheet openers ──────────────────────────────────────────────────────────

  void _openWeightHistory(BuildContext context) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => WeightSheet(profile: _profile!),
    );
    // Always reload — user may have added/deleted data even if they swiped to close.
    if (mounted) await _initScreen();
  }

  void _openMoodHistory(BuildContext context) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => MoodSheet(profile: _profile!),
    );
    if (mounted) await _initScreen();
  }

  void _openFoodHistory(BuildContext context) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => FoodSheet(profile: _profile!),
    );
    if (mounted) await _initScreen();
  }

  void _openTreatments(
    BuildContext context, {
    TreatmentKind kind = TreatmentKind.rabies,
  }) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentSheet(profile: _profile!, presetKind: kind),
    );
    if (mounted) await _initScreen();
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

    await showModalBottomSheet<bool>(
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
    if (mounted) await _initScreen();
  }

  void _openPillReminders(BuildContext context) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PillReminderSheet(profile: _profile!),
    );
    if (mounted) await _initScreen();
  }

  void _openPillReminder(BuildContext context, Pill reminder) async {
    if (_profile == null) return;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => PillDetailSheet(profile: _profile!, reminder: reminder),
    );
    if (mounted) await _initScreen();
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
  /// - [Event] with category 'health'
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
    // Только последняя запись по каждому (kind, name): свежая запись
    // означает, что более ранняя обработка уже выполнена.
    final latestByKey = <String, TreatmentEntry>{};
    for (final t in _profile!.treatmentHistory.entries) {
      final key = t.kind == TreatmentKind.vaccine
          ? 'vaccine:${t.name}'
          : t.kind.name;
      final existing = latestByKey[key];
      if (existing == null || t.date.isAfter(existing.date)) {
        latestByKey[key] = t;
      }
    }
    for (final t in latestByKey.values) {
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
            : 'Через $daysLeft ${dayDeclension(daysLeft)}';
      } else {
        severity = HealthBadgeSeverity.info;
        subtitle =
            'Через $daysLeft ${dayDeclension(daysLeft)} · '
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
            : 'Через $daysLeft ${dayDeclension(daysLeft)}';
      } else {
        severity = HealthBadgeSeverity.info;
        subtitle =
            'Через $daysLeft ${dayDeclension(daysLeft)} · '
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

    ({String caption, String label, ColorPalette palette, IconData icon})?
    healthScore;

    if (_profile != null && !_isLoadingEvents) {
      healthScore = HealthAnalyzer.score(_healthBadges);
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
                    onTap: _healthBadges.isNotEmpty
                        ? () => _openRecommendations(context, _healthBadges)
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
                            '${formatSmartDate(_profile!.moodHistory.lastEntry!.date, pattern: 'd MMMM')}'
                            ' · ${_profile!.moodHistory.lastEntry!.dayPart.label}',
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
            CollapsibleSection(
              expanded: _weightExpanded,
              onToggle: () {
                setState(() => _weightExpanded = !_weightExpanded);
                _saveSectionState(_kWeightExpanded, _weightExpanded);
              },
              titleContent: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Вес', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 8),
                  Text('•', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(width: 4),
                  PopupMenuButton<HistoryPeriod>(
                    initialValue: _chartPeriod,
                    onSelected: (p) => setState(() => _chartPeriod = p),
                    itemBuilder: (_) => [
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
              trailing: TextButton.icon(
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
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 8),
                  GlassPlate(
                    child: Column(
                      children: [
                        WeightChart(entries: weightEntries, height: 180),
                        if (_profile != null &&
                            _profile!.weightHistory.entries.length >= 3)
                          Padding(
                            padding: const EdgeInsets.symmetric(
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Прививки и обработки ──────────────────────────────────────────
            CollapsibleSection(
              expanded: _treatmentsExpanded,
              onToggle: () {
                setState(() => _treatmentsExpanded = !_treatmentsExpanded);
                _saveSectionState(_kTreatmentsExpanded, _treatmentsExpanded);
              },
              titleContent: Text(
                'Прививки и обработки',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              // "Добавить" hidden when list is empty — the empty state already
              // has its own inline "Добавить" link.
              trailing: activeTreatments.isNotEmpty
                  ? TextButton.icon(
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
                          ? () => _openTreatments(context)
                          : null,
                    )
                  : null,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 12),
                  InlineLoading(
                    isLoading: _isLoadingProfile,
                    child: _profile == null
                        ? const SizedBox.shrink()
                        : activeTreatments.isEmpty
                        ? Column(
                            children: [
                              const SizedBox(height: 32),
                              Icon(
                                Icons.vaccines,
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
                                    'Нет прививок.',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
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
                                    onPressed: () => _openTreatments(context),
                                    child: Text(
                                      'Добавить',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
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
                ],
              ),
            ),

            const SizedBox(height: 12),

            // ── Препараты ─────────────────────────────────────────────────────
            CollapsibleSection(
              expanded: _pillsExpanded,
              onToggle: () {
                setState(() => _pillsExpanded = !_pillsExpanded);
                _saveSectionState(_kPillsExpanded, _pillsExpanded);
              },
              titleContent: Text(
                'Препараты',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              trailing: activeReminders != null && activeReminders.isNotEmpty
                  ? TextButton.icon(
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
                    )
                  : null,
              body: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 4),
                  InlineLoading(
                    isLoading: _isLoadingProfile,
                    child: _profile == null || activeReminders == null
                        ? const SizedBox.shrink()
                        : activeReminders.isEmpty
                        ? Column(
                            children: [
                              const SizedBox(height: 32),
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
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleLarge!
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
                                    onPressed: () =>
                                        _openPillReminders(context),
                                    child: Text(
                                      'Добавить',
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleLarge!
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
                                    padding:
                                        const EdgeInsets.only(bottom: 8),
                                    child: _PillReminderTile(
                                      reminder: r,
                                      petId: _profile!.id,
                                      onReload: () => {},
                                      onTap: () =>
                                          _openPillReminder(context, r),
                                    ),
                                  ),
                                )
                                .toList(),
                          ),
                  ),
                ],
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
        useShadow: false,
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
      body: _badges.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.favorite,
                    size: 64,
                    color: ThemeColors.ok.mainColor.withAlpha(180),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Всё в порядке',
                    style: Theme.of(context).textTheme.titleLarge!.copyWith(
                      fontWeight: FontWeight.w700,
                      color: ThemeColors.ok.mainColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Рекомендаций больше нет',
                    style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                      color: ThemeColors.textPrimary.withAlpha(160),
                    ),
                  ),
                ],
              ),
            )
          : Column(
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

// ─── Тайл таблетки ───────────────────────────────────────────────────────────

class _PillReminderTile extends StatefulWidget {
  final Pill reminder;
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

    // «По требованию»: никогда не «пропущено» — пользователь сам решает, когда дать.
    if (widget.reminder.frequencyType == PillFrequencyType.onDemand) {
      final taken = widget.reminder.isTakenOnDay(now);
      return (
        color: taken ? ThemeColors.ok.mainColor : ThemeColors.info.mainColor,
        label: taken ? 'Принято сегодня' : 'По требованию',
        icon: taken ? Icons.check_circle_outline : Icons.alarm_on_outlined,
      );
    }

    final total = widget.reminder.schedules.length;
    final count = widget.reminder.countTakenOnDay(now);

    if (count >= total) {
      return (
        color: ThemeColors.ok.mainColor,
        label: 'Принято',
        icon: Icons.check_circle_outline,
      );
    }

    if (count > 0) {
      return (
        color: ThemeColors.ok.mainColor,
        label: '$count/$total принято',
        icon: Icons.check_circle_outline,
      );
    }

    // None taken — check whether all scheduled times have already passed.
    final allPassed = widget.reminder.schedules.every((s) {
      final scheduled = DateTime(now.year, now.month, now.day, s.hour, s.minute);
      return now.isAfter(scheduled);
    });

    if (allPassed) {
      return (
        color: ThemeColors.warning.mainColor,
        label: 'Пропущено',
        icon: Icons.warning_amber_rounded,
      );
    }

    return (
      color: ThemeColors.info.mainColor,
      label: 'Сегодня · ${widget.reminder.timeLabel}',
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
        useShadow: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          child: Row(
            children: [
              SoftRoundedIcon(
                icon: widget.reminder.kind?.icon ?? Icons.medication_outlined,
                color: widget.reminder.color != null ? Color(widget.reminder.color!) : accent,
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
              if (widget.reminder.schedules.length > 1)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.chevron_right,
                    color: ThemeColors.secondary,
                    size: 26,
                  ),
                )
              else if (scheduledToday)
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
  final Pill reminder;

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

// ─── Celebration overlay when all recommendations are resolved ───────────────

class _HealthCelebrationOverlay extends StatefulWidget {
  final Color color;
  final VoidCallback onDone;

  const _HealthCelebrationOverlay({required this.color, required this.onDone});

  @override
  State<_HealthCelebrationOverlay> createState() =>
      _HealthCelebrationOverlayState();
}

class _CelebrationParticle {
  final double startX; // 0..1 fraction of width
  final double driftX; // horizontal drift, in pixels
  final double rise;   // upward travel, in pixels
  final double size;
  final double delay;  // 0..1 of total duration
  final IconData icon;
  final double rotation;

  _CelebrationParticle({
    required this.startX,
    required this.driftX,
    required this.rise,
    required this.size,
    required this.delay,
    required this.icon,
    required this.rotation,
  });
}

class _HealthCelebrationOverlayState extends State<_HealthCelebrationOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final List<_CelebrationParticle> _particles;
  static const _icons = [
    Icons.favorite,
    Icons.favorite_border,
    Icons.star_rounded,
    Icons.auto_awesome,
    Icons.check_circle,
  ];

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _particles = List.generate(18, (_) {
      return _CelebrationParticle(
        startX: 0.15 + rng.nextDouble() * 0.7,
        driftX: (rng.nextDouble() - 0.5) * 120,
        rise: 220 + rng.nextDouble() * 220,
        size: 18 + rng.nextDouble() * 22,
        delay: rng.nextDouble() * 0.35,
        icon: _icons[rng.nextInt(_icons.length)],
        rotation: (rng.nextDouble() - 0.5) * 1.2,
      );
    });
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onDone();
      });
    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final startY = size.height * 0.62;
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, _) {
          return Stack(
            children: [
              // Soft radial flash behind the score badge.
              Positioned.fill(
                child: Opacity(
                  opacity: (1 - _ctrl.value).clamp(0.0, 1.0) * 0.35,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: Alignment(0, -0.4),
                        radius: 0.6 + _ctrl.value * 0.4,
                        colors: [
                          widget.color.withAlpha(120),
                          widget.color.withAlpha(0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              ..._particles.map((p) {
                final localT = ((_ctrl.value - p.delay) / (1 - p.delay))
                    .clamp(0.0, 1.0);
                final eased = Curves.easeOut.transform(localT);
                final x = size.width * p.startX + p.driftX * eased;
                final y = startY - p.rise * eased;
                final scale = localT < 0.15
                    ? localT / 0.15
                    : 1.0 - (localT - 0.6).clamp(0.0, 0.4) * 1.5;
                final opacity = (1.0 - eased).clamp(0.0, 1.0);
                return Positioned(
                  left: x - p.size / 2,
                  top: y - p.size / 2,
                  child: Opacity(
                    opacity: opacity,
                    child: Transform.rotate(
                      angle: p.rotation * eased,
                      child: Transform.scale(
                        scale: scale.clamp(0.0, 1.2),
                        child: Icon(
                          p.icon,
                          color: widget.color,
                          size: p.size,
                        ),
                      ),
                    ),
                  ),
                );
              }),
              // Center "Всё в порядке" label that pops in and fades.
              Positioned(
                left: 0,
                right: 0,
                top: size.height * 0.4,
                child: Center(
                  child: Opacity(
                    opacity: (_ctrl.value < 0.7
                            ? (_ctrl.value / 0.2).clamp(0.0, 1.0)
                            : (1 - (_ctrl.value - 0.7) / 0.3))
                        .clamp(0.0, 1.0),
                    child: Transform.scale(
                      scale: 0.7 + Curves.easeOutBack
                              .transform(_ctrl.value.clamp(0.0, 1.0)) *
                          0.4,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 18, vertical: 10),
                        decoration: BoxDecoration(
                          color: widget.color.withAlpha(40),
                          borderRadius: BorderRadius.circular(100),
                          border: Border.all(
                            color: widget.color.withAlpha(120),
                            width: 1.5,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.favorite,
                                color: widget.color, size: 22),
                            const SizedBox(width: 8),
                            Text(
                              'Всё в порядке',
                              style: TextStyle(
                                color: widget.color,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
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
          );
        },
      ),
    );
  }
}
