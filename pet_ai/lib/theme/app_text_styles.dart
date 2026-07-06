import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/services/appearance_controller.dart';

/// Ролевые текстовые стили поверх текущего оформления ([AppearanceController]).
///
/// Убирают повторяющийся
/// `Theme.of(context).textTheme.X!.copyWith(color: ...secondaryColor...)`
/// на местах:
///   • заголовки — насыщенный secondaryColor;
///   • подзаголовки — secondaryColor с alpha 128.
///
/// Через `context.watch` — при смене палитры питомца текст перекрашивается сразу.
///
/// ```dart
/// Text('Заголовок',    style: context.titleStyle);
/// Text('Подзаголовок', style: context.subtitleStyle);
/// // Нестандартная база — берём только цвет роли:
/// Text('...', style: someStyle.copyWith(color: context.subtitleColor));
/// ```
extension AppearanceTextStyles on BuildContext {
  AppearanceController get _appearance => watch<AppearanceController>();

  /// Насыщенный цвет заголовков (secondaryColor текущей палитры).
  Color get titleColor => _appearance.titleColor;

  /// Полупрозрачный цвет подзаголовков (secondaryColor @ alpha 128).
  Color get subtitleColor => _appearance.subtitleColor;

  TextTheme get _text => Theme.of(this).textTheme;

  // ── Заголовки: насыщенный secondaryColor ──────────────────────────────────

  /// Крупный заголовок (titleLarge).
  TextStyle get titleStyle => _text.titleLarge!.copyWith(color: titleColor);

  /// Заголовок поменьше (titleMedium).
  TextStyle get titleMediumStyle =>
      _text.titleMedium!.copyWith(color: titleColor);

  // ── Подзаголовки: secondaryColor с alpha 128 ──────────────────────────────

  /// Подзаголовок (bodySmall).
  TextStyle get subtitleStyle => _text.bodySmall!.copyWith(color: subtitleColor);

  /// Подзаголовок покрупнее (bodyMedium).
  TextStyle get subtitleMediumStyle =>
      _text.bodyMedium!.copyWith(color: subtitleColor);
}
