import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:pet_satellite/models/history_filter.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';

/// Лист настроек фильтрации «Истории питомца» на главной странице.
/// Изменения применяются и сохраняются сразу (через [onChanged]).
class HistoryFilterSheet extends StatefulWidget {
  final HistoryFilter filter;
  final ValueChanged<HistoryFilter> onChanged;

  const HistoryFilterSheet({
    super.key,
    required this.filter,
    required this.onChanged,
  });

  @override
  State<HistoryFilterSheet> createState() => _HistoryFilterSheetState();
}

class _HistoryFilterSheetState extends State<HistoryFilterSheet> {
  late HistoryFilter _filter;

  @override
  void initState() {
    super.initState();
    _filter = widget.filter;
  }

  void _update(HistoryFilter next) {
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
      initialSize: 0.6,
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
                  label: 'Предстоящие таблетки',
                  accent: accent,
                  value: _filter.upcomingPills,
                  onChanged: (v) =>
                      _update(_filter.copyWith(upcomingPills: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.vaccines_outlined,
                  label: 'Предстоящие обработки',
                  accent: accent,
                  value: _filter.upcomingTreatments,
                  onChanged: (v) =>
                      _update(_filter.copyWith(upcomingTreatments: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.cancel_outlined,
                  label: 'Пропущенные события',
                  accent: accent,
                  value: _filter.missedEvents,
                  onChanged: (v) =>
                      _update(_filter.copyWith(missedEvents: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.check_circle_outline,
                  label: 'Выполненные события',
                  accent: accent,
                  value: _filter.completedEvents,
                  onChanged: (v) =>
                      _update(_filter.copyWith(completedEvents: v)),
                ),
                const _RowDivider(),
                _FilterRow(
                  icon: Icons.auto_awesome_outlined,
                  label: 'Автоматические события',
                  accent: accent,
                  value: _filter.automaticEvents,
                  onChanged: (v) =>
                      _update(_filter.copyWith(automaticEvents: v)),
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
          Switch(
            value: value,
            activeThumbColor: accent,
            inactiveThumbColor: accent,
            trackOutlineColor: WidgetStateProperty.resolveWith<Color?>((states) {
              if (states.contains(WidgetState.selected)) {
                return Colors.transparent;
              }
              return accent;
            }),
            onChanged: onChanged,
          ),
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
    color: ThemeColors.border.withAlpha(60),
  );
}
