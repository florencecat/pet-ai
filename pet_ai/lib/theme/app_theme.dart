import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static final lightTheme = ThemeData(
    scaffoldBackgroundColor: ThemeColors.background,

    colorScheme: const ColorScheme.light(
      primary: ThemeColors.primary,
      secondary: ThemeColors.secondary,
      surface: ThemeColors.background,
    ),

    splashColor: ThemeColors.splash,

    textTheme: const TextTheme(
      bodyMedium: TextStyle(fontSize: 16, color: ThemeColors.textPrimary),
      bodySmall: TextStyle(fontSize: 14, color: ThemeColors.textPrimary),
      bodyLarge: TextStyle(fontSize: 17, color: ThemeColors.textPrimary, fontWeight: FontWeight.w500),
      titleLarge: TextStyle(
        color: ThemeColors.textPrimary,
        fontSize: 20,
        fontWeight: FontWeight.w500,
      ),
      titleMedium: TextStyle(
        color: ThemeColors.textPrimary,
        fontWeight: FontWeight.w500,
        fontSize: 20,
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
