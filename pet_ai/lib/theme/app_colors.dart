import 'package:flutter/material.dart';

class ThemeColors {
  static const background = Color(0xFFF4FBF9);
  static const primary = Color(0xFF3B807B);
  static const secondary = Color(0xFF355553);
  static const unselected = Color(0x603B807B);
  static const danger = Color(0xFFF44336);
  static const error = Color(0xFFBA1A1A);

  static const gradientBegin = Color(0xFF0bbce4);
  static const gradientEnd = Color(0xFF0edfa6);

  static const gradientColors = [gradientBegin, gradientEnd];

  static const textPrimary = Color(0xFF00453D);
  static const border = secondary;
  static const splash = Color(0x40698583);

  static const white = Colors.white;
}

const double cardBorderRadius = 20;

const RoundedRectangleBorder cardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.all(Radius.circular(cardBorderRadius)),
  side: BorderSide(width: 2, color: ThemeColors.border),
);

const RoundedRectangleBorder dangerCardBorder = RoundedRectangleBorder(
  borderRadius: BorderRadiusGeometry.all(Radius.circular(cardBorderRadius)),
  side: BorderSide(width: 2, color: Color.fromARGB(128, 244, 67, 54)),
);