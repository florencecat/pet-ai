import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

/// Обёртка над [GlassEventCard], добавляющая свайп влево для
/// отображения круглых кнопок «Редактировать» и «Удалить».
class SwipeableEventCard extends StatefulWidget {
  final PetEvent event;
  final VoidCallback? onTap;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final Color? petColor;
  final String? petName;
  final DateTime? selectedDate;
  final ValueChanged<bool>? onCompletedChanged;
  final VoidCallback? trailingCallback;

  const SwipeableEventCard({
    super.key,
    required this.event,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.petColor,
    this.petName,
    this.selectedDate,
    this.onCompletedChanged,
    this.trailingCallback,
  });

  @override
  State<SwipeableEventCard> createState() => _SwipeableEventCardState();
}

class _SwipeableEventCardState extends State<SwipeableEventCard>
    with SingleTickerProviderStateMixin {
  /// Width revealed by the slide = 2 × button diameter + gap + right padding
  static const double _btnSize = 52.0;
  static const double _btnGap = 10.0;
  static const double _sidePad = 12.0;
  static const double _actionWidth = _sidePad + _btnSize + _btnGap + _btnSize + _sidePad;

  late final AnimationController _ctrl;
  late final Animation<double> _slide;

  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    );
    _slide = Tween<double>(begin: 0, end: -_actionWidth).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeOutCubic),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _open() {
    HapticFeedback.selectionClick();
    _ctrl.forward();
    _revealed = true;
  }

  void _close() {
    _ctrl.reverse();
    _revealed = false;
  }

  void _onHorizontalDrag(DragUpdateDetails d) {
    final dx = d.primaryDelta ?? 0;
    if (dx < -6 && !_revealed) _open();
    if (dx > 6 && _revealed) _close();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDrag,
      onTap: _revealed ? _close : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
          children: [
            // ── 2. Action buttons (always at the right edge) ─────────────
            Positioned(
              right: _sidePad,
              top: 0,
              bottom: 0,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _ActionButton(
                    icon: Icons.edit_outlined,
                    color: ThemeColors.secondary,
                    label: 'Изм.',
                    onTap: () {
                      _close();
                      widget.onEdit?.call();
                    },
                  ),
                  const SizedBox(width: _btnGap),
                  _ActionButton(
                    icon: Icons.delete_outline,
                    color: ThemeColors.dangerZone,
                    label: 'Удалить',
                    onTap: () {
                      _close();
                      widget.onDelete?.call();
                    },
                  ),
                ],
              ),
            ),

            // ── 3. Card slides left to reveal buttons ─────────────────────
            AnimatedBuilder(
              animation: _slide,
              builder: (_, child) => Transform.translate(
                offset: Offset(_slide.value, 0),
                child: child,
              ),
              child: GlassEventCard(
                event: widget.event,
                callback: widget.onTap,
                trailingIcon: Icons.chevron_right,
                trailingCallback: widget.trailingCallback,
                selectedDate: widget.selectedDate,
                onCompletedChanged: widget.onCompletedChanged,
                petColor: widget.petColor,
                petName: widget.petName,
              ),
            ),
          ],
        ),
    );
  }
}

// ─── Круглая кнопка действия ─────────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: _SwipeableEventCardState._btnSize,
            height: _SwipeableEventCardState._btnSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(
                  color: color.withAlpha(80),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 22),
          ),
          const SizedBox(height: 5),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
