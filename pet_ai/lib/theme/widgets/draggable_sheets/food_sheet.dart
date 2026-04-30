import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/models/food.dart';
import 'package:pet_ai/services/appearance_controller.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/theme/widgets/appetite_stepper.dart';
import 'package:pet_ai/theme/widgets/base_widgets.dart';
import 'package:pet_ai/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_ai/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';

class FoodSheet extends StatefulWidget {
  final PetProfile profile;

  const FoodSheet({super.key, required this.profile});

  @override
  State<FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<FoodSheet> {
  late FoodHistory _history;

  // ── New-entry form state ─────────────────────────────────────────────────
  int _appetiteScore = 3;
  MealTime _mealTime = MealTime.morning;
  double _grams = 100;
  DateTime _date = DateTime.now();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.foodHistory;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final entry = FoodEntry(
        date: _date,
        mealTime: _mealTime,
        appetiteScore: _appetiteScore,
        grams: _grams.round(),
      );
      await ProfileService().updateFoodHistory(widget.profile.id, entry);
      if (mounted) Navigator.of(context).pop(true);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // ── Date picker ──────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  // ── Delete entry ─────────────────────────────────────────────────────────

  Future<void> _delete(FoodEntry entry) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить запись?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: ThemeColors.dangerZone),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ProfileService().deleteFoodEntry(widget.profile.id, entry.date);
    if (mounted) {
      setState(() => _history.deleteEntry(entry.date));
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = List<FoodEntry>.from(_history.entries.reversed);

    return DraggableSheet(
      title: 'История питания',
      centerTitle: true,
      initialSize: 0.85,
      maxSize: 1.0,
      onBack: () => Navigator.of(context).pop(false),
      actions: [
        if (_isSaving)
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 12),
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          )
        else
          IconButton(
            icon: const Icon(Icons.check),
            color: context.watch<AppearanceController>().primaryColor,
            onPressed: _save,
          ),
      ],
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Form ───────────────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    'Новая запись',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 16),

                  // Appetite stepper
                  Text('Аппетит', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  AppetiteStepper(
                    value: _appetiteScore,
                    onChanged: (v) => setState(() => _appetiteScore = v),
                  ),

                  const SizedBox(height: 16),

                  // Date
                  GestureDetector(
                    onTap: _pickDate,
                    child: AbsorbPointer(
                      child: TextFormField(
                        decoration: baseInputDecoration(
                          'Дата',
                          suffixIcon: Icon(
                            Icons.calendar_today,
                            color: Theme.of(context).dividerColor,
                            size: 18,
                          ),
                        ),
                        controller: TextEditingController(
                          text: DateFormat(
                            'd MMMM yyyy',
                            'ru_RU',
                          ).format(_date),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Meal time
                  Text(
                    'Время суток',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: MealTime.values.map((mt) {
                      final selected = _mealTime == mt;
                      return Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _mealTime = mt),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            margin: const EdgeInsets.symmetric(horizontal: 3),
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: selected
                                  ? context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(200)
                                  : context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(20),
                              border: Border.all(
                                color: selected
                                    ? context
                                          .watch<AppearanceController>()
                                          .primaryColor
                                    : context
                                          .watch<AppearanceController>()
                                          .primaryColor
                                          .withAlpha(60),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mt.icon,
                                  size: 18,
                                  color: selected
                                      ? Colors.white
                                      : context
                                            .watch<AppearanceController>()
                                            .primaryColor,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mt.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected
                                        ? Colors.white
                                        : context
                                              .watch<AppearanceController>()
                                              .primaryColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),

                  const SizedBox(height: 16),

                  // Grams stepper
                  Text(
                    'Граммовка',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  const SizedBox(height: 8),
                  _GramStepper(
                    value: _grams,
                    onChanged: (v) => setState(() => _grams = v),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ── History list ───────────────────────────────────────────────
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 32),
              child: Center(
                child: Column(
                  children: [
                    Icon(
                      Icons.restaurant_outlined,
                      size: 56,
                      color: ThemeColors.primary.withAlpha(60),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'История питания пуста',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: ThemeColors.primary.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text('История', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            ...entries.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _FoodEntryCard(entry: e, onDelete: () => _delete(e)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Gram stepper (wraps PillStepper logic with step=5g) ─────────────────────

class _GramStepper extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;

  const _GramStepper({required this.value, required this.onChanged});

  @override
  State<_GramStepper> createState() => _GramStepperState();
}

class _GramStepperState extends State<_GramStepper> {
  late double _val;

  @override
  void initState() {
    super.initState();
    _val = widget.value;
  }

  void _step(double delta) {
    final next = (_val + delta).clamp(0, 9999).toDouble();
    // Round to nearest 5
    final rounded = (next / 5).round() * 5.0;
    setState(() => _val = rounded);
    widget.onChanged(_val);
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
          IconButton(
            icon: const Icon(Icons.remove, size: 22),
            color: context.watch<AppearanceController>().secondaryColor,
            onPressed: () => _step(-5),
          ),
          const SizedBox(width: 8),
          Text(
            '${_val.toInt()} г',
            style: Theme.of(
              context,
            ).textTheme.titleLarge!.copyWith(fontSize: 26),
          ),
          const SizedBox(width: 8),
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            color: context.watch<AppearanceController>().secondaryColor,
            onPressed: () => _step(5),
          ),
        ],
      ),
    );
  }
}

// ─── History entry card ───────────────────────────────────────────────────────

class _FoodEntryCard extends StatelessWidget {
  final FoodEntry entry;
  final VoidCallback onDelete;

  const _FoodEntryCard({required this.entry, required this.onDelete});

  Color get _appetiteColor {
    if (entry.appetiteScore <= 2) return const Color(0xFFEF5350);
    if (entry.appetiteScore == 3) return const Color(0xFFFFC107);
    return const Color(0xFF66BB6A);
  }

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Appetite score badge
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _appetiteColor.withAlpha(40),
                border: Border.all(color: _appetiteColor, width: 1.5),
              ),
              child: Center(
                child: Text(
                  '${entry.appetiteScore}',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _appetiteColor,
                  ),
                ),
              ),
            ),

            const SizedBox(width: 12),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        entry.mealTime.icon,
                        size: 14,
                        color: context
                            .watch<AppearanceController>()
                            .primaryColor,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        entry.mealTime.label,
                        style: Theme.of(context).textTheme.titleSmall!.copyWith(
                          color: context
                              .watch<AppearanceController>()
                              .secondaryColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${entry.grams} г',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: context
                              .watch<AppearanceController>()
                              .primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    formatSmartDate(entry.date),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),

            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              color: ThemeColors.dangerZone.withAlpha(180),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
