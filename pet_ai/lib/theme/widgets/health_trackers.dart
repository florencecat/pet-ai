import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/app_text_styles.dart';
import 'package:pet_satellite/theme/font_awesome_icons.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/toast.dart';

/// Стабильные идентификаторы трекеров — ключи для настроек (закрепление/порядок).
enum HealthTrackerId { weight, food, mood, walk, heat, symptom }

extension HealthTrackerIdX on HealthTrackerId {
  static HealthTrackerId? fromName(String name) {
    for (final id in HealthTrackerId.values) {
      if (id.name == name) return id;
    }
    return null;
  }
}

/// Базовый интерфейс виджета-трекера на странице «Здоровье».
///
/// Каждый трекер знает: закреплён ли он ([pinned]), есть ли по нему данные
/// ([empty]) и как себя показать — в расширенном ([expanded]) и мини-виде
/// ([mini]). Базовые представления реализованы здесь по умолчанию (как у
/// текущих виджетов веса/питания/настроения); конкретный трекер поставляет
/// только данные. Так новый трекер добавляется одним подклассом.
abstract class HealthTrackerWidget {
  /// Закреплён пользователем (до 2 закреплённых). Проставляется при сборке.
  bool pinned = false;

  HealthTrackerId get id;
  String get title;
  IconData get icon;
  Color get color;

  /// Нет записей по трекеру.
  bool get empty;

  /// Трекер реализован. У плейсхолдеров (прогулки/течка/симптом) — false:
  /// показываем «скоро», лист не открываем.
  bool get available;

  /// Подсказка пустого состояния: «Добавьте прогулку», «Зафиксируйте течку».
  String get emptyHint;

  /// Открыть соответствующий лист/экран. null — открывать нечего (плейсхолдер).
  VoidCallback? get onTap;

  /// Крупное значение расширенной плитки (напр. «13.6 кг»). Может быть null.
  String? get value;

  /// Доп. виджет под значением в расширенной плитке (бейдж динамики / дата).
  Widget? expandedExtra(BuildContext context) => null;

  /// Подпись мини-строки. Для пустых трекеров — [emptyHint].
  Widget miniSubtitle(BuildContext context) =>
      Text(empty ? emptyHint : (value ?? ''), style: context.subtitleStyle);

  /// Расширенное представление — крупная плитка (как «Сегодня» сейчас).
  Widget expanded(BuildContext context) => HealthTrackerCard(tracker: this);

  /// Мини-представление — плотная строка списка.
  Widget mini(BuildContext context) => HealthTrackerRow(tracker: this);
}

// ─── Конкретные трекеры ──────────────────────────────────────────────────────

class WeightTracker extends HealthTrackerWidget {
  @override
  final bool empty;
  final double? dynamics;
  final String? _value;
  @override
  final VoidCallback? onTap;

  WeightTracker({
    required this.empty,
    required String? value,
    required this.dynamics,
    required this.onTap,
  }) : _value = value;

  @override
  HealthTrackerId get id => HealthTrackerId.weight;
  @override
  String get title => 'Вес';
  @override
  IconData get icon => FontAwesome.weight;
  @override
  Color get color => ThemeColors.weightIconColor;
  @override
  bool get available => true;
  @override
  String get emptyHint => 'Добавьте взвешивание';
  @override
  String? get value => _value;
  @override
  Widget? expandedExtra(BuildContext context) =>
      dynamics != null ? dynamicsBadge(dynamics!, context.subtitleStyle) : null;
}

class FoodTracker extends HealthTrackerWidget {
  @override
  final bool empty;
  final String? _value;
  final String? _foodName;
  @override
  final VoidCallback? onTap;

  FoodTracker({
    required this.empty,
    required String? value,
    required String? foodName,
    required this.onTap,
  }) : _value = value,
       _foodName = foodName;

