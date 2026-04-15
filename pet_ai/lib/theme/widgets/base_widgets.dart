import 'package:flutter/material.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/app_theme.dart';

InputDecoration baseInputDecoration(String label, {Widget? suffixIcon}) {
  return InputDecoration(
    labelText: label,
    labelStyle: AppTheme.lightTheme.textTheme.bodyLarge,
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
