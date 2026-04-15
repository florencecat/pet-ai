import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/treatment_draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';

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
  Color get color {
    switch (this) {
      case HealthBadgeSeverity.ok:
        return const Color(0xFF43A047);
      case HealthBadgeSeverity.info:
        return const Color(0xFF1976D2);
      case HealthBadgeSeverity.warning:
        return const Color(0xFFFB8C00);
      case HealthBadgeSeverity.danger:
        return const Color(0xFFE53935);
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
  final String title;
  final String subtitle;
  final HealthBadgeSeverity severity;
  final IconData? icon;

  const HealthBadge({
    required this.title,
    required this.subtitle,
    required this.severity,
    this.icon,
  });
}

/// Анализатор: на основе данных профиля + событий формирует список бейджей.
class HealthAnalyzer {
  static List<HealthBadge> analyze(
    PetProfile profile,
    List<PetEvent> events,
  ) {
    final badges = <HealthBadge>[];
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── Просроченные мероприятия (treatments) ────────────────────────────
    final overdueTreatments = <TreatmentEntry>[];
    final upcomingTreatments = <TreatmentEntry>[];
    for (final t in profile.treatmentHistory.entries) {
      final next = DateTime(t.nextDate.year, t.nextDate.month, t.nextDate.day);
      final diff = next.difference(today).inDays;
      if (diff < 0) {
        overdueTreatments.add(t);
      } else if (diff <= t.remindBeforeDays) {
        upcomingTreatments.add(t);
      }
    }

    for (final t in overdueTreatments) {
      badges.add(HealthBadge(
        title: 'Просрочено: ${t.displayName}',
        subtitle:
            'Должно было быть ${DateFormat('dd.MM.yyyy').format(t.nextDate)}',
        severity: HealthBadgeSeverity.danger,
        icon: t.kind.icon,
      ));
    }
    for (final t in upcomingTreatments) {
      final daysLeft = DateTime(
        t.nextDate.year, t.nextDate.month, t.nextDate.day,
      ).difference(today).inDays;
      badges.add(HealthBadge(
        title: 'Скоро: ${t.displayName}',
        subtitle: daysLeft == 0
            ? 'Сегодня'
            : 'Через $daysLeft ${_daysWord(daysLeft)}'
                ' • ${DateFormat('dd.MM.yyyy').format(t.nextDate)}',
        severity: HealthBadgeSeverity.warning,
        icon: t.kind.icon,
      ));
    }

    // ── Базовые рекомендации по типам мероприятий ────────────────────────
    for (final kind in TreatmentKind.values) {
      if (kind == TreatmentKind.vaccine) continue;
      final last = profile.treatmentHistory.lastOfKind(kind);
      if (last == null) {
        badges.add(HealthBadge(
          title: 'Не зафиксировано: ${kind.label}',
          subtitle: 'Добавьте запись, чтобы получать напоминания',
          severity: HealthBadgeSeverity.info,
          icon: kind.icon,
        ));
      }
    }

    // ── Вес ──────────────────────────────────────────────────────────────
    final lastWeight = profile.weightHistory.lastEntry;
    if (lastWeight == null) {
      badges.add(const HealthBadge(
        title: 'Зафиксируйте вес',
        subtitle: 'Помогает отслеживать динамику здоровья',
        severity: HealthBadgeSeverity.info,
        icon: Icons.monitor_weight_outlined,
      ));
    } else {
      final daysSince = today.difference(
        DateTime(lastWeight.date.year, lastWeight.date.month, lastWeight.date.day),
      ).inDays;
      if (daysSince >= 30) {
        badges.add(HealthBadge(
          title: 'Пора обновить вес',
          subtitle:
              'Последняя запись: ${DateFormat('dd.MM.yyyy').format(lastWeight.date)} '
              '($daysSince ${_daysWord(daysSince)} назад)',
          severity: HealthBadgeSeverity.warning,
          icon: Icons.monitor_weight_outlined,
        ));
      }
    }

    // ── Настроение ──────────────────────────────────────────────────────
    if (!profile.moodHistory.hasTodayEntry()) {
      final lastMood = profile.moodHistory.lastEntry;
      final subtitle = lastMood == null
          ? 'Отметьте, как себя чувствует питомец'
          : 'Последняя запись: ${DateFormat('dd.MM.yyyy').format(lastMood.date)}';
      badges.add(HealthBadge(
        title: 'Зафиксируйте настроение',
        subtitle: subtitle,
        severity: HealthBadgeSeverity.info,
        icon: Icons.mood_outlined,
      ));
    }

    // ── Просроченные события ────────────────────────────────────────────
    final overdueEvents = events.where((e) => e.isOverdue).toList();
    if (overdueEvents.isNotEmpty) {
      badges.add(HealthBadge(
        title: 'Просроченные события: ${overdueEvents.length}',
        subtitle: overdueEvents.first.name,
        severity: HealthBadgeSeverity.warning,
        icon: Icons.event_busy,
      ));
    }

    // ── Если нечего показать — общий "всё хорошо" ──────────────────────
    if (badges.isEmpty) {
      badges.add(const HealthBadge(
        title: 'Всё в порядке',
        subtitle: 'Записи актуальны, ближайших мероприятий нет',
        severity: HealthBadgeSeverity.ok,
        icon: Icons.favorite,
      ));
    }

    return badges;
  }

  static String _daysWord(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'дн.';
    if (mod10 == 1) return 'день';
    if (mod10 >= 2 && mod10 <= 4) return 'дня';
    return 'дн.';
  }
}

// ─── UI ─────────────────────────────────────────────────────────────────────

class HealthBadgeTile extends StatelessWidget {
  final HealthBadge badge;

  const HealthBadgeTile({super.key, required this.badge});

  @override
  Widget build(BuildContext context) {
    final color = badge.severity.color;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: GlassPlate(
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
              color: ThemeColors.textPrimary,
            ),
          ),
          subtitle: Text(
            badge.subtitle,
            style: Theme.of(context).textTheme.bodySmall!.copyWith(
              color: ThemeColors.textPrimary.withAlpha(180),
            ),
          ),
        ),
      ),
    );
  }
}

