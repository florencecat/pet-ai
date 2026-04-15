import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';

class GlassPlate extends StatelessWidget {
  final Widget child;
  final Color color;

  const GlassPlate({super.key, required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(28);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),

          ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: color.withAlpha(128),
                  border: Border.all(color: color.withAlpha(153), width: 1.2),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          gradient: LinearGradient(
                            colors: [color.withAlpha(180), color.withAlpha(0)],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    Padding(padding: const EdgeInsets.all(8), child: child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final VoidCallback? callback;
  final Widget child;
  final Color color;

  const GlassCard({
    super.key,
    required this.callback,
    required this.child,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      color: color,
      child: InkWell(
        onTap: () {
          HapticFeedback.mediumImpact();
          if (callback != null) callback!.call();
        },
        child: child,
      ),
    );
  }
}

class GlassEventCard extends StatelessWidget {
  final VoidCallback? callback;
  final PetEvent event;
  final IconData? trailingIcon;
  final VoidCallback? trailingCallback;
  final ValueChanged<bool>? onCompletedChanged;

  /// Дата вхождения, для которой проверяется/переключается статус выполнения.
  /// Если не задана — используется event.dateTime.
  final DateTime? selectedDate;

  /// Цвет профиля питомца (для режима «все питомцы»)
  final Color? petColor;

  /// Имя питомца (для режима «все питомцы»)
  final String? petName;

  const GlassEventCard({
    super.key,
    required this.event,
    this.callback,
    this.trailingIcon,
    this.trailingCallback,
    this.onCompletedChanged,
    this.selectedDate,
    this.petColor,
    this.petName,
  });

  DateTime get _effectiveDate => selectedDate ?? event.dateTime;

  bool get _isCompleted => event.isCompletedOn(_effectiveDate);

  @override
  Widget build(BuildContext context) {
    final overdue = event.isOverdue;
    final cardColor = overdue ? const Color(0xFFFFAD96) : Colors.white;

    return Padding(
      padding: EdgeInsetsGeometry.symmetric(vertical: 8),
      child: GlassPlate(
        color: cardColor,
        child: InkWell(
          onTap: () {
            HapticFeedback.lightImpact();
            if (callback != null) callback!.call();
          },
          child: ListTile(
            leading: onCompletedChanged != null
                ? GestureDetector(
                    onTap: () => onCompletedChanged!(!_isCompleted),
                    child: Icon(
                      _isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _isCompleted
                          ? ThemeColors.primary
                          : event.category.color,
                      size: 28,
                    ),
                  )
                : Icon(event.category.icon, color: event.category.color),
            title: Text(
              event.name,
              style: Theme.of(context).textTheme.titleMedium!.copyWith(
                inherit: true,
                color: ThemeColors.textPrimary,
                decoration: _isCompleted ? TextDecoration.lineThrough : null,
              ),
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  overdue
                      ? '⚠ ${DateFormat('dd.MM.yyyy – HH:mm').format(event.dateTime)}'
                      : DateFormat('dd.MM.yyyy – HH:mm').format(event.dateTime),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    inherit: true,
                    color: overdue
                        ? const Color(0xFFB85C00)
                        : ThemeColors.textPrimary,
                    fontWeight:
                        overdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (petName != null) ...[
                  const SizedBox(height: 3),
                  _PetBadge(name: petName!, color: petColor ?? ThemeColors.primary),
                ],
              ],
            ),
            trailing: trailingIcon != null
                ? IconButton(
                    onPressed: trailingCallback,
                    icon: Icon(trailingIcon),
                  )
                : null,
          ),
        ),
      ),
    );
  }
}

class _PetBadge extends StatelessWidget {
  final String name;
  final Color color;

  const _PetBadge({required this.name, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withAlpha(60),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(100), width: 0.8),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: color.withAlpha(200),
        ),
      ),
    );
  }
}

class GlassSettingsCard extends StatelessWidget {
  final VoidCallback? callback;
  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final IconData? trailingIcon;
  final Color color;
  final Color textColor;

  const GlassSettingsCard({
    super.key,
    this.callback,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
  }) : color = ThemeColors.white,
       textColor = ThemeColors.border;

  const GlassSettingsCard.debug({
    super.key,
    this.callback,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
  }) : color = ThemeColors.white,
       textColor = ThemeColors.danger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsetsGeometry.only(bottom: 8),
      child: GlassPlate(
        color: color,
        child: ListTile(
          leading: Icon(leadingIcon, color: textColor),
          title: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.bodyLarge!.copyWith(inherit: true, color: textColor),
          ),
          subtitle: subtitle != null
              ? Text(
                  subtitle!,
                  style: Theme.of(context).textTheme.bodySmall!.copyWith(
                    inherit: true,
                    color: textColor,
                  ),
                )
              : null,
          trailing: trailingIcon != null
              ? Icon(trailingIcon!, color: textColor)
              : null,
          onTap: callback,
        ),
      ),
    );
  }
}