  @override
  HealthTrackerId get id => HealthTrackerId.food;
  @override
  String get title => 'Питание';
  @override
  IconData get icon => Icons.fastfood;
  @override
  Color get color => ThemeColors.foodIconColor;
  @override
  bool get available => true;
  @override
  String get emptyHint => 'Запишите кормление';
  @override
  String? get value => _value;
  @override
  Widget? expandedExtra(BuildContext context) =>
      _foodName != null ? Text(_foodName, style: context.subtitleStyle) : null;
}

class MoodTracker extends HealthTrackerWidget {
  @override
  final bool empty;
  final String? _value;
  final IconData _icon;
  final String? dateLabel;
  @override
  final VoidCallback? onTap;

  MoodTracker({
    required this.empty,
    required String? value,
    required IconData icon,
    required this.dateLabel,
    required this.onTap,
  }) : _value = value,
       _icon = icon;

  @override
  HealthTrackerId get id => HealthTrackerId.mood;
  @override
  String get title => 'Настроение';
  @override
  IconData get icon => _icon;
  @override
  Color get color => ThemeColors.moodIconColor;
  @override
  bool get available => true;
  @override
  String get emptyHint => 'Отметьте настроение';
  @override
  String? get value => _value;
  @override
  Widget? expandedExtra(BuildContext context) =>
      dateLabel != null ? Text(dateLabel!, style: context.subtitleStyle) : null;
  @override
  Widget miniSubtitle(BuildContext context) => empty
      ? super.miniSubtitle(context)
      : Row(
          spacing: 6,
          children: [
            if (value != null)
              Text(
                value!,
                style: context.subtitleStyle.copyWith(
                  color: context.titleColor.withAlpha(220),
                ),
              ),
            if (dateLabel != null)
              Text(dateLabel!, style: context.subtitleStyle),
          ],
        );
}

/// База для ещё не реализованных трекеров: всегда пусты, лист не открывают.
abstract class _PlaceholderTracker extends HealthTrackerWidget {
  @override
  bool get empty => true;
  @override
  bool get available => false;
  @override
  VoidCallback? get onTap => null;
  @override
  String? get value => null;
}

class WalkTracker extends _PlaceholderTracker {
  @override
  HealthTrackerId get id => HealthTrackerId.walk;
  @override
  String get title => 'Прогулки';
  @override
  IconData get icon => Icons.directions_walk;
  @override
  Color get color => const Color(0xFF3f8f6f);
  @override
  String get emptyHint => 'Добавьте прогулку';
}

class HeatTracker extends _PlaceholderTracker {
  @override
  HealthTrackerId get id => HealthTrackerId.heat;
  @override
  String get title => 'Течка';
  @override
  IconData get icon => Icons.local_florist_outlined;
  @override
  Color get color => const Color(0xFFc4568a);
  @override
  String get emptyHint => 'Зафиксируйте течку';
}

class SymptomTracker extends _PlaceholderTracker {
  @override
  HealthTrackerId get id => HealthTrackerId.symptom;
  @override
  String get title => 'Симптом';
  @override
  IconData get icon => Icons.monitor_heart_outlined;
  @override
  Color get color => const Color(0xFF7a5fd0);
  @override
  String get emptyHint => 'Отметьте симптом';
}

// ─── Настройки трекеров (persist) ────────────────────────────────────────────

class HealthTrackersConfig {
  static const _kPinned = 'health_trackers_pinned';
  static const _kCount = 'health_trackers_count';

  static const defaultPinned = [HealthTrackerId.weight, HealthTrackerId.mood];
  static const defaultCount = 3;
  static const maxPinned = 2;
  static const minVisible = 1;
  static const maxVisible = 4;

  final List<HealthTrackerId> pinned;
  final int visibleCount;

  const HealthTrackersConfig({
    required this.pinned,
    required this.visibleCount,
  });

  static Future<HealthTrackersConfig> load() async {
    final prefs = await SharedPreferences.getInstance();
    final names = prefs.getStringList(_kPinned);
    final pinned = names == null
        ? List<HealthTrackerId>.from(defaultPinned)
        : names
              .map(HealthTrackerIdX.fromName)
              .whereType<HealthTrackerId>()
              .take(maxPinned)
              .toList();
    final count = (prefs.getInt(_kCount) ?? defaultCount).clamp(
      minVisible,
      maxVisible,
    );
    return HealthTrackersConfig(pinned: pinned, visibleCount: count);
  }

