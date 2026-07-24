import 'package:shared_preferences/shared_preferences.dart';

/// Экраны, по которым показываем обучение (coach marks).
enum OnboardingTour { home, health }

/// Флаги показанного обучения.
///
/// Хранятся так же, как флаг уведомления о сборе диагностики
/// (см. `CrashReportingService.isNoticeShown`) — булевым ключом в
/// SharedPreferences: обучение показываем один раз на установку, дальше флаг
/// живёт вместе с остальными настройками и переживает перезапуски.
class OnboardingService {
  static const _keys = {
    OnboardingTour.home: 'onboarding_home_shown',
    OnboardingTour.health: 'onboarding_health_shown',
  };

  /// Показывали ли пользователю обучение по экрану [tour].
  Future<bool> isShown(OnboardingTour tour) async =>
      (await SharedPreferencesAsync().getBool(_keys[tour]!)) ?? false;

  /// Отмечает обучение по экрану [tour] показанным (больше не покажем).
  Future<void> markShown(OnboardingTour tour) async =>
      SharedPreferencesAsync().setBool(_keys[tour]!, true);

  /// Сбрасывает все флаги — обучение покажется снова при возврате на экраны.
  /// Используется отладочной секцией настроек.
  Future<void> resetAll() async {
    for (final key in _keys.values) {
      await SharedPreferencesAsync().remove(key);
    }
  }
}
