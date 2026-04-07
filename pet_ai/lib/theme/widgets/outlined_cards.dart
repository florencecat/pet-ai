import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../theme/app_colors.dart';
import '../../../services/event_service.dart';
import 'dart:ui';

class GlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.borderRadius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15), // Полупрозрачный белый
              borderRadius: BorderRadius.circular(borderRadius),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.2), // Тонкий светлый блик по краю
                width: 1.5,
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(borderRadius),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class DottedEventCard extends StatelessWidget {
  final PetEvent event;
  final VoidCallback? callback;
  final IconData? trailingIcon;
  final VoidCallback? trailingCallback;

  const DottedEventCard({
    super.key,
    required this.event,
    this.callback,
    this.trailingIcon,
    this.trailingCallback,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(5),
      child: DottedBorder(
        options: RoundedRectDottedBorderOptions(
          radius: Radius.circular(18),
          color: Theme.of(context).colorScheme.primary,
          dashPattern: [10, 5],
          strokeWidth: 2,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.all(Radius.circular(18)),
          clipBehavior: Clip.antiAlias,
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(18),
              splashColor: Theme.of(context).splashColor,
              onTap: callback,
              child: ListTile(
                leading: Icon(event.category.icon, color: event.category.color),
                title: Text(event.name),
                subtitle: Text(
                  DateFormat('dd.MM.yyyy – HH:mm').format(event.dateTime),
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
        ),
      ),
    );
  }
}

class EventCard extends StatelessWidget {
  final PetEvent event;
  final VoidCallback? callback;
  final IconData? trailingIcon;
  final VoidCallback? trailingCallback;

  const EventCard({
    super.key,
    required this.event,
    this.callback,
    this.trailingIcon,
    this.trailingCallback,
  });

  @override
  Widget build(BuildContext context) {
    return OutlinedInkCard(
      padding: 2,
      child: InkWell(
        splashColor: Theme.of(context).splashColor,
        onTap: callback,
        child: ListTile(
          leading: Icon(event.category.icon, color: event.category.color),
          title: Text(event.name),
          subtitle: Text(
            DateFormat('dd.MM.yyyy – HH:mm').format(event.dateTime),
          ),
          trailing: trailingIcon != null
              ? IconButton(
                  onPressed: trailingCallback,
                  icon: Icon(trailingIcon),
                )
              : null,
        ),
      ),
    );
  }
}

class SettingsCard extends StatelessWidget {
  final VoidCallback? callback;
  final IconData leadingIcon;
  final String title;
  final String? subtitle;
  final IconData? trailingIcon;
  final Color borderColor;
  final Color textColor;
  final RoundedRectangleBorder border;

  const SettingsCard({
    super.key,
    this.callback,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
  }) : borderColor = ThemeColors.border,
       textColor = ThemeColors.border,
       border = cardBorder;

  const SettingsCard.debug({
    super.key,
    this.callback,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
  }) : borderColor = ThemeColors.danger,
       textColor = ThemeColors.danger,
       border = dangerCardBorder;

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      shape: border,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: ListTile(
        leading: Icon(leadingIcon, color: borderColor),
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
            ? Icon(trailingIcon!, color: borderColor)
            : null,
        onTap: callback,
      ),
    );
  }
}

class OutlinedInkCard extends StatelessWidget {
  final VoidCallback? callback;
  final Widget? child;
  final double? padding;

  const OutlinedInkCard({super.key, this.callback, this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return OutlinedCard(
      padding: padding,
      child: InkWell(
        splashColor: Theme.of(context).splashColor,
        onTap: callback,
        child: child,
      ),
    );
  }
}

class OutlinedCard extends StatelessWidget {
  final Widget? child;
  final double? padding;

  const OutlinedCard({super.key, this.child, this.padding});

  @override
  Widget build(BuildContext context) {
    return Card.outlined(
      shape: cardBorder,
      clipBehavior: Clip.antiAliasWithSaveLayer,
      child: Padding(
        padding: EdgeInsetsGeometry.all(padding ?? 16),
        child: child,
      ),
    );
  }
}