  static Future<void> save(List<HealthTrackerId> pinned, int count) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kPinned, pinned.map((e) => e.name).toList());
    await prefs.setInt(_kCount, count);
  }
}

/// Незакреплённые трекеры в порядке показа: сначала с данными, затем пустые
/// (внутри групп — исходный порядок [all]).
List<HealthTrackerWidget> orderedUnpinned(
  List<HealthTrackerWidget> all,
  List<HealthTrackerId> pinnedIds,
) {
  final rest = all.where((t) => !pinnedIds.contains(t.id)).toList();
  final withData = rest.where((t) => !t.empty);
  final withoutData = rest.where((t) => t.empty);
  return [...withData, ...withoutData];
}

// ─── Блок «Мои трекеры» на странице здоровья ─────────────────────────────────

class HealthTrackersSection extends StatefulWidget {
  final List<HealthTrackerWidget> trackers; // канонический порядок
  final List<HealthTrackerId> pinnedIds;
  final int visibleCount;
  final VoidCallback onConfigure;

  const HealthTrackersSection({
    super.key,
    required this.trackers,
    required this.pinnedIds,
    required this.visibleCount,
    required this.onConfigure,
  });

  @override
  State<HealthTrackersSection> createState() => _HealthTrackersSectionState();
}

class _HealthTrackersSectionState extends State<HealthTrackersSection> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    // Закреплённые — в порядке закрепления.
    final pinned = <HealthTrackerWidget>[];
    for (final id in widget.pinnedIds) {
      final t = widget.trackers.where((t) => t.id == id);
      if (t.isNotEmpty) {
        t.first.pinned = true;
        pinned.add(t.first);
      }
    }
    for (final t in widget.trackers) {
      t.pinned = widget.pinnedIds.contains(t.id);
    }

    final rest = orderedUnpinned(widget.trackers, widget.pinnedIds);
    final visible = _expanded ? rest : rest.take(widget.visibleCount).toList();
    final hiddenCount = rest.length - visible.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // ── Заголовок + «Настроить» ─────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Мои трекеры',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton.icon(
                onPressed: widget.onConfigure,
                label: Text(
                  'Настроить',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(color: context.subtitleColor),
                ),
                icon: Icon(
                  Icons.push_pin_outlined,
                  color: context.subtitleColor,
                ),
                iconAlignment: IconAlignment.end,
              ),
            ],
          ),
        ),

        // ── Закреплённые (крупно) ───────────────────────────────────────────
        if (pinned.isNotEmpty) ...[
          _PinnedGrid(pinned: pinned),
          const SizedBox(height: 12),
        ],

        // ── Компактный список остальных ─────────────────────────────────────
        if (visible.isNotEmpty || hiddenCount > 0)
          GlassPlate(
            useShadow: false,
            padding: 0,
            child: Column(
              children: [
                for (var i = 0; i < visible.length; i++) ...[
                  if (i > 0) const _RowDivider(),
                  visible[i].mini(context),
                ],
                if (hiddenCount > 0 || _expanded) ...[
                  const _RowDivider(),
                  _ExpandToggle(
                    expanded: _expanded,
                    hiddenCount: hiddenCount,
                    onTap: () => setState(() => _expanded = !_expanded),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

class _PinnedGrid extends StatelessWidget {
  final List<HealthTrackerWidget> pinned;

  const _PinnedGrid({required this.pinned});

  @override
  Widget build(BuildContext context) {
    if (pinned.length == 1) return pinned.first.expanded(context);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: pinned[0].expanded(context)),
          const SizedBox(width: 12),
          Expanded(child: pinned[1].expanded(context)),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      indent: 14,
      endIndent: 14,
      color: context.watch<AppearanceController>().secondaryColor.withAlpha(30),
    );
  }
}

class _ExpandToggle extends StatelessWidget {
  final bool expanded;
  final int hiddenCount;
  final VoidCallback onTap;

  const _ExpandToggle({
    required this.expanded,
    required this.hiddenCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<AppearanceController>().primaryColor;
    return Pressable(
      haptic: HapticStrength.selection,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              size: 16,
              color: primary,
            ),
            const SizedBox(width: 6),
            Text(
              expanded ? 'Свернуть' : 'Ещё $hiddenCount ${_word(hiddenCount)}',
              style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                color: primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  static String _word(int n) {
    final mod10 = n % 10;
    final mod100 = n % 100;
    if (mod100 >= 11 && mod100 <= 14) return 'трекеров';
    if (mod10 == 1) return 'трекер';
    if (mod10 >= 2 && mod10 <= 4) return 'трекера';
    return 'трекеров';
  }
}

// ─── Базовые представления трекера ───────────────────────────────────────────

/// Расширенная плитка — как виджеты «Сегодня» сейчас: иконка, значение и
/// (опционально) доп. строка снизу. Мини-график намеренно не добавляется.
class HealthTrackerCard extends StatelessWidget {
  final HealthTrackerWidget tracker;

  const HealthTrackerCard({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    final extra = tracker.expandedExtra(context);
    final showValue = !tracker.empty && tracker.value != null;

    return GlassCard(
      transparent: true,
      padding: 16,
      callback: () => _activate(context, tracker),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SoftRoundedIcon(
                icon: tracker.icon,
                color: tracker.color,
                size: 18,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            showValue ? tracker.value! : tracker.emptyHint,
            style: Theme.of(context).textTheme.titleMedium!.copyWith(
              inherit: true,
              fontSize: 16,
              color: showValue
                  ? null
                  : context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(140),
            ),
          ),
          if (extra != null) ...[const SizedBox(height: 6), extra],
        ],
      ),
    );
  }
}

/// Мини-строка списка: иконка, название, статус/подсказка, шеврон.
class HealthTrackerRow extends StatelessWidget {
  final HealthTrackerWidget tracker;

  const HealthTrackerRow({super.key, required this.tracker});

  @override
  Widget build(BuildContext context) {
    final secondary = context.watch<AppearanceController>().secondaryColor;
    return Pressable(
      haptic: HapticStrength.light,
      onTap: () => _activate(context, tracker),
      child: ListTile(
        titleAlignment: ListTileTitleAlignment.titleHeight,
        leading: SoftRoundedIcon(
          icon: tracker.icon,
          color: tracker.color,
          size: 20,
        ),
        title: Text(
          tracker.title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600),
        ),
        subtitle: tracker.miniSubtitle(context),
        trailing: Icon(
          !tracker.available ? null : tracker.empty ? Icons.add : Icons.chevron_right,
          size: tracker.empty && tracker.available ? 20 : 22,
          color: secondary.withAlpha(160),
        ),
      ),
    );
  }
}

/// Открывает лист трекера, либо показывает «скоро» для плейсхолдеров.
void _activate(BuildContext context, HealthTrackerWidget tracker) {
  final onTap = tracker.onTap;
  if (onTap != null) {
    onTap();
  } else if (!tracker.available) {
    showAppToast(context, 'Трекер «${tracker.title}» скоро появится');
  }
}

// ─── Лист настройки трекеров ──────────────────────────────────────────────────

class ConfigureTrackersSheet extends StatefulWidget {
  final List<HealthTrackerWidget> trackers;
  final List<HealthTrackerId> initialPinned;
  final int initialCount;
  final void Function(List<HealthTrackerId> pinned, int count) onChanged;

  const ConfigureTrackersSheet({
    super.key,
    required this.trackers,
    required this.initialPinned,
    required this.initialCount,
    required this.onChanged,
  });

  @override
  State<ConfigureTrackersSheet> createState() => _ConfigureTrackersSheetState();
}

class _ConfigureTrackersSheetState extends State<ConfigureTrackersSheet> {
  late final List<HealthTrackerId> _pinned = List.of(widget.initialPinned);
  late int _count = widget.initialCount;

  HealthTrackerWidget _byId(HealthTrackerId id) =>
      widget.trackers.firstWhere((t) => t.id == id);

  void _togglePin(HealthTrackerWidget t) {
    if (_pinned.contains(t.id)) {
      setState(() => _pinned.remove(t.id));
    } else {
      if (_pinned.length >= HealthTrackersConfig.maxPinned) {
        showAppToast(context, 'Можно закрепить не более 2 трекеров');
        return;
      }
      setState(() => _pinned.add(t.id));
    }
    widget.onChanged(_pinned, _count);
  }

  void _setCount(int c) {
    setState(() => _count = c);
    widget.onChanged(_pinned, _count);
  }

  @override
  Widget build(BuildContext context) {
    final pinnedTrackers = _pinned.map(_byId).toList();
    final rest = orderedUnpinned(widget.trackers, _pinned);

    return DraggableSheet(
      title: 'Настройка трекеров',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: 0.75,
      maxSize: 0.95,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Закреплённые ────────────────────────────────────────────────
          Text('Закреплённые', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          Text(
            'До 2 трекеров показываются крупными плитками',
            style: context.subtitleStyle,
          ),
          const SizedBox(height: 8),
          if (pinnedTrackers.isEmpty)
            InfoGlassPlate(label: 'Нажмите на трекер ниже, чтобы закрепить его')
          else
            for (final t in pinnedTrackers)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ConfigRow(
                  tracker: t,
                  pinned: true,
                  onTap: () => _togglePin(t),
                ),
              ),

          const SizedBox(height: 16),

          // ── Количество под закреплёнными ────────────────────────────────
          Text(
            'Показывать под закреплёнными',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          _CountSelector(count: _count, onChanged: _setCount),

          const SizedBox(height: 16),

          // ── Остальные трекеры ───────────────────────────────────────────
          Text('Все трекеры', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          for (final t in rest)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _ConfigRow(
                tracker: t,
                pinned: false,
                onTap: () => _togglePin(t),
              ),
            ),
        ],
      ),
    );
  }
}

class _CountSelector extends StatelessWidget {
  final int count;
  final ValueChanged<int> onChanged;

  const _CountSelector({required this.count, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final primary = context.watch<AppearanceController>().primaryColor;
    return Row(
      children: [
        for (
          var n = HealthTrackersConfig.minVisible;
          n <= HealthTrackersConfig.maxVisible;
          n++
        )
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                right: n == HealthTrackersConfig.maxVisible ? 0 : 8,
              ),
              child: Pressable(
                haptic: HapticStrength.selection,
                scale: 0.94,
                onTap: () => onChanged(n),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: n == count
                        ? primary.withAlpha(210)
                        : primary.withAlpha(20),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: n == count ? primary : primary.withAlpha(60),
                    ),
                  ),
                  child: Text(
                    '$n',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: n == count ? Colors.white : primary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _ConfigRow extends StatelessWidget {
  final HealthTrackerWidget tracker;
  final bool pinned;
  final VoidCallback onTap;

  const _ConfigRow({
    required this.tracker,
    required this.pinned,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final secondary = context.watch<AppearanceController>().secondaryColor;
    final primary = context.watch<AppearanceController>().primaryColor;
    final status = tracker.empty
        ? (tracker.available ? 'Нет данных' : 'Скоро')
        : (tracker.value ?? 'Есть данные');

    return GlassPlate(
      useShadow: false,
      padding: 0,
      child: Pressable(
        haptic: HapticStrength.selection,
        onTap: onTap,
        child: ListTile(
          leading: SoftRoundedIcon(
            icon: tracker.icon,
            color: tracker.color,
            size: 20,
          ),
          title: Text(
            tracker.title,
            style: Theme.of(
              context,
            ).textTheme.titleSmall!.copyWith(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(status, style: context.subtitleStyle),
          trailing: Icon(
            pinned ? Icons.push_pin : Icons.push_pin_outlined,
            size: 20,
            color: pinned ? primary : secondary.withAlpha(120),
          ),
        ),
      ),
    );
  }
}
