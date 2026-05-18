import 'package:flutter/material.dart';

/// A shimmer-animated skeleton placeholder.
///
/// Renders a rounded rectangle that animates a bright highlight sweeping
/// left-to-right to signal a loading state. Drop this anywhere you'd
/// normally show a real piece of content while data is being fetched.
class SkeletonBox extends StatefulWidget {
  final double? width;
  final double? height;
  final double borderRadius;

  const SkeletonBox({
    super.key,
    this.width,
    this.height = 14,
    this.borderRadius = 6,
  });

  @override
  State<SkeletonBox> createState() => _SkeletonBoxState();
}

class _SkeletonBoxState extends State<SkeletonBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _shimmer;

  static const _base = Color(0xFFE4E4E4);
  static const _highlight = Color(0xFFF8F8F8);

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();
    _shimmer = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _shimmer,
      builder: (_, _) {
        final v = _shimmer.value;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.borderRadius),
            gradient: LinearGradient(
              begin: Alignment.centerLeft,
              end: Alignment.centerRight,
              stops: [
                (v - 0.5).clamp(0.0, 1.0),
                v.clamp(0.0, 1.0),
                (v + 0.5).clamp(0.0, 1.0),
              ],
              colors: const [_base, _highlight, _base],
            ),
          ),
        );
      },
    );
  }
}

/// Convenience shorthand for a single line of skeleton text.
///
/// Use [height] to match the line-height of the real text style you're
/// replacing (e.g. 13 for bodySmall, 18 for titleMedium, 22 for titleLarge).
class SkeletonText extends StatelessWidget {
  final double width;
  final double height;

  const SkeletonText({super.key, required this.width, this.height = 14});

  @override
  Widget build(BuildContext context) =>
      SkeletonBox(width: width, height: height, borderRadius: 6);
}
