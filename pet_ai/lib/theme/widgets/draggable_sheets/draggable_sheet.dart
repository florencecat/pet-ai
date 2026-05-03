import 'package:flutter/material.dart';

class DraggableSheet extends StatefulWidget {
  final Widget body;

  final String? title;
  final bool centerTitle;

  final List<Widget>? actions;
  final VoidCallback? onBack;

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
  State<DraggableSheet> createState() => _DraggableSheetState();
}

class _DraggableSheetState extends State<DraggableSheet>
    with WidgetsBindingObserver {
  late DraggableScrollableController _controller;

  @override
  void initState() {
    super.initState();
    _controller = DraggableScrollableController();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.dispose();
    super.dispose();
  }

  void expand() {
    if (_controller.isAttached) {
      _controller.animateTo(
        widget.maxSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  void collapse() {
    if (_controller.isAttached) {
      _controller.animateTo(
        widget.initialSize,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  void didChangeMetrics() {
    final bottomInset = WidgetsBinding
        .instance
        .platformDispatcher
        .views
        .first
        .viewInsets
        .bottom;

    if (bottomInset > 0) {
      expand();
    }
    else {
      collapse();
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      controller: _controller,
      initialChildSize: widget.initialSize,
      minChildSize: widget.minSize,
      maxChildSize: widget.maxSize,
      snap: true,
      snapSizes: [widget.initialSize, widget.maxSize],
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottomInset),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              _buildHeader(context),

              const SizedBox(height: 12),

              widget.body,
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    final hasBack = widget.onBack != null;
    final hasActions = widget.actions != null && widget.actions!.isNotEmpty;

    return SizedBox(
      height: 48,
      child: Row(
        children: [
          if (hasBack)
            IconButton(
              icon: const Icon(Icons.arrow_back),
              color: Theme.of(context).colorScheme.primary,
              onPressed: widget.onBack,
            )
          else if (widget.centerTitle && hasActions)
            const SizedBox(width: kMinInteractiveDimension),

          if (widget.centerTitle) const Spacer(),

          if (widget.title != null)
            Text(
              widget.title!,
              style: Theme.of(context).textTheme.titleMedium,
            ),

          if (widget.centerTitle) const Spacer(),

          if (hasActions)
            ...widget.actions!
          else if (widget.centerTitle && hasBack)
            const SizedBox(width: kMinInteractiveDimension),
        ],
      ),
    );
  }
}