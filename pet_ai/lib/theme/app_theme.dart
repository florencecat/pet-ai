import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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

    textTheme: TextTheme(
      bodyMedium: GoogleFonts.rubikTextTheme().bodyMedium!.copyWith(
        color: ThemeColors.textPrimary,
      ),
      bodySmall: GoogleFonts.rubikTextTheme().bodySmall!.copyWith(
        fontSize: 12,
        color: ThemeColors.textPrimary,
      ),
      bodyLarge: GoogleFonts.rubikTextTheme().bodyLarge!.copyWith(
        color: ThemeColors.textPrimary,
      ),
      titleLarge: GoogleFonts.rubikTextTheme().titleLarge!.copyWith(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: ThemeColors.textPrimary,
      ),
      titleMedium: GoogleFonts.rubikTextTheme().titleMedium!.copyWith(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: ThemeColors.textPrimary,
      ),
      titleSmall: GoogleFonts.rubikTextTheme().titleSmall!.copyWith(
        fontSize: 14,
        fontWeight: FontWeight.w800,
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
