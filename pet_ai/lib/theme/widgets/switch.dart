import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:provider/provider.dart';

class OutlinedSwitch extends StatelessWidget {
  final Color? activeThumbColor;
  final bool value;
  final Function(bool) onChanged;

  const OutlinedSwitch({
    super.key,
    required this.value,
    required this.onChanged,
    this.activeThumbColor,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();

    return Switch(
      inactiveThumbColor: ac.primaryColor,
      trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return Colors.transparent;
        }
        return ac.primaryColor;
      }),
      value: value,
      activeThumbColor: activeThumbColor ?? ac.primaryColor,
      onChanged: onChanged,
    );
  }
}
