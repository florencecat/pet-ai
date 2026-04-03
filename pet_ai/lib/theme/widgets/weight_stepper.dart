import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class WeightStepper extends StatefulWidget {
  final double weight;
  final ValueChanged<double> onChanged;

  const WeightStepper({
    super.key,
    required this.weight,
    required this.onChanged,
  });

  @override
  State<WeightStepper> createState() => _WeightStepperState();
}

class _WeightStepperState extends State<WeightStepper> {
  late TextEditingController controller;
  late double weight;

  final step = 0.1;

  @override
  void initState() {
    super.initState();

    weight = widget.weight;

    controller = TextEditingController(
      text: weight.toStringAsFixed(1),
    );
  }

  void updateWeight(double newWeight) {
    newWeight = (newWeight * 10).round() / 10;

    setState(() {
      weight = newWeight;
      controller.text = weight.toStringAsFixed(1);
    });

    widget.onChanged(weight);
  }

  void increase() async {
    await HapticFeedback.selectionClick();
    updateWeight(weight + step);
  }

  void decrease() async {
    await HapticFeedback.selectionClick();
    updateWeight((weight - step).clamp(0, 999));
  }

  void onTextChanged(String value) {
    final parsed = double.tryParse(value);

    if (parsed != null) {
      weight = parsed;
      widget.onChanged(weight);
    }
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
        mainAxisSize: MainAxisSize.min,
        children: [
          _circleButton(Icons.remove, decrease),

          const SizedBox(width: 12),

          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 60,
                child: TextField(
                  controller: controller,
                  textAlign: TextAlign.center,
                  keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(
                      RegExp(r'^\d+\.?\d{0,1}'),
                    ),
                  ],
                  onChanged: onTextChanged,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge!
                      .copyWith(fontSize: 26),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Text(
                "кг",
                style: Theme.of(context)
                    .textTheme
                    .titleLarge!
                    .copyWith(fontSize: 26),
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
    return InkWell(
      borderRadius: BorderRadius.circular(24),
      onTap: onPressed,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 22),
      ),
    );
  }
}