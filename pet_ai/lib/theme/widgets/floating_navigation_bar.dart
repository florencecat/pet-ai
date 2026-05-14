import 'package:flutter/material.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

class FloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  /// Color of the health-score status dot on the health tab.
  /// Pass null to hide the dot.
  final Color? healthScoreColor;

  /// The visual height of the navbar widget itself (GlassPlate content +
  /// the external bottom padding added in main.dart).
  /// Used by [MainPage] to push inner-Scaffold FABs above the bar.
  ///
  /// Breakdown: icon(22) + gap(3) + label(≈13) = 38
  ///   + AnimatedContainer vertical padding(16) = 54
  ///   + GlassPlate padding(12) = 66 (GlassPlate height)
  ///   + external Padding bottom(16) = 82
  static const double bottomInset = 82.0;

  const FloatingNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.healthScoreColor,
  });

  static const _icons = [
    Icons.pets,
    Icons.health_and_safety_outlined,
    Icons.chat_bubble_outline,
    Icons.calendar_month,
  ];

  static const _labels = ['Главная', 'Здоровье', 'Чат', 'Календарь'];

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 6,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(4, (index) {
          return Expanded(
            child: _NavItem(
              icon: _icons[index],
              label: _labels[index],
              isActive: currentIndex == index,
              badgeColor: index == 1 ? healthScoreColor : null,
              onTap: () => onTap(index),
            ),
          );
        }),
      ),
    );
  }
}

// ── Nav item ─────────────────────────────────────────────────────────────────

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;
  final Color? badgeColor;

  static const _activeContent = Colors.white;
  static const _inactiveContent = Color(0xFFAAAAAA);

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isActive ? context.watch<AppearanceController>().secondaryColor : Colors.transparent,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Stack(
                  clipBehavior: Clip.none,
                  alignment: Alignment.center,
                  children: [
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        icon,
                        key: ValueKey(isActive),
                        size: 22,
                        color: isActive ? _activeContent : _inactiveContent,
                      ),
                    ),
                    if (badgeColor != null)
                      Positioned(
                        right: -5,
                        top: -3,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: badgeColor,
                            border: Border.all(
                              color: isActive ? context.watch<AppearanceController>().secondaryColor : Colors.white,
                              width: 1.5,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                AnimatedDefaultTextStyle(
                  duration: const Duration(milliseconds: 220),
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight:
                        isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? _activeContent : _inactiveContent,
                  ),
                  child: Text(label),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
