import 'dart:math' as math;

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
/// Направление раскрытия выбирается при открытии: если снизу места не хватает
/// (пикер у нижнего края экрана или из-под него вылезла клавиатура), меню
/// уходит вверх. Высота в любом случае ограничена свободным местом — если
/// пунктов больше, чем влезает, список скроллится.
///
/// Значение хранит вызывающий — виджет только показывает [value] и сообщает
/// о выборе через [onChanged].
class AnimatedOptionPicker<T> extends StatefulWidget {
  final T? value;
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
  /// Зазор между триггером и карточкой меню, он же отступ от краёв экрана.
  static const double _gap = 6;
  static const double _screenMargin = 8;
  static const double _maxMenuHeight = 320;

  /// Меньше уже не карточка, а щель: если и столько не влезает, лучше
  /// вылезти за край, чем показать полоску в один пиксель.
  static const double _minMenuHeight = 96;

  final LayerLink _link = LayerLink();
  late final AnimationController _ctrl;
  OverlayEntry? _entry;
  bool _isOpen = false;

  /// Раскрываться вверх. Решается в [_openMenu] — позиция триггера к этому
  /// моменту уже известна, а внутри оверлея её узнать неоткуда.
  bool _openUp = false;
  double _menuMaxHeight = _maxMenuHeight;

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

  /// Высота карточки до её вёрстки: все пункты одинаковые, так что считаем по
  /// одной строке. Оценка нужна только чтобы выбрать сторону — от промаха
  /// меню не сломается, высоту всё равно ограничит [_menuMaxHeight].
  double _estimateMenuHeight() {
    final style = Theme.of(context).textTheme.bodyLarge!;
    final textHeight = MediaQuery.textScalerOf(
      context,
    ).scale(style.fontSize ?? 16);
    // Строка: паддинги 11 сверху и снизу + маржины 1 + контент (текст либо
    // иконка 18). Карточка: паддинги 6 сверху и снизу + рамка.
    final rowHeight = math.max(textHeight * 1.35, 18.0) + 24;
    return widget.options.length * rowHeight + 14;
  }

  /// Выбирает сторону и предел высоты по свободному месту вокруг триггера.
  void _resolveMenuPlacement() {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return;

    final triggerTop = box.localToGlobal(Offset.zero).dy;
    final triggerBottom = triggerTop + box.size.height;

    // Геометрию берём у view, а не у ближайшего MediaQuery: Scaffold вырезает
    // viewInsets из данных для body, и через MediaQuery.of клавиатуры не видно
    // — меню раскрывалось прямо под неё. Оверлей же рисуется поверх всего, в
    // координатах экрана, так что и мерить надо экран.
    final view = MediaQueryData.fromView(View.of(context));
    // Клавиатура (viewInsets) съедает низ так же, как край экрана.
    final bottomLimit =
        view.size.height - view.viewInsets.bottom - _screenMargin;
    final topLimit = view.padding.top + _screenMargin;

    final spaceBelow = bottomLimit - triggerBottom - _gap;
    final spaceAbove = triggerTop - topLimit - _gap;

    final wanted = math.min(_estimateMenuHeight(), _maxMenuHeight);
    // Вверх — только если снизу не помещается и сверху места больше.
    _openUp = spaceBelow < wanted && spaceAbove > spaceBelow;

    final available = _openUp ? spaceAbove : spaceBelow;
    _menuMaxHeight = available.clamp(_minMenuHeight, _maxMenuHeight);
  }

  void _openMenu() {
    if (!widget.enabled || _entry != null) return;
    HapticFeedback.selectionClick();
    _resolveMenuPlacement();
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
    // Вверх карточка растёт сама: цепляем её низ к верху триггера, и высота
    // набирается в противоположную сторону — знать её заранее не нужно.
    final anchor = _openUp ? Alignment.bottomRight : Alignment.topRight;
    final targetAnchor = _openUp ? Alignment.topRight : Alignment.bottomRight;
    final offset = Offset(0, _openUp ? -_gap : _gap);

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
          targetAnchor: targetAnchor,
          followerAnchor: anchor,
          offset: offset,
          child: Align(
            alignment: anchor,
            child: AnimatedBuilder(
              animation: _ctrl,
              builder: (context, child) {
                final v = _ctrl.value.clamp(0.0, 1.0);
                final scale = 0.82 + Curves.easeOutBack.transform(v) * 0.18;
                return Opacity(
                  opacity: v,
                  child: Transform.scale(
                    scale: scale,
                    // Растём из триггера, а не из воздуха.
                    alignment: anchor,
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
          maxHeight: _menuMaxHeight,
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
        // Покадровое появление: пункты разбегаются от триггера, поэтому при
        // раскрытии вверх очередь идёт снизу вверх, а сдвиг — в другую сторону.
        final order = _openUp ? total - 1 - index : index;
        final start = total <= 1 ? 0.0 : (order / total) * 0.45;
        final local = ((_ctrl.value - start) / (1 - start)).clamp(0.0, 1.0);
        final eased = Curves.easeOut.transform(local);
        return Opacity(
          opacity: eased,
          child: Transform.translate(
            offset: Offset(0, (1 - eased) * (_openUp ? -10 : 10)),
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
