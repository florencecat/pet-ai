import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/font_awesome_icons.dart';
import 'package:pet_ai/theme/widgets/activity_indicator.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/food_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/mood_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/treatment_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/weight_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

class HealthPage extends StatefulWidget {
  const HealthPage({super.key});

  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  PetProfile? _profile;
  List<PetEvent> _events = [];
  bool _isLoadingProfile = true;
  bool _isLoadingEvents = true;

  String? _weightStatus;
  double? _weightDynamics;

  String? _moodStatus;
  String? _foodStatus;

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
      if (mounted) setState(() => _isLoadingProfile = false);
      return;
    }

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _isLoadingProfile = false;
    });

    final weightStatus = _profile?.weightHistory.lastWeightString();
    final weightDynamics = _profile?.weightHistory.weightDynamic();
    final foodStatus = await ProfileService().lastFoodString();
    final moodStatus = await ProfileService().lastMoodString();

    final events = await EventService().loadEvents(profile.id);
    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoadingEvents = false;
      _weightStatus = weightStatus;
      _weightDynamics = weightDynamics;
      _foodStatus = foodStatus;
      _moodStatus = moodStatus;
    });
  }

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

  void _openTreatments(BuildContext context) async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentSheet(profile: _profile!),
    );
    if (updated == true) await _initScreen();
  }

  List<PetEvent> _upcomingVaccinations() {
    final now = DateTime.now();
    return _events
        .where(
          (e) =>
              e.category.id == 'vaccination' &&
              (e.dateTime.isAfter(now) ||
                  DateTime(
                    e.dateTime.year,
                    e.dateTime.month,
                    e.dateTime.day,
                  ).isAtSameMomentAs(DateTime(now.year, now.month, now.day))),
        )
        .toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
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

    final vaccinations = _isLoadingEvents
        ? <PetEvent>[]
        : _upcomingVaccinations();

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Здоровье'),
                      if (_profile != null)
                        Text(
                          _profile!.name,
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

                if (healthScore != null)
                  Expanded(child: _HealthScoreBadge(score: healthScore)),
              ],
            ),

            const SizedBox(height: 16),

            // ── Блок здоровья ────────────────────────────────────────────────
            GlassCard(
              callback: null,
              transparent: false,
              child: InlineLoading(
                isLoading: _isLoadingProfile || _isLoadingEvents,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        flex: 4,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              healthScore?.caption ?? '...',
                              style: Theme.of(context).textTheme.titleLarge!
                                  .copyWith(
                                    color: healthScore?.palette.mainColor,
                                    inherit: true,
                                  ),
                            ),
                            if (healthBadges != null)
                              ...healthBadges
                                  .where(
                                    (b) =>
                                        b.severity ==
                                            HealthBadgeSeverity.danger ||
                                        b.severity ==
                                            HealthBadgeSeverity.warning,
                                  )
                                  .take(2)
                                  .map(
                                    (b) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: SoftGlassBadge(
                                        icon: b.icon ?? b.severity.icon,
                                        label: b.title,
                                        color: b.severity.palette.mainColor,
                                        selected: false,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Быстрые действия ────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Сегодня',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            Row(
              spacing: 8,
              children: [
                _HealthActionButton(
                  callback: () => _openWeightHistory(context),
                  icon: FontAwesome.weight,
                  iconColor: ThemeColors.weightIconColor,
                  caption: _weightStatus,
                  topRightWidget: _weightDynamics != null
                      ? dynamicsTextWidget(
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
                ),
                _HealthActionButton(
                  callback: () => _openFoodHistory(context),
                  icon: Icons.fastfood,
                  iconColor: ThemeColors.foodIconColor,
                  caption: _foodStatus,
                ),
              ],
            ),

            const SizedBox(height: 16),

            // ── Прививки и обработки ─────────────────────────────────────────
            GlassCard(
              color: context.watch<AppearanceController>().primaryColor,
              callback: () => _openTreatments(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.vaccines, color: Colors.white),
                    const SizedBox(width: 8),
                    Text(
                      'Прививки и обработки',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),

            // ── Ближайшие прививки ───────────────────────────────────────────
            if (!_isLoadingEvents && vaccinations.isNotEmpty) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Ближайшие прививки',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              ...vaccinations.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _VaccinationTile(event: e),
                ),
              ),
            ],

            // ── Рекомендации ─────────────────────────────────────────────────
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 8),
              child: Text(
                'Рекомендации',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            InlineLoading(
              isLoading: _isLoadingProfile || _isLoadingEvents,
              child: healthBadges == null
                  ? const SizedBox.shrink()
                  : Column(
                      children: healthBadges
                          .map((b) => HealthBadgeTile(badge: b))
                          .toList(),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HealthScoreBadge extends StatelessWidget {
  final ({String caption, String label, ColorPalette palette, IconData icon})
  score;

  const _HealthScoreBadge({required this.score});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      titleAlignment: ListTileTitleAlignment.center,
      tileColor: score.palette.mainColor.withAlpha(92),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadiusGeometry.circular(100),
      ),
      leading: Icon(score.icon, color: score.palette.darkShade, size: 30),
      title: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'оценка',
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              color: score.palette.darkShade.withAlpha(164),
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            score.caption,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              color: score.palette.darkShade,
            ),
          ),
        ],
      ),
      trailing: Icon(
        Icons.chevron_right,
        color: score.palette.darkShade,
        size: 20,
      ),
    );
  }
}

class _HealthActionButton extends StatelessWidget {
  final VoidCallback callback;
  final IconData icon;
  final Color iconColor;
  final String? caption;
  final Widget? topRightWidget;
  final Widget? bottomWidget;

  const _HealthActionButton({
    required this.callback,
    required this.icon,
    required this.iconColor,
    required this.caption,
    this.topRightWidget,
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
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [softIcon, ?topRightWidget],
            ),

            const SizedBox(height: 12),
            if (caption != null)
              Text(
                caption!,
                textAlign: TextAlign.left,
                style: Theme.of(
                  context,
                ).textTheme.titleSmall!.copyWith(inherit: true),
              ),
          ],
        ),
      ),
    );
  }
}

class _VaccinationTile extends StatelessWidget {
  final PetEvent event;

  const _VaccinationTile({required this.event});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final eventDay = DateTime(
      event.dateTime.year,
      event.dateTime.month,
      event.dateTime.day,
    );
    final daysLeft = eventDay.difference(today).inDays;

    String daysLabel;
    if (daysLeft == 0) {
      daysLabel = 'Сегодня';
    } else if (daysLeft == 1) {
      daysLabel = 'Завтра';
    } else {
      daysLabel = 'Через $daysLeft ${_daysWord(daysLeft)}';
    }

    return GlassPlate(
      child: ListTile(
        leading: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: event.category.color.withAlpha(40),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.vaccines, color: event.category.color, size: 20),
        ),
        title: Text(
          event.name,
          style: Theme.of(
            context,
          ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${DateFormat('dd.MM.yyyy', 'ru').format(event.dateTime)} · $daysLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color:
                (daysLeft <= 7
                        ? ThemeColors.warning.mainColor
                        : context.watch<AppearanceController>().primaryColor)
                    .withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            daysLabel,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: daysLeft <= 7
                  ? ThemeColors.warning.mainColor
                  : context.watch<AppearanceController>().primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  static String _daysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дней';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дней';
  }
}
