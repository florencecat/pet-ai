import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ColorPalette {
  final Color mainColor;
  final Color darkShade;

  const ColorPalette(this.mainColor, this.darkShade);

  Map<String, dynamic> toJson() => {
    'mainColor': mainColor.toARGB32(),
    'darkShade': darkShade.toARGB32(),
  };

  factory ColorPalette.fromJson(Map<String, dynamic> json) =>
      ColorPalette(
        Color(json['mainColor'] as int),
        Color(json['darkShade'] as int),
      );
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

  static const defaultProfilePalette = ColorPalette(
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

  static const List<ColorPalette> profilePalettes = [
    ColorPalette(Color(0xFFB896FF), Color(0xFF50416F)),
    ColorPalette(Color(0xFF96FFE0), Color(0xFF416F61)),
    ColorPalette(Color(0xFFF6F091), Color(0xFF6F6B41)),
    ColorPalette(Color(0xFFFFAD96), Color(0xFF6F4B41)),
    ColorPalette(Color(0xFF9C95AA), Color(0xFF38353C)),
    ColorPalette(Color(0xFF5B8075), Color(0xFF3C554E)),
  ];

  static const textPrimary = Color(0xFF41355b);
  static const border = secondary;
  static const splash = Color(0x40698583);

  static const maleGender = Color(0xFFdcebf5);
  static const femaleGender = Color(0xFFf4d9e9);

  // home page
  static const vetCardIconColor = Color(0xFFe07b5c);
  static const filesIconColor = Color(0xFF9a6a1f);
  static const notesIconColor = Color(0xFF3d6e91);

  // health page
  static const weightIconColor = Color(0xFF8a4a77);
  static const moodIconColor = Color(0xFF9a6a1f);
  static const foodIconColor = Color(0xFF3d6e91);

  // ai page
  static const List<Color> aiChatIconGradient = [
    Color(0xFFf1a191),
    Color(0xFFd89abb),
  ];
  static const aiChatOnlineColor = Color(0xFF6fb888);

  static const white = Colors.white;

  static const positiveDynamics = Color(0xFF6fb888);
  static const negativeDynamics = Color(0xFFe07b5c);
  static const neutralDynamics = Color(0xFF9a8e84);

  static const ok = ColorPalette(Color(0xFF43A047), Color(0xff235426));
  static const info = ColorPalette(Color(0xFF1976D2), Color(0xff0B335C));
  static const warning = ColorPalette(Color(0xFFFB8C00), Color(0xffD67600));
  static const danger = ColorPalette(Color(0xFFE53935), Color(0xff471110));
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

String declension(
  int number,
  String nominative,
  String genitiveSingular,
  String genitivePlural,
) {
  final n = number.abs() % 100;
  final n1 = n % 10;

  if (n >= 11 && n <= 19) return genitivePlural;
  if (n1 == 1) return nominative;
  if (n1 >= 2 && n1 <= 4) return genitiveSingular;
  return genitivePlural;
}

Text dynamicsTextWidget(double value, TextStyle style) {
  Color color;
  if (value.abs() < precisionErrorTolerance) {
    color = ThemeColors.neutralDynamics;
  } else if (value > 0) {
    color = ThemeColors.positiveDynamics;
  } else {
    color = ThemeColors.negativeDynamics;
  }

  return Text(
    value > 0
        ? '+${value.toStringAsFixed(1)} кг'
        : '${value.toStringAsFixed(1)} кг',
    style: style.copyWith(
      inherit: true,
      color: color,
      fontWeight: FontWeight.w700,
    ),
  );
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
