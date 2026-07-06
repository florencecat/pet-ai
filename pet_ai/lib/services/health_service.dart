import 'package:pet_satellite/models/pet_profile.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class WeightInputFormatter extends TextInputFormatter {
  final RegExp regex = RegExp(r'^\d+(\.\d?)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    if (regex.hasMatch(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}

// ─── Анализ здоровья ────────────────────────────────────────────────────────

enum HealthBadgeSeverity { ok, info, warning, danger }

extension HealthBadgeSeverityX on HealthBadgeSeverity {
  ColorPalette get palette {
    switch (this) {
      case HealthBadgeSeverity.ok:
        return ThemeColors.ok;
      case HealthBadgeSeverity.info:
        return ThemeColors.info;
      case HealthBadgeSeverity.warning:
        return ThemeColors.warning;
      case HealthBadgeSeverity.danger:
        return ThemeColors.danger;
    }
  }

  IconData get icon {
    switch (this) {
      case HealthBadgeSeverity.ok:
        return Icons.check_circle_outline;
      case HealthBadgeSeverity.info:
        return Icons.info_outline;
      case HealthBadgeSeverity.warning:
        return Icons.warning_amber_rounded;
      case HealthBadgeSeverity.danger:
        return Icons.error_outline;
    }
  }
}

class HealthBadge {
  /// Stable identifier used for dismissing the badge. Null = not dismissable.
  final String? id;
  final String title;
  final String subtitle;
  final HealthBadgeSeverity severity;
  final IconData? icon;

  const HealthBadge({
    this.id,
    required this.title,
    required this.subtitle,
    required this.severity,
    this.icon,
  });
}

/// Анализатор: на основе данных профиля + событий формирует список бейджей.
class HealthAnalyzer {

  static String _dismissedKey(String petId) => 'dismissed_health_badges_$petId';

  static Future<void> saveDismissed(List<String> dismissedBadgeIds, String petId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      _dismissedKey(petId),
      dismissedBadgeIds.toList(),
    );
  }

  static Future<List<String>> loadDismissed(String petId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(_dismissedKey(petId)) ?? [];
  }

  static Future<List<HealthBadge>> analyze(Pet profile, List<Event> events) async {
    final badges = <HealthBadge>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    final dismissedBadgeIds = await loadDismissed(profile.id);
    void addBadge(HealthBadge badge) {
      if (!dismissedBadgeIds.contains(badge.id)) {
        badges.add(badge);
      }
    }

    // ── Просроченные мероприятия (treatments) ────────────────────────────
    // Берём только последнюю запись по каждому (kind, name) — если пользователь
    // добавил более свежую запись, старая считается обработанной этим фактом.
    final overdueTreatments = <TreatmentEntry>[];
    final upcomingTreatments = <TreatmentEntry>[];
    final latestByKey = <String, TreatmentEntry>{};
    for (final t in profile.treatmentHistory.entries) {
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
      final diff = next.difference(today).inDays;
      if (diff < 0) {
        overdueTreatments.add(t);
      } else if (diff <= t.remindBeforeDays) {
        upcomingTreatments.add(t);
      }
    }

    for (final t in overdueTreatments) {
      addBadge(
        HealthBadge(
          title: 'Просрочено: ${t.displayName}',
          subtitle: 'Должно было быть ${formatSmartDate(t.nextDate)}',
          severity: HealthBadgeSeverity.danger,
          icon: t.kind.icon,
        ),
      );
    }
    for (final t in upcomingTreatments) {
      final daysLeft = DateTime(
        t.nextDate.year,
        t.nextDate.month,
        t.nextDate.day,
      ).difference(today).inDays;
      addBadge(
        HealthBadge(
          title: 'Скоро: ${t.displayName}',
          subtitle: daysLeft == 0
              ? 'Сегодня'
              : 'Через $daysLeft ${_daysWord(daysLeft)}'
                    ' • ${formatSmartDate(t.nextDate)}',
          severity: HealthBadgeSeverity.warning,
          icon: t.kind.icon,
        ),
      );
    }

    // ── Базовые рекомендации по типам мероприятий ────────────────────────
    // Only show these for treatment kinds that have at least no entry AND
    // the badge is not dismissed. Each badge gets a stable dismissable id.
    for (final kind in TreatmentKind.values) {
      if (kind == TreatmentKind.vaccine) continue;
      final last = profile.treatmentHistory.lastOfKind(kind);
      if (last == null) {
        addBadge(
          HealthBadge(
            id: 'treatment_remind_${kind.name}',
            title: kind.label,
            subtitle: 'Добавьте запись, чтобы получать напоминания',
            severity: HealthBadgeSeverity.warning,
            icon: kind.icon,
          ),
        );
      }
    }

    // ── Анализ заметок (симптомы за последние 7 дней) ────────────────────
    final sevenDaysAgo = today.subtract(const Duration(days: 7));
    final recentNotes = profile.noteHistory.entries.where((n) {
      final noteDay = DateTime(n.date.year, n.date.month, n.date.day);
      return !noteDay.isBefore(sevenDaysAgo);
    }).toList();
    final symptomCounts = <String, int>{};
    for (final n in recentNotes) {
      if (n.symptomId != null) {
        symptomCounts[n.symptomId!] =
            (symptomCounts[n.symptomId!] ?? 0) + 1;
      }
    }
    for (final entry in symptomCounts.entries) {
      final tag = SymptomTags.byId(entry.key);
      if (tag == null) continue;
      final times = entry.value;
      addBadge(
        HealthBadge(
          title: 'Симптом: ${tag.label}',
          subtitle:
              'Отмечено $times ${_timesWord(times)} за последние 7 дней — '
              'обратите внимание на здоровье питомца',
          severity: HealthBadgeSeverity.warning,
          icon: tag.icon,
        ),
      );
    }

    // ── Вес ──────────────────────────────────────────────────────────────
    final lastWeight = profile.weightHistory.lastEntry;
    if (lastWeight == null) {
      addBadge(
        const HealthBadge(
          title: 'Зафиксируйте вес',
          subtitle: 'Помогает отслеживать динамику здоровья',
          severity: HealthBadgeSeverity.info,
          icon: Icons.monitor_weight_outlined,
        ),
      );
    } else {
      final daysSince = today
          .difference(
            DateTime(
              lastWeight.date.year,
              lastWeight.date.month,
              lastWeight.date.day,
            ),
          )
          .inDays;
      if (daysSince >= 30) {
        addBadge(
          HealthBadge(
            title: 'Пора обновить вес',
            subtitle:
                'Последняя запись: ${formatSmartDate(lastWeight.date)} '
                '($daysSince ${_daysWord(daysSince)} назад)',
            severity: HealthBadgeSeverity.warning,
            icon: Icons.monitor_weight_outlined,
          ),
        );
      }
    }

    // ── Настроение ──────────────────────────────────────────────────────
    if (!profile.moodHistory.hasTodayEntry()) {
      final lastMood = profile.moodHistory.lastEntry;
      final subtitle = lastMood == null
          ? 'Отметьте, как себя чувствует питомец'
          : 'Последняя запись: ${formatSmartDate(lastMood.date)}';
      addBadge(
        HealthBadge(
          title: 'Зафиксируйте настроение',
          subtitle: subtitle,
          severity: HealthBadgeSeverity.info,
          icon: Icons.mood_outlined,
        ),
      );
    }

    // ── Тренд веса (снижение за последние 3+ записи) ────────────────────
    final weightEntries = profile.weightHistory.entries;
    if (weightEntries.length >= 3) {
      final recent = weightEntries.reversed.take(3).toList();
      // recent[0] = newest, recent[2] = oldest
      final newest = recent[0].weight;
      final oldest = recent[2].weight;
      if (newest < oldest) {
        final diff = (oldest - newest);
        addBadge(
          HealthBadge(
            title: 'Снижение веса',
            subtitle:
                'Последние 3 записи: потеря ${diff.toStringAsFixed(1)} кг',
            severity: HealthBadgeSeverity.warning,
            icon: Icons.trending_down,
          ),
        );
      }
    }

    // ── Низкий аппетит (последние 3 дня средний балл < 3) ───────────────
    final foodEntries = profile.foodHistory.entries;
    if (foodEntries.isNotEmpty) {
      final threeDaysAgo = today.subtract(const Duration(days: 3));
      final recentFood = foodEntries
          .where(
            (f) => !DateTime(
              f.date.year,
              f.date.month,
              f.date.day,
            ).isBefore(threeDaysAgo),
          )
          .toList();
      if (recentFood.isNotEmpty) {
        final avgScore =
            recentFood.map((f) => f.appetiteScore).reduce((a, b) => a + b) /
            recentFood.length;
        if (avgScore < 3.0) {
          final avgStr = avgScore.toStringAsFixed(1);
          addBadge(
            HealthBadge(
              title: 'Плохой аппетит',
              subtitle:
                  'Средний балл за 3 дня: $avgStr / 5 — питомец плохо ест',
              severity: HealthBadgeSeverity.warning,
              icon: Icons.no_food_outlined,
            ),
          );
        }
      }
    }

    // ── Просроченные прививки из PetEvent ───────────────────────────────
    final overdueVaccinations = events
        .where((e) => e.category.id == 'vaccination' && e.isOverdue)
        .toList();
    for (final v in overdueVaccinations) {
      addBadge(
        HealthBadge(
          title: '⚠ Просрочена прививка',
          subtitle:
              '${v.name} · ${DateFormat('dd.MM.yyyy').format(v.dateTime)}',
          severity: HealthBadgeSeverity.danger,
          icon: Icons.vaccines,
        ),
      );
    }

    // ── Просроченные события ────────────────────────────────────────────
    final overdueEvents = events
        .where((e) => e.isOverdue && e.category.id != 'vaccination')
        .toList();
    if (overdueEvents.isNotEmpty) {
      addBadge(
        HealthBadge(
          title: 'Просроченные события: ${overdueEvents.length}',
          subtitle: overdueEvents.first.name,
          severity: HealthBadgeSeverity.warning,
          icon: Icons.event_busy,
        ),
      );
    }

    // ── Пропущенные таблетки ─────────────────────────────────────────────
    // Считаем только если сегодня по расписанию И время уже прошло И не принято.
    // Предстоящие приёмы не влияют на оценку здоровья.
    // Препараты «по требованию» нельзя пропустить — они не имеют фиксированного
    // времени и отмечаются вручную в момент приёма.
    for (final pill in profile.pillReminders) {
      if (!pill.isActive) continue;
      if (pill.frequencyType == PillFrequencyType.onDemand) continue;
      if (!pill.isScheduledForDay(now)) continue;
      final scheduled = DateTime(
        today.year, today.month, today.day, pill.hour, pill.minute,
      );
      if (now.isAfter(scheduled) && !pill.isTakenOnDay(now)) {
        addBadge(HealthBadge(
          title: 'Пропущен приём: ${pill.name}',
          subtitle: pill.doseLabel.isNotEmpty
              ? '${pill.doseLabel} · ${pill.timeLabel}'
              : pill.timeLabel,
          severity: HealthBadgeSeverity.warning,
          icon: Icons.medication_outlined,
        ));
      }
    }

    // ── Если нечего показать — общий "всё хорошо" ──────────────────────
    if (badges.isEmpty) {
      addBadge(
        const HealthBadge(
          title: 'Всё в порядке',
          subtitle: 'Записи актуальны, ближайших мероприятий нет',
          severity: HealthBadgeSeverity.ok,
          icon: Icons.favorite,
        ),
      );
    }

    return badges;
  }

  static ({String caption, String label, ColorPalette palette, IconData icon}) score(
    List<HealthBadge> badges,
  ) {
    final dangerCount = badges
        .where((b) => b.severity == HealthBadgeSeverity.danger)
        .length;
    final warningCount = badges
        .where((b) => b.severity == HealthBadgeSeverity.warning)
        .length;

    if (dangerCount > 0) {
      return (
        caption: 'Критично',
        label: 'Критично',
      palette: HealthBadgeSeverity.danger.palette,
        icon: Icons.error_outline,
      );
    }
    if (warningCount >= 3) {
      return (
        caption: 'Внимание',
        label: 'Внимание',
      palette: HealthBadgeSeverity.warning.palette,
        icon: Icons.warning_amber_rounded,
      );
    }
    return (
      caption: 'В норме',
      label: 'OK',
    palette: HealthBadgeSeverity.ok.palette,
      icon: Icons.check_circle_outline,
    );
  }

  static String _daysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дн.';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дн.';
  }

  static String _timesWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'раз';
    if (mod10 == 1) return 'раз';
    if (mod10 >= 2 && mod10 <= 4) return 'раза';
    return 'раз';
  }
}

