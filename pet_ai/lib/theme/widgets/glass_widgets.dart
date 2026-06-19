import 'package:flutter/material.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:provider/provider.dart';

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
  final double padding;
  final List<Color>? gradientColors;
  final bool useShadow;

  const GlassPlate({
    super.key,
    required this.child,
    this.color = Colors.white,
    this.padding = 8,
    this.gradientColors,
    this.useShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    const borderRadius = BorderRadius.all(Radius.circular(24));
    final borderColor = color.withAlpha(180);
    final fillColor = color;

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
          boxShadow: useShadow
              ? [
                  BoxShadow(
                    color: Colors.black.withAlpha(20),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : [],
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
    final fillColor = color;

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
  final bool useShadow;

  const GlassCard({
    super.key,
    required this.callback,
    required this.child,
    this.color = Colors.white,
    this.padding = 8,
    this.transparent = false,
    this.gradientColors,
    this.useShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: padding,
      color: color,
      gradientColors: gradientColors,
      useShadow: useShadow,
      child: Pressable(
        onTap: callback == null ? null : () => callback!(),
        haptic: HapticStrength.light,
        child: child,
      ),
    );
  }
}

class GlassEventCard extends StatelessWidget {
  final VoidCallback? callback;
  final Event event;
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
        child: Pressable(
          onTap: callback == null ? null : () => callback!(),
          haptic: HapticStrength.light,
          child: ListTile(
            leading: onCompletedChanged != null
                ? Pressable(
                    onTap: () => onCompletedChanged!(!_isCompleted),
                    haptic: HapticStrength.selection,
                    scale: 0.9,
                    child: Icon(
                      _isCompleted
                          ? Icons.check_circle
                          : Icons.radio_button_unchecked,
                      color: _isCompleted
                          ? context.watch<AppearanceController>().primaryColor
                          : event.style.color,
                      size: 28,
                    ),
                  )
                : Icon(event.style.icon, color: event.style.color),
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
                    color:
                        petColor ??
                        context.watch<AppearanceController>().primaryColor,
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

class GlassListTile extends StatelessWidget {
  final IconData? icon;
  final Color iconColor;
  final Widget? customIcon;
  final String title;
  final String? subtitle;
  final Widget? bottomBadge;
  final Widget? trailing;
  final VoidCallback? callback;

  const GlassListTile({
    super.key,
    required this.iconColor,
    required this.title,
    this.icon,
    this.subtitle,
    this.customIcon,
    this.bottomBadge,
    this.trailing,
    this.callback,
  });

  @override
  Widget build(BuildContext context) {
    assert(icon == null || customIcon == null);

    Widget tileIcon;
    if (icon != null) {
      tileIcon = SoftRoundedIcon(
        icon: icon!,
        color: iconColor.withAlpha(128),
        size: 22,
      );
    } else {
      tileIcon = customIcon!;
    }

    return GlassPlate(
      child: Pressable(
        onTap: callback,
        haptic: HapticStrength.light,
        child: ListTile(
          leading: tileIcon,
          title: Text(title, style: Theme.of(context).textTheme.titleMedium),
          subtitle: Column(
            spacing: 6,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (subtitle != null)
                Text(subtitle!, style: Theme.of(context).textTheme.bodySmall),
              ?bottomBadge,
            ],
          ),
          trailing: trailing,
        ),
      ),
    );
  }
}

class DeleteIconButton extends StatelessWidget {
  final VoidCallback callback;

  const DeleteIconButton({super.key, required this.callback});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.delete_outline, size: 20),
      color: ThemeColors.dangerZone.withAlpha(180),
      onPressed: () {
        // heavy haptic — это деструктивное действие, привлекаем внимание
        triggerHaptic(HapticStrength.heavy);
        callback();
      },
    );
  }
}

class SoftGlassBadge extends StatefulWidget {
  final Color color;
  final IconData? icon;
  final String label;
  final TextStyle? labelStyle;
  final bool selected;
  final ValueChanged<bool>? onChanged;
  final double size;

  const SoftGlassBadge({
    super.key,
    required this.color,
    required this.label,
    this.icon,
    this.labelStyle,
    this.selected = false,
    this.onChanged,
    this.size = 10,
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
      duration: const Duration(milliseconds: 100),
    );

    _scaleAnimation = Tween<double>(
      begin: 1.0,
      end: 0.92,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
  }

  Future<void> _onTap() async {
    if (widget.onChanged != null) {
      triggerHaptic(HapticStrength.selection);
      await _controller.forward();
      await _controller.reverse();
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
              if (widget.icon != null) ...[
                Icon(
                  widget.icon,
                  size: widget.size * 1.4,
                  color: selected ? Colors.white : color,
                ),
                const SizedBox(width: 5),
              ],

              Text(
                widget.label,
                style:
                    widget.labelStyle ??
                    TextStyle(
                      fontSize: widget.size,
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

class SoftRoundedIcon extends StatelessWidget {
  final IconData icon;
  final Color? color;
  final List<Color>? gradient;
  final double size;

  const SoftRoundedIcon({
    super.key,
    required this.icon,
    this.color,
    this.gradient,
    this.size = 20,
  });

  @override
  Widget build(BuildContext context) {
    assert(color != null || gradient != null);

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.8),
        gradient: gradient == null
            ? null
            : LinearGradient(
                colors: gradient!,
                begin: AlignmentGeometry.topLeft,
                end: AlignmentGeometry.bottomRight,
              ),
        color: color?.withAlpha(64),
      ),
      child: Padding(
        padding: EdgeInsetsGeometry.all(size * 0.6),
        child: Icon(icon, size: size, color: color ?? Colors.white),
      ),
    );
  }
}

// ─── Коллапсируемая секция ────────────────────────────────────────────────────
//
// Шеврон слева от заголовка поворачивается на 90° (право→низ) при раскрытии.
// Тело анимируется через AnimatedAlign.heightFactor (0 → 1).
// Состояние expand/collapse управляется снаружи через [expanded] + [onToggle].

class CollapsibleSection extends StatelessWidget {
  final bool expanded;
  final VoidCallback onToggle;

  /// Контент между шевроном и [trailing] (например, текст или Row с пикером).
  final Widget titleContent;

  /// Необязательный виджет справа (кнопка «Добавить», «Детали» и т.п.).
  final Widget? trailing;

  /// Тело секции — показывается/скрывается с анимацией.
  final Widget body;

  const CollapsibleSection({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.titleContent,
    this.trailing,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Строка заголовка ──────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: GestureDetector(
                onTap: () {
                  triggerHaptic(HapticStrength.selection);
                  onToggle();
                },
                behavior: HitTestBehavior.opaque,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(left: 2, right: 2),
                      child: AnimatedRotation(
                        turns: expanded ? 0.25 : 0.0,
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.chevron_right,
                          size: 22,
                          color: Theme.of(
                            context,
                          ).textTheme.titleLarge?.color?.withAlpha(160),
                        ),
                      ),
                    ),
                    Flexible(child: titleContent),
                  ],
                ),
              ),
            ),
            if (trailing != null) trailing!,
          ],
        ),
        // ── Тело (анимированное) ──────────────────────────────────────────
        ClipRect(
          child: AnimatedAlign(
            alignment: Alignment.topCenter,
            heightFactor: expanded ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            child: body,
          ),
        ),
      ],
    );
  }
}