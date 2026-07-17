import 'package:flutter/foundation.dart';

/// Фичи, настройку которых можно скрыть за гейтом, пока они «пилятся».
enum Feature {
  cloudSync,
  userCity,
  dataExport,
  biometrics,
  aiAdvices,
  helpFAQ,
  rateUs
}

/// Гейт фич приложения.
///
/// Гейт СКРЫВАЕТ настройку перечисленных фич в UI (сама реализация остаётся),
/// но действует только:
///   • в релизной сборке ([kReleaseMode]) — в debug гейт игнорируется;
///   • на «гейтируемых» платформах ([gatedPlatforms], пока только Android) —
///     на остальных платформах ограничения игнорируются.
///
/// Значения правятся здесь, в одном месте. Осознанно используем type-safe
/// Dart-конфиг вместо внешнего JSON: флаги известны на этапе компиляции, не
/// нужен рантайм-парсинг и загрузка ассетов, а опечатки в именах фич ловит
/// компилятор. Если позже понадобится удалённое управление без пересборки —
/// точку доступа [isEnabled] можно переключить на источник вроде Firebase
/// Remote Config, не трогая места вызова.
class FeatureFlags {
  const FeatureFlags._();

  /// Платформы, на которых гейт действует. Для остальных — игнорируется.
  static const Set<TargetPlatform> gatedPlatforms = {TargetPlatform.android};

  /// Доступность фичи В ГЕЙТИРУЕМОМ КОНТЕКСТЕ (release + gated platform).
  /// `false` → настройка фичи скрыта. Незаданная фича считается доступной.
  static const Map<Feature, bool> _enabledWhenGated = {
    Feature.cloudSync: false,
    Feature.userCity: false,
    Feature.dataExport: false,
    Feature.biometrics: false,
    Feature.aiAdvices: false,
  };

  /// Оверрайды для тестов (в проде остаются null).
  @visibleForTesting
  static bool? debugReleaseOverride;
  @visibleForTesting
  static TargetPlatform? debugPlatformOverride;

  static bool get _isRelease => debugReleaseOverride ?? kReleaseMode;
  static TargetPlatform get _platform =>
      debugPlatformOverride ?? defaultTargetPlatform;

  /// Действует ли гейт в текущей сборке (release + гейтируемая платформа).
  static bool get isGateActive =>
      _isRelease && gatedPlatforms.contains(_platform);

  /// Доступна ли настройка фичи в UI.
  static bool isEnabled(Feature feature) {
    if (!isGateActive) return true;
    return _enabledWhenGated[feature] ?? true;
  }
}
