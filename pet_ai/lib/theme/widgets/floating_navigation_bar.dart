import 'package:flutter/material.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';

class FloatingNavigationBar extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;

  const FloatingNavigationBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
  });

  static const _icons = [
    Icons.pets,
    Icons.chat_bubble_outline,
    Icons.calendar_month,
    Icons.settings,
  ];

  static const _labels = ["Главная", "Чат", "События", "Настройки"];

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

  const NavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
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
          AnimatedScale(
            scale: isActive ? 1.1 : 1.0,
            duration: const Duration(milliseconds: 200),
            child: Icon(
              icon,
              size: 28,
              color: isActive ? activeColor : activeColor.withAlpha(128),
            ),
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

