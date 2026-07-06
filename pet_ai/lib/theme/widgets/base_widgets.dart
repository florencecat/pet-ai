import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_theme.dart';
import 'package:provider/provider.dart';

InputDecoration baseInputDecoration(BuildContext context, String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: AppTheme.lightTheme.textTheme.bodyLarge!.copyWith(
      inherit: true,
      color: context.watch<AppearanceController>().secondaryColor.withAlpha(128),
    ),
    alignLabelWithHint: true,

    floatingLabelBehavior: FloatingLabelBehavior.never,
    filled: true,
    fillColor: ThemeColors.white,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
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
