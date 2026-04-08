import 'dart:ui';
import 'package:flutter/material.dart';

class GlassPlate extends StatelessWidget {
  final Widget child;
  final double width;
  const GlassPlate({super.key, required this.child, this.width = 80});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: width,
      margin: const EdgeInsets.symmetric(horizontal: 8),
      child: Stack(
        children: [
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(28),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 40,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
            ),
          ),

          Positioned.fill(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(28),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 40, sigmaY: 40),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),

                    color: Colors.white.withAlpha(128),

                    border: Border.all(
                      color: Colors.white.withAlpha(128),
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
                                Colors.white.withAlpha(180),
                                Colors.white.withAlpha(0),
                              ],
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                            ),
                          ),
                        ),
                      ),

                      child,
                    ],
                  ),
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