// ─── UI ─────────────────────────────────────────────────────────────────────

class HealthBadgeTile extends StatelessWidget {
  final HealthBadge badge;
  /// If provided, a dismiss button is shown for dismissable badges.
  final VoidCallback? onDismiss;

  const HealthBadgeTile({super.key, required this.badge, this.onDismiss});

  @override
  Widget build(BuildContext context) {
    final color = badge.severity.palette.mainColor;
    final canDismiss = onDismiss != null && badge.id != null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: SoftGlassPlate(
        color: color.withAlpha(60),
        child: ListTile(
          leading: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withAlpha(60),
              shape: BoxShape.circle,
            ),
            child: Icon(badge.icon ?? badge.severity.icon, color: color),
          ),
          title: Text(
            badge.title,
            style: Theme.of(context).textTheme.titleSmall!.copyWith(
              fontWeight: FontWeight.w600,
              color: context.watch<AppearanceController>().secondaryColor,
            ),
          ),
          subtitle: Text(
            badge.subtitle,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: context.watch<AppearanceController>().secondaryColor,
            ),
          ),
          trailing: canDismiss
              ? IconButton(
                  icon: const Icon(Icons.close, size: 18),
                  color: ThemeColors.border,
                  tooltip: 'Скрыть',
                  onPressed: onDismiss,
                )
              : null,
        ),
      ),
    );
  }
}