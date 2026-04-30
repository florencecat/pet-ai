import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ProfileColorPalette {
  final Color mainColor;
  final Color darkShade;

  const ProfileColorPalette(this.mainColor, this.darkShade);

  Map<String, dynamic> toJson() => {
    'mainColor': mainColor.toARGB32(),
    'darkShade': darkShade.toARGB32(),
  };

  factory ProfileColorPalette.fromJson(Map<String, dynamic> json) =>
      ProfileColorPalette(Color(json['mainColor'] as int), Color(json['darkShade'] as int));
}

class ThemeColors {
  static const background = Color(0xFFf4f3ee);
  static const primary = Color(0xFFB896FF);
  static const secondary = Color(0xFF786B96);
  static const unselected = Color(0x603B807B);
  static const dangerZone = Color(0xFFF44336);
  static const error = Color(0xFFBA1A1A);

  static const gradientBegin = Color(0xFFB896FF);
  static const gradientEnd = Color(0xff78d3a1);

  static const backgroundGradientBegin = Color(0xFF777777);
  static const backgroundGradientEnd = Color(0xFF5B5E5D);

  static const gradientColors = [gradientBegin, gradientEnd];

  static const defaultProfileColor = primary;

  static const defaultProfilePalette = ProfileColorPalette(
    Color(0xFFB896FF),
    Color(0xFF50416F),
  );

  static const profileColors = [
    Color(0xFFB896FF),
    Color(0xFF96FFE0),
    Color(0xFFF6F091),
    Color(0xFFFFAD96),
    Color(0xFF9C95AA),
    Color(0xFF5B8075),
  ];

  static const darkProfileColors = [
    Color(0xFF50416F),
    Color(0xFF416F61),
    Color(0xFF6F6B41),
    Color(0xFF6F4B41),
    Color(0xFF38353C),
    Color(0xFF3C554E),
  ];

  static const List<ProfileColorPalette> profilePalettes = [
    ProfileColorPalette(Color(0xFFB896FF), Color(0xFF50416F)),
    ProfileColorPalette(Color(0xFF96FFE0), Color(0xFF416F61)),
    ProfileColorPalette(Color(0xFFF6F091), Color(0xFF6F6B41)),
    ProfileColorPalette(Color(0xFFFFAD96), Color(0xFF6F4B41)),
    ProfileColorPalette(Color(0xFF9C95AA), Color(0xFF38353C)),
    ProfileColorPalette(Color(0xFF5B8075), Color(0xFF3C554E)),
  ];

  static const textPrimary = Color(0xFF41355b);
  static const border = secondary;
  static const splash = Color(0x40698583);

  static const white = Colors.white;

  static const ok = Color(0xFF43A047);
  static const info = Color(0xFF1976D2);
  static const warning = Color(0xFFFB8C00);
  static const danger = Color(0xFFE53935);
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

/// Форматирует дату: "Сегодня", "Вчера", "Завтра" или [pattern].
String formatSmartDate(
  DateTime d, {
  String pattern = 'dd.MM.yyyy',
  String locale = 'ru',
}) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(d.year, d.month, d.day);
  final diff = target.difference(today).inDays;

  if (diff == 0) return 'Сегодня';
  if (diff == -1) return 'Вчера';
  if (diff == 1) return 'Завтра';
  return DateFormat(pattern, locale).format(d);
}

/// Форматирует дату + время: "Сегодня в 14:30" или "dd.MM.yyyy – HH:mm".
String formatSmartDateTime(DateTime d) {
  final datePart = formatSmartDate(d);
  final timePart = DateFormat('HH:mm').format(d);
  final isRelative =
      datePart == 'Сегодня' || datePart == 'Вчера' || datePart == 'Завтра';
  return isRelative
      ? '$datePart в $timePart'
      : '${DateFormat('dd.MM.yyyy').format(d)} – $timePart';
}

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
