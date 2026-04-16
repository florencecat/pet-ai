import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// A stepper widget that shows 5 bars of increasing height.
/// Bars 1-2 are red, bar 3 is yellow, bars 4-5 are green.
/// +/- buttons on each side change the score.
class AppetiteStepper extends StatelessWidget {
  final int value; // 1–5
  final ValueChanged<int> onChanged;

  const AppetiteStepper({
    super.key,
    required this.value,
    required this.onChanged,
  });

  static const _barCount = 5;
  static const _maxBarHeight = 40.0;
  static const _minBarHeight = 10.0;

  Color _barColor(int barIndex) {
    // barIndex is 1-based
    if (barIndex <= 2) return const Color(0xFFEF5350); // red
    if (barIndex == 3) return const Color(0xFFFFC107); // yellow
    return const Color(0xFF66BB6A); // green
  }

  void _decrement() {
    HapticFeedback.selectionClick();
    if (value > 1) onChanged(value - 1);
  }

  void _increment() {
    HapticFeedback.selectionClick();
    if (value < 5) onChanged(value + 1);
  }

  @override
  Widget build(BuildContext context) {
    final activeColor = _barColor(value);
    final dimColor = activeColor.withAlpha(50);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ── Minus button ────────────────────────────────────────────────────
        _StepButton(
          icon: Icons.remove,
          color: value > 1 ? activeColor : dimColor,
          onTap: value > 1 ? _decrement : null,
        ),

        const SizedBox(width: 16),

        // ── Bars ─────────────────────────────────────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(_barCount, (i) {
            final barIndex = i + 1; // 1-based
            final t = i / (_barCount - 1); // 0.0 … 1.0
            final height =
                _minBarHeight + (_maxBarHeight - _minBarHeight) * t;
            final isActive = barIndex <= value;

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                width: 14,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(4),
                  color: isActive ? _barColor(barIndex) : dimColor,
                ),
              ),
            );
          }),
        ),

        const SizedBox(width: 16),

        // ── Plus button ──────────────────────────────────────────────────────
        _StepButton(
          icon: Icons.add,
          color: value < 5 ? activeColor : dimColor,
          onTap: value < 5 ? _increment : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _StepButton({
    required this.icon,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withAlpha(30),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Icon(icon, size: 18, color: color),
      ),
    );
  }
}
