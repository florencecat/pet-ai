import 'package:flutter/material.dart';
import 'package:pet_satellite/theme/app_colors.dart';

/// Выпадающий список автодополнения. Единый стиль для всех полей с подсказками
/// (город в профиле, корм в дневнике питания и т.д.).
class SuggestionList extends StatelessWidget {
  final List<String> suggestions;
  final ValueChanged<String> onSelected;
  final IconData icon;
  final Color accent;

  const SuggestionList({
    super.key,
    required this.suggestions,
    required this.onSelected,
    required this.accent,
    this.icon = Icons.location_on_outlined,
  });

  @override
  Widget build(BuildContext context) {
    if (suggestions.isEmpty) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        children: suggestions.asMap().entries.map((entry) {
          final i = entry.key;
          final value = entry.value;
          final isLast = i == suggestions.length - 1;
          return Column(
            children: [
              InkWell(
                onTap: () => onSelected(value),
                borderRadius: BorderRadius.circular(14),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  child: Row(
                    children: [
                      Icon(icon, size: 16, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (!isLast)
                Divider(
                  height: 1,
                  indent: 42,
                  color: ThemeColors.border.withAlpha(50),
                ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
