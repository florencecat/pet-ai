import 'package:flutter/material.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/draggable_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pill_stepper.dart';
import 'package:pet_satellite/theme/widgets/weight_chart.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class WeightSheet extends StatefulWidget {
  final Pet profile;

  const WeightSheet({super.key, required this.profile});

  @override
  State<WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<WeightSheet> {
  HistoryPeriod _period = HistoryPeriod.halfYear;

  bool _changed = false;
  late double _weight;
  late WeightHistory _history;

  @override
  void initState() {
    super.initState();
    _weight = widget.profile.weightHistory.lastWeight ?? 0.0;
    _history = widget.profile.weightHistory;
  }

  Future<void> _save() async {
    await PetService().updateWeightHistory(widget.profile.id, _weight);
    if (!mounted) return;
    // Stay in sheet — reload history list
    final updated = await PetService().loadProfile(widget.profile.id);
    if (updated != null && mounted) {
      setState(() {
        _history = updated.weightHistory;
        _changed = false;
      });
    }
  }

  Future<void> _deleteEntry(WeightEntry entry) async {
    final confirmed = await confirmDelete(context, title: 'Удалить запись?');
    if (!confirmed) return;
    await PetService().deleteWeightEntry(widget.profile.id, entry.date);
    if (mounted) setState(() => _history.deleteEntry(entry.date));
  }

  @override
  Widget build(BuildContext context) {
    final entries = _history.filterByPeriod(_period);
    final color = context.watch<AppearanceController>().secondaryColor;

    return DraggableSheet(
      onBack: () => Navigator.of(context).pop(true),
      title: 'История веса',
      centerTitle: true,
      initialSize: 0.75,
      maxSize: 0.85,
      body: Column(
        children: [
          // ── Period selector ───────────────────────────────────────────────
          SegmentedButton<HistoryPeriod>(
            style: SegmentedButton.styleFrom(
              side: BorderSide(color: color, width: 2),
              foregroundColor: color,
              selectedBackgroundColor: color,
              selectedForegroundColor: Theme.of(context).colorScheme.surface,
            ),
            segments: const [
              ButtonSegment(value: HistoryPeriod.month, label: Text('1 мес')),
              ButtonSegment(
                value: HistoryPeriod.halfYear,
                label: Text('6 мес'),
              ),
              ButtonSegment(value: HistoryPeriod.year, label: Text('Год')),
              ButtonSegment(value: HistoryPeriod.all, label: Text('Всё')),
            ],
            selected: {_period},
            onSelectionChanged: (v) => setState(() => _period = v.first),
          ),

          const SizedBox(height: 16),

          // ── Chart ─────────────────────────────────────────────────────────
          WeightChart(entries: entries),

          // ── New-weight stepper ────────────────────────────────────────────
          GlassPlate(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Новая запись',
                    style: Theme.of(context).textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  Text('Вес', style: Theme.of(context).textTheme.bodySmall),
                  const SizedBox(height: 8),
                  PillStepper(
                      value: _weight,
                      min: 0,
                      max: 150,
                      onChanged: (value) => setState(() {
                        _changed = true;
                        _weight = value;
                      }),
                    ),

                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton.icon(
                      onPressed: _changed ? _save : null,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),

                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── History list ──────────────────────────────────────────────────
          if (_history.entries.isNotEmpty) ...[
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'История',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const SizedBox(height: 8),
            ...List.from(_history.entries.reversed).map<Widget>(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _WeightEntryCard(
                  entry: e as WeightEntry,
                  onDelete: () => _deleteEntry(e),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _WeightEntryCard extends StatelessWidget {
  final WeightEntry entry;
  final VoidCallback onDelete;

  const _WeightEntryCard({required this.entry, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              color: context.watch<AppearanceController>().primaryColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${entry.weight.toStringAsFixed(1)} кг',
                    style: Theme.of(context).textTheme.titleSmall!.copyWith(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    formatSmartDate(entry.date, pattern: 'd MMMM yyyy'),
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
