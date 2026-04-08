import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPlate extends StatelessWidget {
  final Widget child;
  final double? width;

  const GlassPlate({
    super.key,
    required this.child,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final borderRadius = BorderRadius.circular(28);

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          // тень (не обрезается!)
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),

          // glass слой
          ClipRRect(
            borderRadius: borderRadius,
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: borderRadius,
                  color: Colors.white.withOpacity(0.5),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.6),
                    width: 1.2,
                  ),
                ),
                child: Stack(
                  children: [
                    // верхний блик
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
                              Colors.white.withOpacity(0.7),
                              Colors.white.withOpacity(0.0),
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),

                    // ВАЖНО: отступы внутри
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: child,
                    ),
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
  final double width;

  const GlassCard({
    super.key,
    required this.callback,
    required this.child,
    this.width = 80,
  });

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      width: width,
      child: InkWell(onTap: callback, child: child),
    );
  }
}
