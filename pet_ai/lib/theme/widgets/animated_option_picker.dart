import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';

/// Один пункт кастомного пикера.
class PickerOption<T> {
  final T value;
  final String label;
  final IconData? icon;

  const PickerOption({required this.value, required this.label, this.icon});
}

/// «Дорогая» замена скучному [PopupMenuButton]/[DropdownButton]:
/// компактное меню-карточка, которое раскрывается из триггера с упругой
/// анимацией и покадровым появлением пунктов, отдаёт тактильный отклик при
/// открытии и выборе, а шеврон плавно переворачивается.
///
/// Значение хранит вызывающий — виджет только показывает [value] и сообщает
/// о выборе через [onChanged].
class AnimatedOptionPicker<T> extends StatefulWidget {
  final T value;
  final List<PickerOption<T>> options;
  final ValueChanged<T> onChanged;

  /// Содержимое триггера (обычно [Text] с текущим значением). Шеврон
  /// пикер рисует сам.
  final Widget child;

  final bool enabled;
  final bool showChevron;

  /// Цвет шеврона и акцентов меню. По умолчанию — primaryColor темы.
  final Color? accentColor;

  /// Минимальная ширина выпадающей карточки.
  final double minMenuWidth;

  const AnimatedOptionPicker({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    required this.child,
    this.enabled = true,
    this.showChevron = true,
    this.accentColor,
    this.minMenuWidth = 150,
  });

  @override
  State<AnimatedOptionPicker<T>> createState() =>
      _AnimatedOptionPickerState<T>();
}

class _AnimatedOptionPickerState<T> extends State<AnimatedOptionPicker<T>>
    with SingleTickerProviderStateMixin {
  final LayerLink _link = LayerLink();
  late final AnimationController _ctrl;
  OverlayEntry? _entry;
  bool _isOpen = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
      reverseDuration: const Duration(milliseconds: 160),
    );
  }

  @override
  void dispose() {
    _entry?.remove();
    _entry = null;
    _ctrl.dispose();
    super.dispose();
  }

  void _openMenu() {
    if (!widget.enabled || _entry != null) return;
    HapticFeedback.selectionClick();
    _entry = OverlayEntry(builder: (_) => _buildOverlay());
    Overlay.of(context).insert(_entry!);
    setState(() => _isOpen = true);
    _ctrl.forward(from: 0);
  }

  Future<void> _closeMenu() async {
    if (_entry == null) return;
    setState(() => _isOpen = false);
    try {
      await _ctrl.reverse();
    } catch (_) {
      // Виджет мог быть размонтирован во время анимации — не критично.
    }
    _entry?.remove();
    _entry = null;
  }

  void _select(T value) {
    HapticFeedback.selectionClick();
    widget.onChanged(value);
    _closeMenu();
  }

  Widget _buildOverlay() {
    return Stack(
      children: [
        // Барьер: тап мимо меню закрывает его.
        Positioned.fill(
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _closeMenu,
          ),
        ),
        CompositedTransformFollower(
          link: _link,
          showWhenUnlinked: false,
          targetAnchor: Alignment.bottomRight,
          followerAnchor: Alignment.topRight,
          offset: const Offset(0, 6),
          child: Align(
            alignment: Alignment.topRight,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final v = _ctrl.value.clamp(0.0, 1.0);
                final scale = 0.82 + Curves.easeOutBack.transform(v) * 0.18;
                return Opacity(
                  opacity: v,
                  child: Transform.scale(
                    scale: scale,
                    alignment: Alignment.topRight,
                    child: child,
                  ),
                );
              },
              child: _menuCard(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _menuCard() {
    final ac = context.read<AppearanceController>();
    return Material(
      color: Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: widget.minMenuWidth,
          maxWidth: 280,
          maxHeight: 320,
        ),
        child: IntrinsicWidth(
          child: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: ThemeColors.white,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: ac.primaryColor.withAlpha(46)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(36),
                  blurRadius: 26,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (var i = 0; i < widget.options.length; i++)
                    _optionRow(ac, widget.options[i], i),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _optionRow(AppearanceController ac, PickerOption<T> opt, int index) {
    final selected = opt.value == widget.value;
    final total = widget.options.length;

    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, child) {
        // Покадровое появление: каждый следующий пункт чуть позже предыдущего.
        final start = total <= 1 ? 0.0 : (index / total) * 0.45;
        final local = ((_ctrl.value - start) / (1 - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * 10),
            child: child,
          ),
        );
      },
      child: Pressable(
        haptic: HapticStrength.none, // отклик даём в _select, чтобы не двоить
        scale: 0.97,
        onTap: () => _select(opt.value),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected
                ? ac.primaryColor.withAlpha(38)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (opt.icon != null) ...[
                Icon(opt.icon, size: 18, color: ac.secondaryColor),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  opt.label,
                  style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                    color: ac.secondaryColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 10),
                Icon(Icons.check_rounded, size: 18, color: ac.primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent =
        widget.accentColor ??
        context.watch<AppearanceController>().primaryColor;

    return CompositedTransformTarget(
      link: _link,
      child: GestureDetector(
        onTap: widget.enabled ? _openMenu : null,
        behavior: HitTestBehavior.opaque,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            widget.child,
            if (widget.showChevron)
              AnimatedRotation(
                turns: _isOpen ? 0.5 : 0.0,
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeOut,
                child: Icon(Icons.expand_more, size: 22, color: accent),
              ),
          ],
        ),
      ),
    );
  }
}
