import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  // Одно семейство «Rubik» — конкретное начертание выбирается по fontWeight,
  // а pubspec сопоставляет вес → файл (400 Regular / 700 Bold / 900 Black).
  static const _fontFamily = 'Rubik';

  /// Builds a theme from a pet palette: mainColor as primary, darkShade as text color.
  static ThemeData withPalette(ColorPalette palette) {
    final base = lightTheme;
    final textColor = palette.darkShade;
    return base.copyWith(
      colorScheme: base.colorScheme.copyWith(
        primary: palette.mainColor,
        secondary: palette.darkShade,
      ),
      dividerColor: palette.mainColor,
      textSelectionTheme: TextSelectionThemeData(cursorColor: palette.mainColor),
      textTheme: base.textTheme.copyWith(
        bodyMedium: base.textTheme.bodyMedium!.copyWith(color: textColor),
        bodySmall: base.textTheme.bodySmall!.copyWith(color: textColor),
        bodyLarge: base.textTheme.bodyLarge!.copyWith(color: textColor),
        titleLarge: base.textTheme.titleLarge!.copyWith(color: textColor),
        titleMedium: base.textTheme.titleMedium!.copyWith(color: textColor),
        titleSmall: base.textTheme.titleSmall!.copyWith(color: textColor),
        headlineSmall: base.textTheme.headlineSmall!.copyWith(color: textColor),
        headlineMedium: base.textTheme.headlineMedium!.copyWith(color: textColor),
        headlineLarge: base.textTheme.headlineLarge!.copyWith(color: textColor),
      ),
    );
  }

  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: ThemeColors.background,

    colorScheme: const ColorScheme.light(
      primary: ThemeColors.primary,
      secondary: ThemeColors.secondary,
      surface: ThemeColors.background,
    ),

    splashColor: ThemeColors.splash,

    textTheme: const TextTheme(
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        color: ThemeColors.textPrimary,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        color: ThemeColors.textPrimary,
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        color: ThemeColors.textPrimary,
      ),
      titleLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w900, // Black
        color: ThemeColors.textPrimary,
      ),
      titleMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w700, // Bold
        color: ThemeColors.textPrimary,
      ),
      titleSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400, // Regular
        color: ThemeColors.textPrimary,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontWeight: FontWeight.w900, // Black
        color: ThemeColors.textPrimary,
      ),
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: ThemeColors.background,
      elevation: 0,
      iconTheme: IconThemeData(color: ThemeColors.border),
    ),

    bottomNavigationBarTheme: BottomNavigationBarThemeData(
      selectedItemColor: ThemeColors.border,
      unselectedItemColor: ThemeColors.unselected,
    ),

    dividerColor: ThemeColors.border,

    useMaterial3: true,
  );
}
