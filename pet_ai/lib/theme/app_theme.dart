import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  /// Builds a theme from a pet palette: mainColor as primary, darkShade as text color.
  static ThemeData withPalette(ProfileColorPalette palette) {
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
