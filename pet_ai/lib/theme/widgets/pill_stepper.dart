import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:provider/provider.dart';

class PillStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  /// Допустимый диапазон значения (включительно). По умолчанию — широкий.
  final double min;
  final double max;

  /// Подпись единицы измерения справа от значения (напр. «кг», «мин»).
  final String unit;

  /// Шаг изменения по кнопкам «+»/«−».
  final double step;

  /// Сколько знаков после запятой показывать/хранить (0 — целые значения).
  final int decimals;

  const PillStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 999,
    this.unit = 'кг',
    this.step = 1.0,
    this.decimals = 1,
  });

  @override
  State<PillStepper> createState() => _PillStepperState();
}

class _PillStepperState extends State<PillStepper> {
  late TextEditingController controller;
  late double weight;

  double get step => widget.step;
  int get _decimals => widget.decimals;

  String _format(double v) => v.toStringAsFixed(_decimals);

  @override
  void initState() {
    super.initState();

    weight = widget.value;

    controller = TextEditingController(text: _format(weight));
  }

  void updateWeight(double newWeight) {
    // Округляем до нужного числа знаков после запятой (0/1/2 знака).
    final rounder = [1, 10, 100][_decimals.clamp(0, 2)];
    newWeight = (newWeight * rounder).round() / rounder;
    newWeight = newWeight.clamp(widget.min, widget.max).toDouble();

    setState(() {
      weight = newWeight;
      controller.text = _format(weight);
    });

    widget.onChanged(weight);
  }

  void increase() async {
    await HapticFeedback.selectionClick();
    updateWeight(weight + step);
  }

  void decrease() async {
    await HapticFeedback.selectionClick();
    updateWeight(weight - step);
  }

  void onTextChanged(String value) {
    value = value.replaceAll(',', '.');
    final parsed = double.tryParse(value);
    if (parsed == null) return;

    if (parsed > widget.max) {
      // Больше максимума ввести нельзя — фиксируем на границе (со сбросом текста).
      updateWeight(widget.max);
      return;
    }
    weight = parsed.clamp(widget.min, widget.max).toDouble();
    widget.onChanged(weight);
  }

  /// Ширина поля под текущий текст: измеряем строку и добавляем запас на курсор,
  /// ограничивая снизу (компактно для 1–2 цифр) и сверху (для 3 цифр с дробью).
  double _fieldWidth(String text, TextStyle style) {
    final tp = TextPainter(
      text: TextSpan(text: text.isEmpty ? '0.0' : text, style: style),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = (tp.width + 16).clamp(52.0, 120.0).toDouble();
    tp.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _circleButton(Icons.remove, decrease),

          const SizedBox(width: 12),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Поле шириной по содержимому: короткое значение — компактно (и «кг»
              // рядом), трёхзначное — поле плавно расширяется и не обрезается.
              AnimatedSize(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                child: ListenableBuilder(
                  listenable: controller,
                  builder: (context, _) {
                    final valueStyle = Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(fontSize: 26);
                    return SizedBox(
                      width: _fieldWidth(controller.text, valueStyle),
                      child: TextField(
                        controller: controller,
                        textAlign: TextAlign.center,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.allow(
                            _decimals == 0
                                ? RegExp(r'\d')
                                : RegExp(r'^\d+[.,]?\d?'),
                          ),
                        ],
                        onChanged: onTextChanged,
                        style: valueStyle,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    );
                  },
                ),
              ),

              const SizedBox(width: 4),

              Text(
                widget.unit,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge!.copyWith(fontSize: 26),
              ),
            ],
          ),

          const SizedBox(width: 12),

          _circleButton(Icons.add, increase),
        ],
      ),
    );
  }

  Widget _circleButton(IconData icon, VoidCallback onPressed) {
    return IconButton(
      onPressed: onPressed,
      icon: Icon(
        icon,
        size: 22,
        color: context.watch<AppearanceController>().secondaryColor,
      ),
    );
  }
}
