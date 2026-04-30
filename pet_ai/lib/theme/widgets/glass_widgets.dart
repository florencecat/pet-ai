import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';

/// Имитация liquid-glass карточки без BackdropFilter.
///
/// Раньше использовался настоящий blur через [BackdropFilter] —
/// он крайне дорогой (каждая карточка читает фрейм-буфер и блюрит его),
/// поэтому при множестве карточек на странице UI заметно подтормаживал.
///
/// Сейчас рисуем плоский полупрозрачный фон с лёгким верхним хайлайтом
/// и тенью — визуально близко к стеклу, но без чтения буфера.
/// Обёрнут в [RepaintBoundary], чтобы изолировать перерисовки.
class GlassPlate extends StatelessWidget {
  final Widget child;
  final Color color;
  final bool transparent;
  final double padding;
  final List<Color>? gradientColors;

  const GlassPlate({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.transparent = true,
    this.padding = 8,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(28));
    final borderColor = transparent ? color.withAlpha(180) : color;
    final fillColor = transparent ? color.withAlpha(220) : color;

    final content = ClipRRect(
      borderRadius: borderRadius,
      child: Stack(
        children: [
          // Лёгкий хайлайт сверху — имитация преломления стекла
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withAlpha(64),
                      Colors.white.withAlpha(0),
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                ),
              ),
            ),
          ),
          Padding(padding: EdgeInsets.all(padding), child: child),
        ],
      ),
    );

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: fillColor,
          border: Border.all(color: borderColor, width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withAlpha(20),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: gradientColors != null
            ? DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  gradient: LinearGradient(colors: gradientColors!),
                ),
                child: content,
              )
            : content,
      ),
    );
  }
}

class SoftGlassPlate extends StatelessWidget {
  final Widget child;
  final Color color;

  const SoftGlassPlate({
    super.key,
    required this.child,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(28));
    final borderColor = color.withAlpha(180);
    final fillColor = color.withAlpha(64);

    return RepaintBoundary(
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          color: fillColor,
          border: Border.all(color: borderColor, width: 1.2),
        ),
        child: ClipRRect(
          borderRadius: borderRadius,
          child: Stack(
            children: [
              // Лёгкий хайлайт сверху — имитация преломления стекла
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: IgnorePointer(child: Container(height: 28)),
              ),
              Padding(padding: const EdgeInsets.all(8), child: child),
            ],
          ),
        ),
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final VoidCallback? callback;
  final Widget child;
  final Color color;
  final double padding;
  final List<Color>? gradientColors;
  final bool transparent;

  const GlassCard({
    super.key,
    required this.callback,
    required this.child,
    this.color = Colors.white,
    this.padding = 8,
    this.transparent = false,
    this.gradientColors,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: padding,
      color: color,
      transparent: transparent,
      gradientColors: gradientColors,
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
        transparent: false,
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
                      ? '⚠ ${formatSmartDateTime(event.dateTime)}'
                      : formatSmartDateTime(event.dateTime),
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    inherit: true,
                    color: overdue
                        ? const Color(0xFFB85C00)
                        : ThemeColors.textPrimary,
                    fontWeight: overdue ? FontWeight.w600 : FontWeight.normal,
                  ),
                ),
                if (petName != null) ...[
                  const SizedBox(height: 3),
                  GlassBadge(
                    name: petName!,
                    color: petColor ?? ThemeColors.primary,
                  ),
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
    this.textColor = ThemeColors.border
  }) : color = ThemeColors.white;

  const GlassSettingsCard.debug({
    super.key,
    this.callback,
    required this.leadingIcon,
    required this.title,
    this.subtitle,
    this.trailingIcon,
  }) : color = ThemeColors.white,
       textColor = ThemeColors.dangerZone;

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

class GlassBadge extends StatelessWidget {
  final Icon? icon;
  final String name;
  final Color color;

  const GlassBadge({
    super.key,
    this.icon,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: () {},
      icon: icon,
      style: OutlinedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: color.withAlpha(200), width: 0.8),
        ),
        backgroundColor: color.withAlpha(60),
        foregroundColor: color.withAlpha(200),
        padding: EdgeInsetsGeometry.all(8),
        alignment: AlignmentGeometry.center,
      ),
      label: Text(
        name,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color.withAlpha(200),
        ),
      ),
    );
  }
}

class SoftGlassBadge extends StatefulWidget {
  final Color color;
  final IconData icon;
  final String label;
  final bool selected;
  final ValueChanged<bool>? onChanged;

  const SoftGlassBadge({
    super.key,
    required this.color,
    required this.icon,
    required this.label,
    required this.selected,
    this.onChanged,
  });

  @override
  State<SoftGlassBadge> createState() => _SoftGlassBadgeState();
}

class _SoftGlassBadgeState extends State<SoftGlassBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  Future<void> _onTap() async {
    await _controller.forward();
    await _controller.reverse();

    if (widget.onChanged != null) {
      widget.onChanged!(!widget.selected);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.color;
    final selected = widget.selected;

    return GestureDetector(
      onTap: _onTap,
      child: AnimatedBuilder(
        animation: _scaleAnimation,
        builder: (context, child) {
          return Transform.scale(scale: _scaleAnimation.value, child: child);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: selected ? color.withAlpha(200) : color.withAlpha(25),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                widget.icon,
                size: 14,
                color: selected ? Colors.white : color,
              ),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
