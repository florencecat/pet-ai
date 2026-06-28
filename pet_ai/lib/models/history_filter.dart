import 'package:shared_preferences/shared_preferences.dart';

/// Параметры отображения «Истории питомца» на главной странице.
/// Сохраняются в [SharedPreferences] и переживают перезапуск приложения.
class HistoryFilter {
  /// Показывать предстоящие приёмы препаратов (события-таблетки).
  final bool upcomingPills;

  /// Показывать предстоящие обработки/прививки (события-обработки).
  final bool upcomingTreatments;

  /// Показывать пропущенные события (прошли и не отмечены выполненными).
  final bool missedEvents;

  /// Показывать выполненные события.
  final bool completedEvents;

  /// Показывать автоматические события (пока — только день рождения питомца).
  final bool automaticEvents;

  const HistoryFilter({
    this.upcomingPills = false,
    this.upcomingTreatments = false,
    this.missedEvents = false,
    this.completedEvents = true,
    this.automaticEvents = true,
  });

  const HistoryFilter.defaults() : this();

  HistoryFilter copyWith({
    bool? upcomingPills,
    bool? upcomingTreatments,
    bool? missedEvents,
    bool? completedEvents,
    bool? automaticEvents,
  }) => HistoryFilter(
    upcomingPills: upcomingPills ?? this.upcomingPills,
    upcomingTreatments: upcomingTreatments ?? this.upcomingTreatments,
    missedEvents: missedEvents ?? this.missedEvents,
    completedEvents: completedEvents ?? this.completedEvents,
    automaticEvents: automaticEvents ?? this.automaticEvents,
  );

  // ── Persistence ─────────────────────────────────────────────────────────────

  static const _kPills = 'history_filter_upcoming_pills';
  static const _kTreatments = 'history_filter_upcoming_treatments';
  static const _kMissed = 'history_filter_missed';
  static const _kCompleted = 'history_filter_completed';
  static const _kAutomatic = 'history_filter_automatic';

  static Future<HistoryFilter> load() async {
    final prefs = SharedPreferencesAsync();
    const def = HistoryFilter.defaults();
    return HistoryFilter(
      upcomingPills: await prefs.getBool(_kPills) ?? def.upcomingPills,
      upcomingTreatments:
          await prefs.getBool(_kTreatments) ?? def.upcomingTreatments,
      missedEvents: await prefs.getBool(_kMissed) ?? def.missedEvents,
      completedEvents: await prefs.getBool(_kCompleted) ?? def.completedEvents,
      automaticEvents: await prefs.getBool(_kAutomatic) ?? def.automaticEvents,
    );
  }

  Future<void> save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kPills, upcomingPills);
    await prefs.setBool(_kTreatments, upcomingTreatments);
    await prefs.setBool(_kMissed, missedEvents);
    await prefs.setBool(_kCompleted, completedEvents);
    await prefs.setBool(_kAutomatic, automaticEvents);
  }
}
