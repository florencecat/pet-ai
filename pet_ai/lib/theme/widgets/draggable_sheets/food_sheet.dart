import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/appetite_stepper.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/grouped_history_list.dart';
import 'package:pet_satellite/theme/widgets/suggestion_list.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class FoodSheet extends StatefulWidget {
  final Pet profile;

  const FoodSheet({super.key, required this.profile});

  @override
  State<FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<FoodSheet> {
  late MealHistory _history;

  // ── New-entry form state ─────────────────────────────────────────────────
  int _appetiteScore = 3;
  MealTime _mealTime = MealTime.morning;
  FoodKind _kind = FoodKind.natural;
  bool _isSaving = false;

  /// Id редактируемой записи, либо null если форма создаёт новую.
  String? _editingId;

  final _foodCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  final _foodFocus = FocusNode();
  List<String> _suggestions = [];

  @override
  void initState() {
    super.initState();
    _history = widget.profile.foodHistory;
    // Дефолт граммовки зависит от типа корма (см. _defaultGramsForKind).
    _gramsCtrl.text = _defaultGramsForKind(_kind).toString();
    _foodCtrl.addListener(_refreshSuggestions);
  }

  @override
  void dispose() {
    _foodCtrl.dispose();
    _gramsCtrl.dispose();
    _foodFocus.dispose();
    super.dispose();
  }

  bool get _isEditing => _editingId != null;

  int get _grams {
    final raw = int.tryParse(_gramsCtrl.text.trim()) ?? 0;
    return raw.clamp(0, 9999);
  }

  /// Дефолтная граммовка для типа корма: граммовка последней записи этого же
  /// типа, иначе базовое значение (лакомство — 10 г, остальное — 100 г).
  int _defaultGramsForKind(FoodKind k) {
    MealEntry? last;
    for (final e in _history.entries) {
      if (e.kind != k) continue;
      if (last == null || e.date.isAfter(last.date)) last = e;
    }
    if (last != null) return last.grams;
    return k == FoodKind.treat ? 10 : 100;
  }

  void _setGrams(int v) {
    final clamped = v.clamp(0, 9999);
    _gramsCtrl.text = clamped.toString();
    _gramsCtrl.selection = TextSelection.collapsed(
      offset: _gramsCtrl.text.length,
    );
    setState(() {});
  }

  void _stepGrams(int delta) {
    HapticFeedback.selectionClick();
    // Шаг кратен 5.
    final next = ((_grams + delta) / 5).round() * 5;
    _setGrams(next);
  }

  // ── Suggestions (autocomplete) ───────────────────────────────────────────

  void _refreshSuggestions() {
    setState(() {
      _suggestions = _foodCtrl.text.trim().isEmpty
          ? []
          : _history.foodSuggestions(kind: _kind, query: _foodCtrl.text);
    });
  }

  bool get _showSuggestions => _suggestions.isNotEmpty;

  // ── Save / edit ───────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);
    try {
      final entry = MealEntry(
        id: _editingId,
        date: DateTime.now(),
        mealTime: _mealTime,
        appetiteScore: _appetiteScore,
        grams: _grams,
        foodName: _foodCtrl.text.trim(),
        kind: _kind,
      );
      await PetService().updateFoodHistory(widget.profile.id, entry);
      if (mounted) {
        final fresh = await PetService().loadProfile(widget.profile.id);
        if (fresh != null && mounted) {
          _history = fresh.foodHistory;
        }
        _resetForm();
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _resetForm() {
    setState(() {
      _editingId = null;
      _foodCtrl.clear();
      _appetiteScore = 3;
      _suggestions = [];
      // Граммовку оставляем как удобный «последний» дефолт.
    });
    FocusScope.of(context).unfocus();
  }

  void _startEdit(MealEntry e) {
    setState(() {
      _editingId = e.id;
      _kind = e.kind;
      _mealTime = e.mealTime;
      _appetiteScore = e.appetiteScore;
      _foodCtrl.text = e.foodName;
      _gramsCtrl.text = e.grams.toString();
    });
  }

  Future<void> _delete(MealEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить запись?');
    if (!confirmed) return;
    await PetService().deleteFoodEntryById(widget.profile.id, entry.id);
    if (mounted) {
      setState(() {
        _history.deleteById(entry.id);
        if (_editingId == entry.id) _resetForm();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final entries = _history.entries;
    final accent = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: 'Дневник питания',
      centerTitle: true,
      initialSize: 0.65,
      minSize: 0.5,
      maxSize: 1.0,
      onBack: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Form ───────────────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Text(
                      _isEditing ? 'Редактирование' : 'Новая запись',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Тип питания
                  Text('Пища', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  _KindSelector(
                    value: _kind,
                    onChanged: (k) {
                      setState(() {
                        _kind = k;
                        // При смене типа подставляем подходящий дефолт граммовки
                        // (но не затираем значение при редактировании записи).
                        if (!_isEditing) {
                          _gramsCtrl.text = _defaultGramsForKind(k).toString();
                        }
                      });
                      _refreshSuggestions();
                    },
                  ),

                  const SizedBox(height: 16),

                  TextField(
                    controller: _foodCtrl,
                    focusNode: _foodFocus,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: baseInputDecoration(
                      _kind == FoodKind.natural
                          ? 'Напр. курица, гречка'
                          : 'Название корма',
                      suffixIcon: _foodCtrl.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.close, size: 18),
                              onPressed: () {
                                _foodCtrl.clear();
                                _refreshSuggestions();
                              },
                            )
                          : null,
                    ),
                  ),
                  if (_showSuggestions) ...[
                    const SizedBox(height: 8),
                    SuggestionList(
                      suggestions: _suggestions,
                      icon: Icons.restaurant_menu,
                      accent: _kind.color,
                      onSelected: (name) {
                        _foodCtrl.text = name;
                        _foodCtrl.selection = TextSelection.collapsed(
                          offset: name.length,
                        );
                        setState(() => _suggestions = []);
                        _foodFocus.unfocus();
                      },
                    ),
                  ],

                  const SizedBox(height: 16),

                  Text('Аппетит и граммовка', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  Center(
                    child: AppetiteStepper(
                      value: _appetiteScore,
                      onChanged: (v) => setState(() => _appetiteScore = v),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _GramInput(
                    controller: _gramsCtrl,
                    onStep: _stepGrams,
                    onChanged: () => setState(() {}),
                  ),

                  const SizedBox(height: 16),

                  // Время суток
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
                                  ? accent.withAlpha(200)
                                  : accent.withAlpha(20),
                              border: Border.all(
                                color: selected ? accent : accent.withAlpha(60),
                              ),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  mt.icon,
                                  size: 18,
                                  color: selected ? Colors.white : accent,
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  mt.label,
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: selected ? Colors.white : accent,
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

                  Row(
                    children: [
                      if (_isEditing) ...[
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _isSaving ? null : _resetForm,
                            child: const Text('Отмена'),
                          ),
                        ),
                        const SizedBox(width: 12),
                      ],
                      Expanded(
                        child: TextButton.icon(
                          onPressed: _isSaving ? null : _save,
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Icon(
                                  _isEditing ? Icons.check : Icons.add,
                                  size: 18,
                                ),
                          label: Text(_isEditing ? 'Сохранить' : 'Добавить'),
                        ),
                      ),
                    ],
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
                      color: accent.withAlpha(60),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Дневник питания пуст',
                      style: Theme.of(context).textTheme.bodyLarge!.copyWith(
                        color: accent.withAlpha(120),
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Text('История', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            GroupedHistoryList<MealEntry>(
              entries: entries,
              // Внутри даты: ночь → вечер → день → утро, затем по времени.
              sortWithinGroup: (a, b) {
                final byTime = b.mealTime.index.compareTo(a.mealTime.index);
                if (byTime != 0) return byTime;
                return a.date.compareTo(b.date);
              },
              itemBuilder: (context, e) => _FoodEntryCard(
                entry: e,
                onEdit: () => _startEdit(e),
                onDelete: () => _delete(e),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Kind selector ────────────────────────────────────────────────────────────

class _KindSelector extends StatelessWidget {
  final FoodKind value;
  final ValueChanged<FoodKind> onChanged;

  const _KindSelector({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: FoodKind.values.map((k) {
        final selected = value == k;
        final color = k.color;
        return Expanded(
          child: GestureDetector(
            onTap: () {
              HapticFeedback.selectionClick();
              onChanged(k);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: selected ? color.withAlpha(220) : color.withAlpha(20),
                border: Border.all(
                  color: selected ? color : color.withAlpha(60),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    k.icon,
                    size: 18,
                    color: selected ? Colors.white : color,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    k.label,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: selected ? Colors.white : color,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Gram input (manual entry + step buttons) ────────────────────────────────

class _GramInput extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<int> onStep;
  final VoidCallback onChanged;

  const _GramInput({
    required this.controller,
    required this.onStep,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).dividerColor;
    final secondary = context.watch<AppearanceController>().secondaryColor;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: color, width: 2),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.remove, size: 22),
            color: secondary,
            onPressed: () => onStep(-5),
          ),
          Expanded(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                IntrinsicWidth(
                  child: TextField(
                    controller: controller,
                    onChanged: (_) => onChanged(),
                    keyboardType: TextInputType.number,
                    textAlign: TextAlign.center,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: const InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      hintText: '0',
                    ),
                    style: Theme.of(
                      context,
                    ).textTheme.titleLarge!.copyWith(fontSize: 26),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'г',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge!.copyWith(fontSize: 20, color: color),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.add, size: 22),
            color: secondary,
            onPressed: () => onStep(5),
          ),
        ],
      ),
    );
  }
}

// ─── History entry card ───────────────────────────────────────────────────────

class _FoodEntryCard extends StatelessWidget {
  final MealEntry entry;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FoodEntryCard({
    required this.entry,
    required this.onEdit,
    required this.onDelete,
  });

  Color get _appetiteColor {
    if (entry.appetiteScore <= 2) return const Color(0xFFEF5350);
    if (entry.appetiteScore == 3) return const Color(0xFFFFC107);
    return const Color(0xFF66BB6A);
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;
    final hasName = entry.foodName.trim().isNotEmpty;

    return GlassPlate(
      useShadow: false,
      child: ListTile(
        onTap: onEdit,
        leading: Container(
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
        title: Text(
          hasName ? entry.foodName : entry.kind.label,
          style: Theme.of(context).textTheme.titleSmall!.copyWith(
            color: context.watch<AppearanceController>().secondaryColor,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Wrap(
            spacing: 10,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _Chip(
                icon: entry.kind.icon,
                label: entry.kind.label,
                color: entry.kind.color,
              ),
              _Chip(
                icon: entry.mealTime.icon,
                label: entry.mealTime.label,
                color: accent,
              ),
              Text(
                '${entry.grams} г',
                style: Theme.of(context).textTheme.bodySmall!.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        trailing: IconButton(
          icon: const Icon(Icons.delete_outline, size: 20),
          color: ThemeColors.dangerZone.withAlpha(180),
          onPressed: onDelete,
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _Chip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: color,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
