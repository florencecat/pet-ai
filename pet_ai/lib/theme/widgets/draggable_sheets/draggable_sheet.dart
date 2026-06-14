import 'package:flutter/material.dart';

// DraggableSheet is intentionally a plain StatelessWidget — it no longer wraps
// a DraggableScrollableSheet.
//
// Root cause of the removed code:
//   DraggableScrollableSheet uses a LayoutBuilder internally. LayoutBuilder
//   builds its child during the *layout* phase (not the build phase). If the
//   containing showModalBottomSheet route is dismissed between a setState() and
//   the next layout pass, Flutter deactivates the element tree while a pending
//   layout is still queued. InheritedElements inside the subtree are deactivated
//   before their dependents are removed, which fires:
//     '_dependents.isEmpty': is not true
//
//   showModalBottomSheet already provides drag-to-dismiss, so
//   DraggableScrollableSheet is not needed for that behaviour. Keyboard
//   avoidance is handled via MediaQuery.viewInsetsOf.

class DraggableSheet extends StatelessWidget {
  final Widget body;

  final String? title;
  final bool centerTitle;

  final List<Widget>? actions;
  final VoidCallback? onBack;

  // Kept for API compatibility only — no longer used for sizing.
  final double initialSize;
  final double minSize;
  final double maxSize;

  const DraggableSheet({
    super.key,
    required this.body,
    this.title,
    this.actions,
    this.onBack,
    this.centerTitle = true,
    this.initialSize = 0.6,
    this.minSize = 0.3,
    this.maxSize = 0.95,
  });

  @override
  Widget build(BuildContext context) {
    // All InheritedWidget lookups happen on this normal StatelessElement
    // context, which is deactivated in the correct (bottom-up) order.
    final theme = Theme.of(context);
    final surfaceColor = theme.colorScheme.surface;
    final primaryColor = theme.colorScheme.primary;
    final titleStyle = theme.textTheme.titleMedium;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Drag handle ───────────────────────────────────────────────
          // Kept OUTSIDE the scroll view: showModalBottomSheet's enableDrag
          // detects vertical drags on the sheet surface, but a wrapping
          // SingleChildScrollView consumes them — so a drag on the handle
          // or header wouldn't dismiss the sheet (this was the iOS bug
          // where the sheet body scrolled bouncily instead of stretching
          // the sheet down).
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(top: 12, bottom: 4),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // ── Header ────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: _buildHeader(primaryColor, titleStyle),
          ),

          // ── Body ──────────────────────────────────────────────────────
          // Flexible so the column hugs its content when small (sheet keeps
          // wrapping to body height) but caps at the available height when
          // the body overflows (then the body scrolls).
          Flexible(
            fit: FlexFit.loose,
            child: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 8, 16, keyboardInset + 24),
                child: body,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color primaryColor, TextStyle? titleStyle) {
    final hasBack = onBack != null;
    final hasActions = actions != null && actions!.isNotEmpty;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (hasBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: primaryColor,
              onPressed: onBack,
            )
          else if (centerTitle && hasActions)
            const SizedBox(width: kMinInteractiveDimension),

          if (centerTitle) const Spacer(),

          if (title != null)
            Text(
              title!,
              style: titleStyle,
            ),

          if (centerTitle) const Spacer(),

          if (hasActions)
            ...actions!
          else if (centerTitle && hasBack)
            const SizedBox(width: kMinInteractiveDimension),
        ],
      ),
    );
  }
}
