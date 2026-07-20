import 'package:flutter/material.dart';

class ChartPlaceholder extends StatelessWidget {
  final Widget label;

  const ChartPlaceholder({super.key, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 120,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 8),
            label,
          ],
        ),
      ),
    );
  }
}