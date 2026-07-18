import 'package:shared_preferences/shared_preferences.dart';

/// Параметры отображения событий в календаре на странице «События».
/// Сохраняются в [SharedPreferences] и переживают перезапуск приложения.
/// По умолчанию показывается всё.
class CalendarFilter {
  /// Показывать приёмы препаратов (события-таблетки).
  final bool showPills;

  /// Показывать обработки/прививки (события-обработки).
  final bool showTreatments;

  /// Показывать события из заметок.
  final bool showNotes;

  /// Показывать прошедшие события (дата вхождения раньше сегодняшнего дня).
  final bool showPast;

  /// Показывать выполненные события.
  final bool showCompleted;

  /// Показывать повторяющиеся события.
  final bool showRepeating;

  const CalendarFilter({
    this.showPills = true,
    this.showTreatments = true,
    this.showNotes = true,
    this.showPast = true,
    this.showCompleted = true,
    this.showRepeating = true,
  });

  const CalendarFilter.defaults() : this();

  CalendarFilter copyWith({
    bool? showPills,
    bool? showTreatments,
    bool? showNotes,
    bool? showPast,
    bool? showCompleted,
    bool? showRepeating,
  }) => CalendarFilter(
    showPills: showPills ?? this.showPills,
    showTreatments: showTreatments ?? this.showTreatments,
    showNotes: showNotes ?? this.showNotes,
    showPast: showPast ?? this.showPast,
    showCompleted: showCompleted ?? this.showCompleted,
    showRepeating: showRepeating ?? this.showRepeating,
  );

  // ── Persistence ─────────────────────────────────────────────────────────────

  static const _kPills = 'calendar_filter_pills';
  static const _kTreatments = 'calendar_filter_treatments';
  static const _kNotes = 'calendar_filter_notes';
  static const _kPast = 'calendar_filter_past';
  static const _kCompleted = 'calendar_filter_completed';
  static const _kRepeating = 'calendar_filter_repeating';

  static Future<CalendarFilter> load() async {
    final prefs = SharedPreferencesAsync();
    const def = CalendarFilter.defaults();
    return CalendarFilter(
      showPills: await prefs.getBool(_kPills) ?? def.showPills,
      showTreatments: await prefs.getBool(_kTreatments) ?? def.showTreatments,
      showNotes: await prefs.getBool(_kNotes) ?? def.showNotes,
      showPast: await prefs.getBool(_kPast) ?? def.showPast,
      showCompleted: await prefs.getBool(_kCompleted) ?? def.showCompleted,
      showRepeating: await prefs.getBool(_kRepeating) ?? def.showRepeating,
    );
  }

  Future<void> save() async {
    final prefs = SharedPreferencesAsync();
    await prefs.setBool(_kPills, showPills);
    await prefs.setBool(_kTreatments, showTreatments);
    await prefs.setBool(_kNotes, showNotes);
    await prefs.setBool(_kPast, showPast);
    await prefs.setBool(_kCompleted, showCompleted);
    await prefs.setBool(_kRepeating, showRepeating);
  }
}