/// Шит «Здоровье» — реальный анализ + быстрые действия.
class HealthSummaryModal extends StatefulWidget {
  const HealthSummaryModal({super.key});

  @override
  State<HealthSummaryModal> createState() => _HealthSummaryModalState();
}

class _HealthSummaryModalState extends State<HealthSummaryModal> {
  PetProfile? _profile;
  List<PetEvent> _events = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await ProfileService().loadActiveProfile();
    if (profile == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final events = await EventService().loadEvents(profile.id);
    if (!mounted) return;
    setState(() {
      _profile = profile;
      _events = events;
      _loading = false;
    });
  }

  Future<void> _openTreatments() async {
    if (_profile == null) return;
    final updated = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      builder: (_) => TreatmentDraggableSheet(profile: _profile!),
    );
    if (updated == true) await _load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const DraggableSheet(
        title: 'Здоровье',
        body: SizedBox(
          height: 200,
          child: Center(child: CircularProgressIndicator()),
        ),
      );
    }
    if (_profile == null) {
      return const DraggableSheet(
        title: 'Здоровье',
        body: Padding(
          padding: EdgeInsets.all(24),
          child: Text('Профиль не найден'),
        ),
      );
    }

    final badges = HealthAnalyzer.analyze(_profile!, _events);

    return DraggableSheet(
      title: 'Здоровье',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.75,
      minSize: 0.4,
      maxSize: 1.0,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Быстрое действие — добавить прививку/обработку
          GlassCard(
            color: ThemeColors.primary,
            callback: _openTreatments,
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

          const SizedBox(height: 16),

          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 4),
            child: Text(
              'Рекомендации',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),

          ...badges.map((b) => HealthBadgeTile(badge: b)),
        ],
      ),
    );
  }
}
