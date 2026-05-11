import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/health_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
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

    final weightStatus = await ProfileService().lastWeightString();
    final foodStatus = await ProfileService().lastFoodString();
    final moodStatus = await ProfileService().lastMoodString();

    if (!mounted) return;
    setState(() {
      _profile = profile;
      _weightStatus = weightStatus;
      _foodStatus = foodStatus;
      _moodStatus = moodStatus;
      _isLoadingProfile = false;
    });

    final events = await EventService().loadEvents(profile.id);
    if (!mounted) return;
    setState(() {
      _events = events;
      _isLoadingEvents = false;
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
    ({String caption, String label, Color color, IconData icon})? healthScore;
    List<Color>? healthGradient;

    if (_profile != null && !_isLoadingEvents) {
      healthBadges = HealthAnalyzer.analyze(_profile!, _events);
      healthScore = HealthAnalyzer.score(healthBadges);
      healthGradient = [Colors.transparent, healthScore.color.withAlpha(72)];
    }

    final vaccinations = _isLoadingEvents ? <PetEvent>[] : _upcomingVaccinations();

    return Scaffold(
      backgroundColor: ThemeColors.white,
      body: Container(
        decoration: context.watch<AppearanceController>().gradientDecoration,
        child: ListView(
          padding: EdgeInsets.fromLTRB(16, topPadding + 16, 16, 100),
          children: [
            // ── Заголовок страницы ──────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 12),
              child: Text(
                'Здоровье',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),

            // ── Блок здоровья ────────────────────────────────────────────────
            GlassCard(
              callback: null,
              transparent: false,
              gradientColors: healthGradient,
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
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge!
                                  .copyWith(
                                    color: healthScore?.color,
                                    inherit: true,
                                  ),
                            ),
                            if (healthBadges != null)
                              ...healthBadges
                                  .where((b) =>
                                      b.severity == HealthBadgeSeverity.danger ||
                                      b.severity == HealthBadgeSeverity.warning)
                                  .take(2)
                                  .map(
                                    (b) => Padding(
                                      padding: const EdgeInsets.only(top: 6),
                                      child: SoftGlassBadge(
                                        icon: b.icon ?? b.severity.icon,
                                        label: b.title,
                                        color: b.severity.color,
                                        selected: false,
                                      ),
                                    ),
                                  ),
                          ],
                        ),
                      ),
                      if (healthScore != null)
                        _HealthScoreCircle(score: healthScore),
                    ],
                  ),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // ── Быстрые действия ────────────────────────────────────────────
            Row(
              spacing: 8,
              children: [
                _HealthActionButton(
                  callback: () => _openWeightHistory(context),
                  emoji: '⚖️',
                  category: 'Вес',
                  caption: _weightStatus,
                ),
                _HealthActionButton(
                  callback: () => _openMoodHistory(context),
                  emoji: '😊',
                  category: 'Настроение',
                  caption: _moodStatus,
                ),
                _HealthActionButton(
                  callback: () => _openFoodHistory(context),
                  emoji: '🥣',
                  category: 'Питание',
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
            if (!_isLoadingEvents) ...[
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 8),
                child: Text(
                  'Ближайшие прививки',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              if (vaccinations.isEmpty)
                GlassPlate(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Нет запланированных прививок',
                      style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                            color: context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(153),
                          ),
                    ),
                  ),
                )
              else
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

class _HealthScoreCircle extends StatelessWidget {
  final ({String caption, String label, Color color, IconData icon}) score;

  const _HealthScoreCircle({required this.score});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: score.color.withAlpha(40),
        border: Border.all(color: score.color.withAlpha(120), width: 2),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(score.icon, size: 20, color: score.color),
          Text(
            score.label,
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: score.color,
            ),
          ),
        ],
      ),
    );
  }
}

class _HealthActionButton extends StatelessWidget {
  final VoidCallback callback;
  final String emoji;
  final String category;
  final String? caption;

  const _HealthActionButton({
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
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                emoji,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(inherit: true, fontSize: 26),
              ),
              const SizedBox(height: 4),
              Text(
                category,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall!
                    .copyWith(inherit: true, fontSize: 10),
              ),
              if (caption != null)
                Text(
                  caption!,
                  textAlign: TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall!
                      .copyWith(inherit: true, fontSize: 11),
                ),
            ],
          ),
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
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        subtitle: Text(
          '${DateFormat('dd.MM.yyyy', 'ru').format(event.dateTime)} · $daysLabel',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: (daysLeft <= 7
                    ? ThemeColors.warning
                    : context.watch<AppearanceController>().primaryColor)
                .withAlpha(30),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            daysLabel,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: daysLeft <= 7
                      ? ThemeColors.warning
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
