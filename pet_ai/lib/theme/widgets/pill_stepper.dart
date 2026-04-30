import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:provider/provider.dart';

class PillStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const PillStepper({super.key, required this.value, required this.onChanged});

  @override
  State<PillStepper> createState() => _PillStepperState();
}

class _PillStepperState extends State<PillStepper> {
  late TextEditingController controller;
  late double weight;

  final step = 0.1;

  @override
  void initState() {
    super.initState();

    weight = widget.value;

    controller = TextEditingController(text: weight.toStringAsFixed(1));
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
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'^\d+\.?\d?')),
                  ],
                  onChanged: onTextChanged,
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge!.copyWith(fontSize: 26),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),

              const SizedBox(width: 4),

              Text(
                "кг",
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
