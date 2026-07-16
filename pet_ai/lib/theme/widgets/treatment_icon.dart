import 'package:flutter/material.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pill_icon.dart' show PillColors;
import 'package:provider/provider.dart';

/// Иконка обработки/прививки: глиф типа ([TreatmentKind.icon]) в выбранном
/// цвете внутри мягкого круглого контейнера. Аналог [PillIcon] для препаратов.
class TreatmentIcon extends StatelessWidget {
  final TreatmentKind kind;
  final int? colorValue;
  final Color fallback;
  final double size;

  const TreatmentIcon({
    super.key,
    required this.kind,
    required this.colorValue,
    required this.fallback,
    this.size = 40,
  });

  @override
  Widget build(BuildContext context) {
    final color = colorValue != null ? Color(colorValue!) : fallback;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color.withAlpha(28),
        border: Border.all(color: color.withAlpha(70), width: 1.2),
      ),
      child: Icon(kind.icon, color: color, size: size * 0.48),
    );
  }
}

/// Результат [showTreatmentIconPicker].
class TreatmentIconSelection {
  final TreatmentKind kind;
  final int color;
  const TreatmentIconSelection({required this.kind, required this.color});
}

/// Пикер вида (тип обработки) + цвета. Возвращает null при отмене.
Future<TreatmentIconSelection?> showTreatmentIconPicker(
  BuildContext context, {
  required TreatmentKind initialKind,
  int? initialColor,
  required Color accent,
}) {
  return showModalBottomSheet<TreatmentIconSelection>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TreatmentIconPickerSheet(
      initialKind: initialKind,
      initialColor: initialColor,
      accent: accent,
    ),
  );
}

class _TreatmentIconPickerSheet extends StatefulWidget {
  final TreatmentKind initialKind;
  final int? initialColor;
  final Color accent;

  const _TreatmentIconPickerSheet({
    required this.initialKind,
    required this.initialColor,
    required this.accent,
  });

  @override
  State<_TreatmentIconPickerSheet> createState() =>
      _TreatmentIconPickerSheetState();
}

class _TreatmentIconPickerSheetState extends State<_TreatmentIconPickerSheet> {
  late TreatmentKind _kind;
  late int _color;

  @override
  void initState() {
    super.initState();
    _kind = widget.initialKind;
    _color =
        widget.initialColor ?? PillColors.toValue(PillColors.palette.first);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
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
                child: SoftRoundedIcon(
                  icon: _kind.icon,
                  color: Color(_color),
                  size: 48,
                ),
              ),
              Text(_kind.shortLabel, style: theme.textTheme.titleMedium),
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

                    // ── Kind grid ─────────────────────────────────────────
                    Text('Вид', style: theme.textTheme.bodySmall),
                    const SizedBox(height: 10),
                    GridView.count(
                      crossAxisCount: 4,
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      childAspectRatio: 0.82,
                      children: TreatmentKind.values.map((k) {
                        final selected = k == _kind;
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
                                    k.shortLabel,
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
                    ).pop(TreatmentIconSelection(kind: _kind, color: _color)),
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
