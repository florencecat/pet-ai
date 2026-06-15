import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// Праздничный лист «День рождения» питомца с подробным содержимым и
/// анимациями (анимированный вход hero + счётчик возраста + сворачиваемые
/// секции в стиле страницы здоровья).
class BirthdaySheet extends StatefulWidget {
  final Pet profile;
  const BirthdaySheet({super.key, required this.profile});

  @override
  State<BirthdaySheet> createState() => _BirthdaySheetState();
}

class _BirthdaySheetState extends State<BirthdaySheet>
    with SingleTickerProviderStateMixin {
  static const _pink = Color(0xFFEC92B6);

  bool _ageExpanded = true;
  bool _upcomingExpanded = false;

  late final AnimationController _entrance;
  late final Animation<double> _heroScale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _entrance = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 750),
    );
    _heroScale = CurvedAnimation(parent: _entrance, curve: Curves.elasticOut);
    _fade = CurvedAnimation(
      parent: _entrance,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
    );
    _entrance.forward();
  }

  @override
  void dispose() {
    _entrance.dispose();
    super.dispose();
  }

  // ── Date math ───────────────────────────────────────────────────────────────

  DateTime get _birth => widget.profile.birthDate!;

  DateTime get _today {
    final n = DateTime.now();
    return DateTime(n.year, n.month, n.day);
  }

  DateTime get _nextBirthday {
    var d = DateTime(_today.year, _birth.month, _birth.day);
    if (d.isBefore(_today)) {
      d = DateTime(_today.year + 1, _birth.month, _birth.day);
    }
    return d;
  }

  int get _daysUntil => _nextBirthday.difference(_today).inDays;

  int get _ageAtNext => _nextBirthday.year - _birth.year;

  /// Точный возраст: годы, месяцы, дни.
  (int, int, int) get _exactAge {
    int years = _today.year - _birth.year;
    int months = _today.month - _birth.month;
    int days = _today.day - _birth.day;
    if (days < 0) {
      months -= 1;
      // Количество дней в предыдущем месяце.
      days += DateTime(_today.year, _today.month, 0).day;
    }
    if (months < 0) {
      years -= 1;
      months += 12;
    }
    return (years, months, days);
  }

  /// Возраст полных лет на сегодня.
  int get _ageYears => _exactAge.$1;

  /// Примерный «человеческий» возраст для собак и кошек.
  int? get _humanAge {
    final id = widget.profile.species.id;
    final isDog = id == BuiltInSpecies.dog.id;
    final isCat = id == BuiltInSpecies.cat.id;
    if (!isDog && !isCat) return null;

    final petYears = _today.difference(_birth).inDays / 365.25;
    if (petYears <= 0) return 0;

    final double human;
    if (petYears <= 1) {
      human = petYears * 15;
    } else if (petYears <= 2) {
      human = 15 + (petYears - 1) * 9;
    } else {
      human = 24 + (petYears - 2) * (isDog ? 5 : 4);
    }
    return human.round();
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final name = widget.profile.name.isEmpty ? 'питомец' : widget.profile.name;
    final isToday = _daysUntil == 0;

    return DraggableSheet(
      title: 'День рождения',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.75,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Hero (анимированный вход) ─────────────────────────────────────
          Center(
            child: Column(
              children: [
                ScaleTransition(
                  scale: _heroScale,
                  child: Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [_pink.withAlpha(60), _pink.withAlpha(20)],
                      ),
                      border: Border.all(color: _pink.withAlpha(90), width: 1.5),
                    ),
                    child: const Icon(Icons.cake_rounded, color: _pink, size: 46),
                  ),
                ),
                const SizedBox(height: 14),
                FadeTransition(
                  opacity: _fade,
                  child: Text(
                    name,
                    style: Theme.of(context).textTheme.headlineSmall!.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 4),
                // Счётчик возраста (анимированный отсчёт от 0).
                FadeTransition(
                  opacity: _fade,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: _ageYears.toDouble()),
                    duration: const Duration(milliseconds: 900),
                    curve: Curves.easeOutCubic,
                    builder: (context, value, _) {
                      final shown = value.round();
                      return Text(
                        '$shown ${_yearsWord(shown)}',
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          color: _pink,
                          fontWeight: FontWeight.w600,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 18),

          // ── Обратный отсчёт ───────────────────────────────────────────────
          _CountdownCard(
            daysUntil: _daysUntil,
            isToday: isToday,
            nextDate: _nextBirthday,
            ageAtNext: _ageAtNext,
            pink: _pink,
          ),

          const SizedBox(height: 16),

          // ── Подробно о возрасте (сворачиваемая секция) ───────────────────
          CollapsibleSection(
            expanded: _ageExpanded,
            onToggle: () => setState(() => _ageExpanded = !_ageExpanded),
            titleContent: Text(
              'Подробно о возрасте',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            body: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassPlate(
                padding: 0,
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.hourglass_bottom_rounded,
                      label: 'Полный возраст',
                      value: _fullAgeLabel(),
                    ),
                    const _RowDivider(),
                    _InfoRow(
                      icon: Icons.event_rounded,
                      label: 'Дата рождения',
                      value: DateFormat('d MMMM yyyy', 'ru').format(_birth),
                    ),
                    if (_humanAge != null) ...[
                      const _RowDivider(),
                      _InfoRow(
                        icon: Icons.people_alt_rounded,
                        label: 'В человеческих годах',
                        value: '≈ $_humanAge ${_yearsWord(_humanAge!)}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),

          const SizedBox(height: 12),

          // ── Следующие дни рождения (сворачиваемая секция) ────────────────
          CollapsibleSection(
            expanded: _upcomingExpanded,
            onToggle: () =>
                setState(() => _upcomingExpanded = !_upcomingExpanded),
            titleContent: Text(
              'Следующие дни рождения',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            body: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: GlassPlate(
                padding: 0,
                child: Column(
                  children: [
                    for (var i = 0; i < 5; i++) ...[
                      if (i > 0) const _RowDivider(),
                      _InfoRow(
                        icon: Icons.celebration_outlined,
                        label: DateFormat('d MMMM yyyy', 'ru').format(
                          DateTime(
                            _nextBirthday.year + i,
                            _birth.month,
                            _birth.day,
                          ),
                        ),
                        value: 'исполнится ${_ageAtNext + i}',
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _fullAgeLabel() {
    final (y, m, d) = _exactAge;
    final parts = <String>[];
    if (y > 0) parts.add('$y ${_yearsWord(y)}');
    if (m > 0) parts.add('$m ${_monthsWord(m)}');
    if (d > 0 || parts.isEmpty) parts.add('$d ${_daysWord(d)}');
    return parts.join(' ');
  }

  // ── Word forms ──────────────────────────────────────────────────────────────

  static String _yearsWord(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'лет';
    if (m10 == 1) return 'год';
    if (m10 >= 2 && m10 <= 4) return 'года';
    return 'лет';
  }

  static String _monthsWord(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'мес.';
    if (m10 == 1) return 'месяц';
    if (m10 >= 2 && m10 <= 4) return 'месяца';
    return 'мес.';
  }

  static String _daysWord(int n) {
    final m10 = n % 10, m100 = n % 100;
    if (m100 >= 11 && m100 <= 14) return 'дней';
    if (m10 == 1) return 'день';
    if (m10 >= 2 && m10 <= 4) return 'дня';
    return 'дней';
  }
}

// ─── Countdown card ───────────────────────────────────────────────────────────

class _CountdownCard extends StatelessWidget {
  final int daysUntil;
  final bool isToday;
  final DateTime nextDate;
  final int ageAtNext;
  final Color pink;

  const _CountdownCard({
    required this.daysUntil,
    required this.isToday,
    required this.nextDate,
    required this.ageAtNext,
    required this.pink,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (isToday) {
      return GlassPlate(
        color: pink.withAlpha(28),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          child: Row(
            children: [
              const Text('🎉', style: TextStyle(fontSize: 30)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Сегодня день рождения!',
                      style: theme.textTheme.titleMedium!.copyWith(
                        fontWeight: FontWeight.w700,
                        color: pink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Исполняется $ageAtNext ${_BirthdaySheetState._yearsWord(ageAtNext)}',
                      style: theme.textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GlassPlate(
      padding: 0,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        child: Row(
          children: [
            // Big animated day number.
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: daysUntil.toDouble()),
              duration: const Duration(milliseconds: 900),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => Text(
                '${value.round()}',
                style: theme.textTheme.displaySmall!.copyWith(
                  fontWeight: FontWeight.w800,
                  color: pink,
                ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    daysUntil == 1
                        ? 'день до праздника'
                        : '${_BirthdaySheetState._daysWord(daysUntil)} до праздника',
                    style: theme.textTheme.titleSmall!.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${DateFormat('EEEE, d MMMM', 'ru').format(nextDate)} · '
                    'исполнится $ageAtNext',
                    style: theme.textTheme.bodySmall!.copyWith(
                      color: ThemeColors.border,
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
}

// ─── Helpers ──────────────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
      child: Row(
        children: [
          Icon(icon, size: 18, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium!.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 46,
    endIndent: 0,
    color: ThemeColors.border.withAlpha(60),
  );
}
