import 'package:flutter/material.dart';
import 'package:pet_satellite/theme/widgets/switch.dart';
import 'package:provider/provider.dart';

import 'package:pet_satellite/models/calendar_filter.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// Лист настроек отображения событий в календаре на странице «События».
/// Изменения применяются и сохраняются сразу (через [onChanged]).
class CalendarFilterSheet extends StatefulWidget {
  final CalendarFilter filter;
  final ValueChanged<CalendarFilter> onChanged;

  const CalendarFilterSheet({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<CalendarFilterSheet> createState() => _CalendarFilterSheetState();
}

class _CalendarFilterSheetState extends State<CalendarFilterSheet> {
  late CalendarFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _update(CalendarFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
    next.save();
  }

  @override
  Widget build(BuildContext context) {
    final accent = context.watch<AppearanceController>().primaryColor;

    return DraggableSheet(
      title: 'Что показывать',
      centerTitle: true,
      onBack: () => Navigator.of(context).pop(),
      initialSize: null,
      minSize: 0.4,
      maxSize: 0.95,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GlassPlate(
            padding: 0,
            child: Column(
              children: [
                _FilterRow(
                  icon: Icons.medication_outlined,
                  label: 'Приём таблеток',
                  accent: accent,
                  value: _filter.showPills,
                  onChanged: (v) => _update(_filter.copyWith(showPills: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.vaccines_outlined,
                  label: 'Обработки',
                  accent: accent,
                  value: _filter.showTreatments,
                  onChanged: (v) =>
                      _update(_filter.copyWith(showTreatments: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.note_outlined,
                  label: 'Заметки',
                  accent: accent,
                  value: _filter.showNotes,
                  onChanged: (v) => _update(_filter.copyWith(showNotes: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.history,
                  label: 'Прошедшие события',
                  accent: accent,
                  value: _filter.showPast,
                  onChanged: (v) => _update(_filter.copyWith(showPast: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.check_circle_outline,
                  label: 'Выполненные события',
                  accent: accent,
                  value: _filter.showCompleted,
                  onChanged: (v) => _update(_filter.copyWith(showCompleted: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.repeat,
                  label: 'Повторяющиеся события',
                  accent: accent,
                  value: _filter.showRepeating,
                  onChanged: (v) => _update(_filter.copyWith(showRepeating: v)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color accent;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _FilterRow({
    required this.icon,
    required this.label,
    required this.accent,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          OutlinedSwitch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) => Divider(
    height: 1,
    indent: 46,
    color: context.watch<AppearanceController>().secondaryColor.withAlpha(60),
  );
}
