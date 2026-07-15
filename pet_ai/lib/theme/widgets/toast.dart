import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:provider/provider.dart';

/// Короткое всплывающее сообщение поверх всего (включая модальные листы).
///
/// В отличие от `ScaffoldMessenger`/SnackBar, вставляется в общий `Overlay`
/// поверх текущего маршрута, поэтому видно и над `showModalBottomSheet`
/// (у которого нет своего Scaffold, и обычный SnackBar уезжает под лист).
void showAppToast(BuildContext context, String message) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (ctx) {
      final media = MediaQuery.of(ctx);
      return Positioned(
        left: 24,
        right: 24,
        bottom: media.viewInsets.bottom + media.padding.bottom + 32,
        child: IgnorePointer(
          child: _ToastCard(
            message: message,
            onFinished: () {
              if (entry.mounted) entry.remove();
            },
          ),
        ),
      );
    },
  );
  overlay.insert(entry);
}

class _ToastCard extends StatefulWidget {
  final String message;
  final VoidCallback onFinished;

  const _ToastCard({required this.message, required this.onFinished});

  @override
  State<_ToastCard> createState() => _ToastCardState();
}

class _ToastCardState extends State<_ToastCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _run();
  }

  Future<void> _run() async {
    await _c.forward();
    await Future.delayed(const Duration(milliseconds: 1900));
    if (!mounted) return;
    await _c.reverse();
    widget.onFinished();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _c,
      child: Center(
        child: Material(
          color: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: context.watch<AppearanceController>().secondaryColor,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Text(
              widget.message,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,

                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
