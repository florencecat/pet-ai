import 'package:flutter/material.dart';

class InlineLoading extends StatelessWidget {
  final bool isLoading;
  final Widget? child;
  final double minHeight;

  const InlineLoading({
    super.key,
    required this.isLoading,
    this.child,
    this.minHeight = 120,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        AnimatedOpacity(
          opacity: isLoading ? 0.3 : 1,
          duration: const Duration(milliseconds: 200),
          child: child,
        ),

        if (isLoading)
          Positioned.fill(
            child: Container(
              alignment: Alignment.center,
              child: const CircularProgressIndicator(),
            ),
          ),
      ],
    );
  }
}