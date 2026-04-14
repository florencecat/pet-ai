import 'package:flutter/material.dart';

class ThemeColors {
  static const background = Color(0xFFf4f3ee);
  static const primary = Color(0xFFB896FF);
  static const secondary = Color(0xFF786B96);
  static const unselected = Color(0x603B807B);
  static const danger = Color(0xFFF44336);
  static const error = Color(0xFFBA1A1A);

  static const gradientBegin = Color(0xFFB896FF);
  static const gradientEnd = Color(0xff78d3a1);

  static const backgroundGradientBegin = Color(0xFF777777);
  static const backgroundGradientEnd = Color(0xFF5B5E5D);

  static const gradientColors = [gradientBegin, gradientEnd];

  static const defaultProfileColor = primary;
  static const profileColors = [
    Color(0xFFB896FF),
    Color(0xFF96FFE0),
    Color(0xFFFFF896),
    Color(0xFFFFAD96),
    Color(0xFF9C95AA),
    Color(0xFF5B8075)
  ];

  static const textPrimary = Color(0xFF41355b);
  static const border = secondary;
  static const splash = Color(0x40698583);

  static const white = Colors.white;
}

const double cardBorderRadius = 20;

const RoundedRectangleBorder cardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.all(Radius.circular(cardBorderRadius)),
  side: BorderSide(width: 2, color: ThemeColors.white),
);

const RoundedRectangleBorder dangerCardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.all(Radius.circular(cardBorderRadius)),
  side: BorderSide(width: 2, color: Color.fromARGB(128, 244, 67, 54)),
);

const BoxDecoration pageGradientDecoration = BoxDecoration(
  gradient: LinearGradient(
    tileMode: TileMode.mirror,
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0x60B896FF), // ThemeColors.gradientBegin.withAlpha(96)
      Color(0x4078d3a1), // ThemeColors.gradientEnd.withAlpha(64)
    ],
  ),
);