import 'package:flutter/material.dart';
import 'package:pet_ai/services/appearance_service.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';

/// Реактивный контроллер темы приложения.
/// Уведомляет слушателей при изменении цвета/настройки — тема применяется сразу.
class AppearanceController extends ChangeNotifier {
  bool _loaded = false;
  bool _usePetColor = false;
  ProfileColorPalette _profilePalette = ThemeColors.defaultProfilePalette;

  bool get loaded => _loaded;
  bool get usePetColor => _usePetColor;

  /// Цвет активного питомца (всегда загружен, независимо от usePetColor).
  ProfileColorPalette get petPalette => _profilePalette;
  Color get petColor => _profilePalette.mainColor;

  /// Основной цвет темы: цвет питомца или дефолтный.
  ProfileColorPalette get primaryPalette =>
      _usePetColor ? _profilePalette : ThemeColors.defaultProfilePalette;
  Color get primaryColor => _usePetColor
      ? _profilePalette.mainColor
      : ThemeColors.defaultProfilePalette.mainColor;
  Color get secondaryColor => _usePetColor
      ? _profilePalette.darkShade
      : ThemeColors.defaultProfilePalette.darkShade;

  /// Градиентный фон страниц, адаптированный к текущему primaryColor.
  BoxDecoration get gradientDecoration => BoxDecoration(
    gradient: LinearGradient(
      tileMode: TileMode.mirror,
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        primaryColor.withAlpha(96),
        ThemeColors.gradientEnd.withAlpha(64),
      ],
    ),
  );

  Future<void> load() async {
    _usePetColor = await AppearanceService().getUsePetColor();
    final profile = await ProfileService().loadActiveProfile();
    if (profile != null) _profilePalette = profile.palette;
    _loaded = true;
    notifyListeners();
  }

  Future<void> setUsePetColor(bool value) async {
    _usePetColor = value;
    await AppearanceService().setUsePetColor(value);
    notifyListeners();
  }

  /// Немедленно применяет новую палитру (вызывать после сохранения профиля).
  void updatePetPalette(ProfileColorPalette palette) {
    _profilePalette = palette;
    notifyListeners();
  }

  /// Перезагружает цвет питомца (вызывать при смене активного профиля).
  Future<void> reloadProfile() async {
    final profile = await ProfileService().loadActiveProfile();
    if (profile != null) _profilePalette = profile.palette;
    notifyListeners();
  }
}
