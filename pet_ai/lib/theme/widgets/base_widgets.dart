import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_theme.dart';
import 'package:provider/provider.dart';

InputDecoration baseInputDecoration(
  BuildContext context, {
  Widget? prefixIcon,
  String? hint,
  Widget? suffixIcon,
  bool useBorder = false,
}) {
  final secondaryColor = context.watch<AppearanceController>().secondaryColor;
  return InputDecoration(
    labelText: hint,
    labelStyle: AppTheme.lightTheme.textTheme.bodyLarge!.copyWith(
      inherit: true,
      color: secondaryColor.withAlpha(128),
    ),
    alignLabelWithHint: true,
    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: ThemeColors.white,
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: useBorder
          ? BorderSide(
        color: secondaryColor.withAlpha(128),
        style: BorderStyle.solid,
        width: 2,
      )
          : BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: useBorder
          ? BorderSide(
        color: secondaryColor,
        style: BorderStyle.solid,
        width: 2,
      )
          : BorderSide.none,
    ),
    suffixIcon: suffixIcon,
  );
}

RoundedRectangleBorder baseRoundedRectangleBorder() {
  return RoundedRectangleBorder(
    borderRadius: BorderRadius.circular(16),
    side: BorderSide.none,
  );
}
