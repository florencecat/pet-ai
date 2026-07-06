import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/widgets/activity_indicator.dart';
import 'package:pet_satellite/theme/widgets/appetite_stepper.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/base_widgets.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/grouped_history_list.dart';
import 'package:pet_satellite/theme/widgets/suggestion_list.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class FoodDialog extends StatefulWidget {
  final Pet profile;
  final MealHistory history;

  /// Редактируемая запись, либо null если создаётся новая.
  final MealEntry? editEntry;

  const FoodDialog({
    super.key,
    required this.profile,
    required this.history,
    this.editEntry,
  });

  @override
  State<FoodDialog> createState() => _FoodDialogState();
}

class _FoodDialogState extends State<FoodDialog> {
  // ── New-entry form state ─────────────────────────────────────────────────
  int _appetiteScore = 3;
  MealTime _mealTime = MealTime.morning;
  FoodKind _kind = FoodKind.natural;
  bool _isSaving = false;

  final _foodCtrl = TextEditingController();
  final _gramsCtrl = TextEditingController(text: '100');
  final _foodFocus = FocusNode();
  List<String> _suggestions = [];

  MealHistory get _history => widget.history;
  bool get _isEditing => widget.editEntry != null;

  @override
  void initState() {
    super.initState();
    final entry = widget.editEntry;
    if (entry != null) {
      _kind = entry.kind;
      _mealTime = entry.mealTime;
      _appetiteScore = entry.appetiteScore;
      _foodCtrl.text = entry.foodName;
      _gramsCtrl.text = entry.grams.toString();
    } else {
      // Дефолт граммовки зависит от типа корма (см. _defaultGramsForKind).
      _gramsCtrl.text = _defaultGramsForKind(_kind).toString();
    }
    _foodCtrl.addListener(_refreshSuggestions);
  }

  @override
  void dispose() {
    _foodCtrl.dispose();
    _gramsCtrl.dispose();
    _foodFocus.dispose();
    super.dispose();
  }

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

  // ── Save ────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    setState(() => _isSaving = true);

    bool error = false;
    try {
      final entry = MealEntry(
        id: widget.editEntry?.id,
        date: DateTime.now(),
        mealTime: _mealTime,
        appetiteScore: _appetiteScore,
        grams: _grams,
        foodName: _foodCtrl.text.trim(),
        kind: _kind,
      );
      await PetProfileService().updateFoodHistory(widget.profile.id, entry);
    } catch (e) {
      error = true;
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
        if (!error) Navigator.of(context).pop(true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return AlertDialog(
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: _isSaving ? null : _save,
          style: FilledButton.styleFrom(backgroundColor: accent),
          child: Text(_isEditing ? 'Сохранить' : 'Добавить'),
        ),
      ],
      title: Text(
        _isEditing ? 'Редактирование' : 'Новая запись',
        style: Theme.of(context).textTheme.titleLarge,
        textAlign: TextAlign.center,
      ),
      content: InlineLoading(
        isLoading: _isSaving,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
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
                  context,
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
              // Анимируем появление/скрытие подсказок, чтобы диалог не «прыгал».
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                alignment: Alignment.topCenter,
                child: _showSuggestions
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
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
                      )
                    : const SizedBox(width: double.infinity),
              ),

              const SizedBox(height: 16),

              Text(
                'Аппетит и граммовка',
                style: Theme.of(context).textTheme.bodySmall,
              ),
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
              Text('Время суток', style: Theme.of(context).textTheme.bodySmall),
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
            ],
          ),
        ),
      ),
    );
  }
}

class FoodSheet extends StatefulWidget {
  final Pet profile;

  const FoodSheet({super.key, required this.profile});

  @override
  State<FoodSheet> createState() => _FoodSheetState();
}

class _FoodSheetState extends State<FoodSheet> {
  late MealHistory _history;

  @override
  void initState() {
    super.initState();
    _history = widget.profile.foodHistory;
  }

  Future<void> _showAddDialog({MealEntry? editEntry}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => FoodDialog(
        profile: widget.profile,
        history: _history,
        editEntry: editEntry,
      ),
    );
    if (saved == true) await _reload();
  }

  Future<void> _reload() async {
    final fresh = await PetProfileService().loadProfile(widget.profile.id);
    if (fresh != null && mounted) {
      setState(() => _history = fresh.foodHistory);
    }
  }

  Future<void> _delete(MealEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить запись?');
    if (!confirmed) return;
    await PetProfileService().deleteFoodEntryById(widget.profile.id, entry.id);
    if (mounted) setState(() => _history.deleteById(entry.id));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _history.entries;
    final accent = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: 'Дневник питания',
      centerTitle: true,
      initialSize: entries.isEmpty ? 0.2 : 0.6,
      maxSize: 0.85,
      onBack: () => Navigator.of(context).pop(true),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Column(
              mainAxisAlignment: MainAxisAlignment.end,
              mainAxisSize: MainAxisSize.max,
              children: [
                Icon(
                  Icons.restaurant_outlined,
                  size: 72,
                  color: accent.withAlpha(192),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Дневник пуст.',
                      style: Theme.of(context).textTheme.titleLarge!.copyWith(
                        inherit: true,
                        color: context
                            .watch<AppearanceController>()
                            .secondaryColor
                            .withAlpha(60),
                      ),
                    ),
                    TextButton(
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.all(5),
                      ),
                      onPressed: () => _showAddDialog(),
                      child: Row(
                        spacing: 1,
                        children: [
                          Text(
                            'Добавить',
                            style: Theme.of(context).textTheme.titleLarge!
                                .copyWith(
                                  inherit: true,
                                  color: context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                      .withAlpha(192),
                                ),
                          ),
                          Icon(Icons.chevron_right_rounded, size: 28),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            )
          else ...[
            SoftGlassButton(
              icon: Icons.restaurant_menu_outlined,
              title: 'Добавить запись',
              subtitle: 'Ведите дневник питания',
              onTap: () => _showAddDialog(),
            ),
            const SizedBox(height: 16),
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
                onEdit: () => _showAddDialog(editEntry: e),
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
    // IntrinsicHeight + stretch выравнивает все чипы по самому высокому
    // (лейблы «Влажный корм»/«Сухой корм» переносятся в две строки на узких
    // экранах — иначе такой чип становится выше остальных).
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
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
                padding: const EdgeInsets.symmetric(
                  vertical: 10,
                  horizontal: 2,
                ),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected ? color.withAlpha(220) : color.withAlpha(20),
                  border: Border.all(
                    color: selected ? color : color.withAlpha(60),
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
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
      ),
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
                style: context.subtitleStyle.copyWith(
                  color: accent.withAlpha(172),
                )
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
    final color = this.color.withAlpha(172);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 3),
        Text(
          label,
          style: context.subtitleStyle.copyWith(
            fontSize: 11,
            color: color,
          ),
        ),
      ],
    );
  }
}
