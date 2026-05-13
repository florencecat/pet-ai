import 'package:flutter/material.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

class FloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  /// Color of the health-score status dot on the health tab.
  /// Pass null to hide the dot.
  final Color? healthScoreColor;

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
      child: Row(
        children: List.generate(4, (index) {
          return Expanded(
            child: NavItem(
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

class NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  /// Optional status dot shown at top-right of the icon.
  final Color? badgeColor;

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
    this.badgeColor,
  });

  @override
  Widget build(BuildContext context) {
    const activeColor = Color(0xFF3B807B);

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              AnimatedScale(
                scale: isActive ? 1.1 : 1.0,
                duration: const Duration(milliseconds: 200),
                child: Icon(
                  icon,
                  size: 28,
                  color: isActive ? activeColor : activeColor.withAlpha(128),
                ),
              ),
              if (badgeColor != null)
                Positioned(
                  right: -4,
                  top: -3,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: badgeColor,
                      border: Border.all(color: Colors.white, width: 1.5),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: isActive ? activeColor : activeColor.withAlpha(128),
            ),
          ),
        ],
      ),
    );
  }
}
