import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/remindable.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/animated_option_picker.dart';

/// Переиспользуемый контрол «Напомнить за N (дн./час./мин.)».
///
/// Используется в листах события, препарата и мед. мероприятия. Значение и
/// единицу хранит вызывающий; при смене единицы значение сбрасывается в 0
/// (как в листе события — «7 дней» ≠ «7 минут»).
class RemindBeforePicker extends StatelessWidget {
  final int value;
  final RemindBeforeVariant variant;
  final ValueChanged<int> onValueChanged;
  final ValueChanged<RemindBeforeVariant> onVariantChanged;

  /// Доступные единицы (по умолчанию все). Например, для all-day — только дни.
  final List<RemindBeforeVariant> variants;

  /// Заголовок слева.
  final String label;

  /// Верхняя граница значения.
  final int maxValue;

  const RemindBeforePicker({
    super.key,
    required this.value,
    required this.variant,
    required this.onValueChanged,
    required this.onVariantChanged,
    this.variants = RemindBeforeVariant.values,
    this.label = 'Напомнить за',
    this.maxValue = 120,
  });

  // Минуты шагаем по 5, остальное — по 1 (как в листе события).
  int get _step => variant == RemindBeforeVariant.minutes ? 5 : 1;

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final theme = Theme.of(context);
    final canPickVariant = variants.length > 1;

    return FittedBox(child:  Row(
      children: [
        Text(label, style: theme.textTheme.bodyLarge),
        const SizedBox(width: 8),
        IconButton(
          icon: const Icon(Icons.remove_circle_outline),
          color: accent,
          onPressed: value > 0
              ? () => onValueChanged((value - _step).clamp(0, maxValue))
              : null,
        ),
        SizedBox(
          width: 28,
          child: Text(
            '$value',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge!
                .copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.add_circle_outline),
          color: accent,
          onPressed: value < maxValue
              ? () => onValueChanged((value + _step).clamp(0, maxValue))
              : null,
        ),
        const SizedBox(width: 8),
        AnimatedOptionPicker<RemindBeforeVariant>(
          value: variant,
          enabled: canPickVariant,
          showChevron: canPickVariant,
          accentColor: accent,
          options: variants
              .map((v) => PickerOption(value: v, label: v.label))
              .toList(),
          onChanged: (v) {
            if (v != variant) onValueChanged(0);
            onVariantChanged(v);
          },
          child: Text(
            variant.declension(value),
            style: theme.textTheme.bodyLarge,
          ),
        ),
      ],
    ));
  }
}
