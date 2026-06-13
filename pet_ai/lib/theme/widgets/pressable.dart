import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Сила тактильного отклика для [Pressable].
enum HapticStrength { none, selection, light, medium, heavy }

/// Универсальная обёртка для нажимаемых элементов: при нажатии слегка
/// уменьшает дочерний виджет (scale-down) и подаёт тактильный отклик.
///
/// Используется как «премиальная» альтернатива голому `GestureDetector`:
/// масштабирование во время press + haptic делают интерфейс заметно
/// «дороже» практически без затрат на производительность.
class Pressable extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final HapticStrength haptic;
  final HapticStrength longPressHaptic;
  final double scale;
  final Duration duration;
  final HitTestBehavior behavior;

  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.haptic = HapticStrength.light,
    this.longPressHaptic = HapticStrength.medium,
    this.scale = 0.96,
    this.duration = const Duration(milliseconds: 110),
    this.behavior = HitTestBehavior.opaque,
  });

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
    reverseDuration: const Duration(milliseconds: 160),
    lowerBound: 0,
    upperBound: 1,
  );

  late final Animation<double> _scale = Tween<double>(
    begin: 1.0,
    end: widget.scale,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _down(_) {
    if (widget.onTap == null && widget.onLongPress == null) return;
    _ctrl.forward();
  }

  void _up(_) {
    if (!_ctrl.isAnimating && _ctrl.value == 0) return;
    _ctrl.reverse();
  }

  void _cancel() {
    if (!_ctrl.isAnimating && _ctrl.value == 0) return;
    _ctrl.reverse();
  }

  void _onTap() {
    if (widget.onTap == null) return;
    triggerHaptic(widget.haptic);
    widget.onTap!();
  }

  void _onLongPress() {
    if (widget.onLongPress == null) return;
    triggerHaptic(widget.longPressHaptic);
    widget.onLongPress!();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: widget.behavior,
      onTapDown: _down,
      onTapUp: _up,
      onTapCancel: _cancel,
      onTap: widget.onTap == null ? null : _onTap,
      onLongPress: widget.onLongPress == null ? null : _onLongPress,
      child: ScaleTransition(scale: _scale, child: widget.child),
    );
  }
}

/// Вызвать тактильный отклик нужной силы (no-op для [HapticStrength.none]).
void triggerHaptic(HapticStrength strength) {
  switch (strength) {
    case HapticStrength.none:
      return;
    case HapticStrength.selection:
      HapticFeedback.selectionClick();
      break;
    case HapticStrength.light:
      HapticFeedback.lightImpact();
      break;
    case HapticStrength.medium:
      HapticFeedback.mediumImpact();
      break;
    case HapticStrength.heavy:
      HapticFeedback.heavyImpact();
      break;
  }
}

/// Премиальный переход страницы: лёгкое смещение снизу + плавное появление.
/// Использовать вместо `MaterialPageRoute`, чтобы экран не «прыгал» по
/// дефолтной андроидной анимации, а появлялся мягко.
Route<T> appPageRoute<T>(WidgetBuilder builder, {bool fullscreenDialog = false}) {
  return PageRouteBuilder<T>(
    fullscreenDialog: fullscreenDialog,
    transitionDuration: const Duration(milliseconds: 320),
    reverseTransitionDuration: const Duration(milliseconds: 240),
    pageBuilder: (context, animation, secondaryAnimation) => builder(context),
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
        reverseCurve: Curves.easeInCubic,
      );
      final slide = Tween<Offset>(
        begin: const Offset(0, 0.04),
        end: Offset.zero,
      ).animate(curved);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(position: slide, child: child),
      );
    },
  );
}

/// Появление содержимого с лёгким fade + offset.
///
/// Подходит для списков и блоков, чтобы при первом построении они мягко
/// «всплывали», а не появлялись резко.
class AppearAnimation extends StatefulWidget {
  final Widget child;
  final Duration duration;
  final Duration delay;
  final Offset beginOffset;

  const AppearAnimation({
    super.key,
    required this.child,
    this.duration = const Duration(milliseconds: 420),
    this.delay = Duration.zero,
    this.beginOffset = const Offset(0, 0.04),
  });

  @override
  State<AppearAnimation> createState() => _AppearAnimationState();
}

class _AppearAnimationState extends State<AppearAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(
    vsync: this,
    duration: widget.duration,
  );

  late final Animation<double> _fade =
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOut);
  late final Animation<Offset> _offset = Tween<Offset>(
    begin: widget.beginOffset,
    end: Offset.zero,
  ).animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic));

  @override
  void initState() {
    super.initState();
    if (widget.delay == Duration.zero) {
      _ctrl.forward();
    } else {
      Future.delayed(widget.delay, () {
        if (mounted) _ctrl.forward();
      });
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
