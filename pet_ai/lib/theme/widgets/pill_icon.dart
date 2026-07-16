import 'package:flutter/material.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:provider/provider.dart';

/// Curated iOS-style medication colour palette.
class PillColors {
  PillColors._();

  static const List<Color> palette = [
    Color(0xFFEF5350), // red
    Color(0xFFFF7043), // deep orange
    Color(0xFFFFA726), // orange
    Color(0xFFFFCA28), // amber
    Color(0xFF9CCC65), // light green
    Color(0xFF66BB6A), // green
    Color(0xFF26A69A), // teal
    Color(0xFF29B6F6), // light blue
    Color(0xFF42A5F5), // blue
    Color(0xFF5C6BC0), // indigo
    Color(0xFFAB47BC), // purple
    Color(0xFFEC407A), // pink
    Color(0xFF8D6E63), // brown
    Color(0xFF78909C), // blue grey
  ];

  /// Nearest stored colour for a swatch (so re-opening the picker re-selects it).
  static int toValue(Color c) => c.toARGB32();
}

/// Renders a pill's icon "iOS style": the kind-specific shape rendered in the
/// chosen colour inside a soft circular tinted container.
///
/// When [kind] is null a generic medication glyph is shown.
/// When [colorValue] is null the [fallback] colour (usually the app accent)
/// is used.
class PillIcon extends StatelessWidget {
  final PillKind? kind;
  final int? colorValue;
  final Color fallback;
  final double size;

  const PillIcon({
    super.key,
    required this.kind,
    required this.colorValue,
    required this.fallback,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorValue != null ? Color(colorValue!) : fallback;
    final icon = kind != null && kind!.id.isNotEmpty
        ? kind!.icon
        : Icons.medication_outlined;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(70), width: 1.2),
      ),
      child: Icon(icon, color: color, size: size * 0.48),
    );
  }
}

/// Result of [showPillIconPicker].
class PillIconSelection {
  final PillKind kind;
  final int color;
  const PillIconSelection({required this.kind, required this.color});
}

/// iOS-style shape + colour picker. Returns null if dismissed.
Future<PillIconSelection?> showPillIconPicker(
  BuildContext context, {
  PillKind? initialKind,
  int? initialColor,
  required Color accent,
}) {
  return showModalBottomSheet<PillIconSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _PillIconPickerSheet(
      initialKind: initialKind,
      initialColor: initialColor,
      accent: accent,
    ),
  );
}

class _PillIconPickerSheet extends StatefulWidget {
  final PillKind? initialKind;
  final int? initialColor;
  final Color accent;

  const _PillIconPickerSheet({
    required this.initialKind,
    required this.initialColor,
    required this.accent,
  });

  @override
  State<_PillIconPickerSheet> createState() => _PillIconPickerSheetState();
}

class _PillIconPickerSheetState extends State<_PillIconPickerSheet> {
  late PillKind _kind;
  late int _color;

  @override
  void initState() {
    super.initState();
    _kind = (widget.initialKind != null && widget.initialKind!.id.isNotEmpty)
        ? widget.initialKind!
        : PillKind.pill;
    _color =
        widget.initialColor ?? PillColors.toValue(PillColors.palette.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) {
        return Container(
          decoration: const BoxDecoration(
            color: ThemeColors.background,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            children: [
              // Grabber
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 6),
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: context.watch<AppearanceController>().secondaryColor.withAlpha(120),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              // ── Live preview ──────────────────────────────────────────────
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: PillIcon(
                  kind: _kind,
                  colorValue: _color,
                  fallback: widget.accent,
                  size: 88,
                ),
              ),
              Text(_kind.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),

              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                  children: [
                    // ── Colour row ────────────────────────────────────────
                    Text('Цвет', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: PillColors.palette.map((c) {
                        final value = PillColors.toValue(c);
                        final selected = value == _color;
                        return GestureDetector(
                          onTap: () => setState(() => _color = value),
                          child: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: c,
                              border: Border.all(
                                color: selected
                                    ? Colors.white
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: selected
                                  ? [
                                      BoxShadow(
                                        color: c.withAlpha(140),
                                        blurRadius: 8,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: selected
                                ? const Icon(
                                    Icons.check,
                                    color: Colors.white,
                                    size: 18,
                                  )
                                : null,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 20),

                    // ── Shape grid ────────────────────────────────────────
                    Text('Форма', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: PillKind.all.map((k) {
                        final selected = k.id == _kind.id;
                        final c = Color(_color);
                        return GestureDetector(
                          onTap: () => setState(() => _kind = k),
                          child: Container(
                            decoration: BoxDecoration(
                              color: selected
                                  ? c.withAlpha(28)
                                  : ThemeColors.white,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: selected
                                    ? c
                                    : context.watch<AppearanceController>().secondaryColor.withAlpha(60),
                                width: selected ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  k.icon,
                                  size: 24,
                                  color: selected ? c : context.watch<AppearanceController>().secondaryColor,
                                ),
                                const SizedBox(height: 6),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 4,
                                  ),
                                  child: Text(
                                    k.name,
                                    style: theme.textTheme.bodySmall!.copyWith(

                                      color: selected
                                          ? context
                                                .watch<AppearanceController>()
                                                .secondaryColor
                                          : context.watch<AppearanceController>().secondaryColor,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),

              // ── Done button ───────────────────────────────────────────────
              Padding(
                padding: EdgeInsets.fromLTRB(
                  20,
                  8,
                  20,
                  12 + MediaQuery.of(context).padding.bottom,
                ),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      context,
                    ).pop(PillIconSelection(kind: _kind, color: _color)),
                    style: FilledButton.styleFrom(
                      backgroundColor: widget.accent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Готово'),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
