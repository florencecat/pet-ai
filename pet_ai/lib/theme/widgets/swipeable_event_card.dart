import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

/// Обёртка над [GlassEventCard], добавляющая свайп влево для
/// отображения кнопок «Редактировать» и «Удалить».
class SwipeableEventCard extends StatefulWidget {
  final PetEvent event;

  /// Вызывается при нажатии на карточку (открывает EventSheet)
  final VoidCallback? onTap;

  /// Вызывается при нажатии «Редактировать»
  final VoidCallback? onEdit;

  /// Вызывается при нажатии «Удалить»
  final VoidCallback? onDelete;

  /// Параметры для режима «все питомцы»
  final Color? petColor;
  final String? petName;

  /// Дата для отметки выполнения (completionDate)
  final DateTime? selectedDate;

  /// Колбэк отметки выполнения (если задан — показывает чекбокс)
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
  static const _actionWidth = 140.0; // total width of edit+delete buttons

  late final AnimationController _ctrl;
  late final Animation<double> _offset;

  bool _revealed = false;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _offset = Tween<double>(begin: 0, end: -_actionWidth)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _toggleReveal() {
    HapticFeedback.selectionClick();
    if (_revealed) {
      _ctrl.reverse();
    } else {
      _ctrl.forward();
    }
    _revealed = !_revealed;
  }

  void _close() {
    if (_revealed) {
      _ctrl.reverse();
      _revealed = false;
    }
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    // Positive dx = swipe right; negative = swipe left
    if (details.primaryDelta! < -4 && !_revealed) {
      _toggleReveal();
    } else if (details.primaryDelta! > 4 && _revealed) {
      _close();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragUpdate: _onHorizontalDragUpdate,
      onTap: _revealed ? _close : null,
      behavior: HitTestBehavior.translucent,
      child: Stack(
        alignment: Alignment.centerRight,
        children: [
          // ── Action buttons (revealed on swipe left) ─────────────────
          SizedBox(
            width: _actionWidth,
            child: Row(
              children: [
                // Edit
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _close();
                      widget.onEdit?.call();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: ThemeColors.secondary.withAlpha(200),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.edit_outlined,
                              color: Colors.white, size: 20),
                          SizedBox(height: 4),
                          Text(
                            'Изм.',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                // Delete
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      _close();
                      widget.onDelete?.call();
                    },
                    child: Container(
                      margin: const EdgeInsets.symmetric(
                          vertical: 8, horizontal: 4),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(20),
                        color: ThemeColors.danger.withAlpha(200),
                      ),
                      child: const Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.delete_outline,
                              color: Colors.white, size: 20),
                          SizedBox(height: 4),
                          Text(
                            'Удалить',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // ── Card (slides left to reveal buttons) ─────────────────────
          AnimatedBuilder(
            animation: _offset,
            builder: (_, child) => Transform.translate(
              offset: Offset(_offset.value, 0),
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
