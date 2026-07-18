import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:provider/provider.dart';

class SmartDateInput extends StatelessWidget {
  final VoidCallback onTap;
  final VoidCallback onTodayTap;
  final TextEditingController controller;
  final String hint;

  const SmartDateInput({
    super.key,
    required this.onTap,
    required this.onTodayTap,
    required this.controller,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      keyboardType: TextInputType.none,
      onTap: onTap,
      controller: controller,
      decoration: baseInputDecoration(
        context,
        hint: hint,
        suffixIcon: controller.text.isEmpty
            ? Padding(
                padding: EdgeInsetsGeometry.symmetric(horizontal: 11),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.end,
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: onTodayTap,
                      style: TextButton.styleFrom(
                        backgroundColor: context
                            .watch<AppearanceController>()
                            .primaryColor
                            .withAlpha(30),
                      ),
                      child: Text('Сегодня'),
                    ),
                    Icon(
                      Icons.calendar_today,
                      color: Theme.of(context).dividerColor,
                      size: 18,
                    ),
                  ],
                ),
              )
            : Icon(
                Icons.calendar_today,
                color: Theme.of(context).dividerColor,
                size: 18,
              ),
      ),
      style: Theme.of(context).textTheme.bodyMedium,
    );
  }
}
