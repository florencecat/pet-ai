import 'package:flutter/material.dart';

class ChartPlaceholder extends StatelessWidget {
  final String message;

  const ChartPlaceholder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 250,
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
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                inherit: true,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}