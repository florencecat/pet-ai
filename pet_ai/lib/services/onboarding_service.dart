import 'package:shared_preferences/shared_preferences.dart';

/// Флаги показанного обучения (coach marks).
///
/// Хранятся так же, как флаг уведомления о сборе диагностики
/// (см. `CrashReportingService.isNoticeShown`) — булевым ключом в
/// SharedPreferences: обучение показываем один раз на установку, дальше флаг
/// живёт вместе с остальными настройками и переживает перезапуски.
class OnboardingService {
  // Показывали ли обучение по главному экрану (один раз).
  static const _homeShownKey = 'onboarding_home_shown';

  /// Показывали ли пользователю обучение по главному экрану.
  Future<bool> isHomeShown() async =>
      (await SharedPreferencesAsync().getBool(_homeShownKey)) ?? false;

  /// Отмечает обучение по главному экрану показанным (больше не покажем).
  Future<void> markHomeShown() async =>
      SharedPreferencesAsync().setBool(_homeShownKey, true);

  /// Сбрасывает флаг — обучение покажется снова при возврате на главный экран.
  /// Используется отладочной секцией настроек.
  Future<void> resetHomeShown() async =>
      SharedPreferencesAsync().remove(_homeShownKey);
}
