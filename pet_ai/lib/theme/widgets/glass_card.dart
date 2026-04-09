import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPlate extends StatelessWidget {
  final Widget child;
  final Color color;

  const GlassPlate({super.key, required this.child, this.color = Colors.white});

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(28);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 0),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha(30),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),

          ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: color.withAlpha(128),
                  border: Border.all(
                    color: color.withAlpha(153),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 28,
                        decoration: BoxDecoration(
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(28),
                          ),
                          gradient: LinearGradient(
                            colors: [
                              color.withAlpha(180),
                              color.withAlpha(0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    Padding(padding: const EdgeInsets.all(8), child: child),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class GlassCard extends StatelessWidget {
  final VoidCallback? callback;
  final Widget child;
  final Color color;

  const GlassCard({
    super.key,
    required this.callback,
    required this.child,
    this.color = Colors.white,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      color: color,
      child: InkWell(onTap: callback, child: child),
    );
  }
}
