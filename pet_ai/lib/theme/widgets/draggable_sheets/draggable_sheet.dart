import 'package:flutter/material.dart';

class DragHandle extends StatelessWidget {
  const DragHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 12, bottom: 4),
        decoration: BoxDecoration(
          color: Colors.grey.shade400,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

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

  // Sizing as a fraction of screen height. `initialSize` sets the resting
  // height the sheet opens at; `maxSize` caps how tall it may grow. `minSize`
  // is kept for API compatibility only (drag-to-dismiss handles shrinking).
  //
  // `initialSize == null` — высоты покоя нет, sheet подгоняется под контент (в
  // пределах `maxSize`). Тогда смена контента меняет высоту sheet, и решать,
  // анимировать ли это, — задача body (например, обернуть его в AnimatedSize).
  final double? initialSize;
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
    final screenHeight = MediaQuery.sizeOf(context).height;

    // Fixed resting height: open at `initialSize`, never grow past `maxSize`.
    // Without this the sheet's height tracks its content, so a long history
    // list pushes the content past the screen and the sheet snaps to full
    // height instead of staying at its intended size. With a stable minHeight
    // the overflowing body scrolls *inside* the sheet instead.
    //
    // `initialSize == null` — это поведение осознанно отключается: minHeight
    // нулевой, и sheet тянется по контенту вплоть до `maxSize` (дальше контент
    // всё так же скроллится внутри).
    final initial = initialSize;
    final minHeight = initial == null
        ? 0.0
        : (screenHeight * initial).clamp(0.0, screenHeight * maxSize);

    return ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: minHeight,
        maxHeight: screenHeight * maxSize,
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ── Handle ──────────────────────────────────────────────────────
            DragHandle(),
            // ── Header ──────────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: _buildHeader(primaryColor, titleStyle),
            ),
            // ── Body ──────────────────────────────────────────────────────
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

          if (title != null) Text(title!, style: titleStyle),

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
