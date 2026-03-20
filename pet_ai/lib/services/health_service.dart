import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/weight_stepper.dart';

class WeightInputFormatter extends TextInputFormatter {
  final RegExp regex = RegExp(r'^\d+(\.\d?)?$');

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    if (regex.hasMatch(newValue.text)) {
      return newValue;
    }

    return oldValue;
  }
}

class WeightChartPlaceholder extends StatelessWidget {
  final String message;

  const WeightChartPlaceholder({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.monitor_weight_outlined,
              size: 72,
              color: Theme.of(context).colorScheme.primary.withAlpha(128),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge!.copyWith(
                inherit: true,
                color: Theme.of(context).colorScheme.primary.withAlpha(128),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class UpdateWeightModal extends StatefulWidget {
  final PetProfile profile;

  const UpdateWeightModal({super.key, required this.profile});

  @override
  State<UpdateWeightModal> createState() => _UpdateWeightModalState();
}

class _UpdateWeightModalState extends State<UpdateWeightModal> {
  WeightPeriod period = WeightPeriod.month;

  final controller = TextEditingController();

  late double weight;
  late WeightHistory history;

  @override
  void initState() {
    super.initState();
    weight = widget.profile.weightHistory.lastWeight ?? 0.0;
    history = widget.profile.weightHistory;

    controller.text = weight.toString();
  }

  List<FlSpot> buildSpots(List<WeightEntry> entries) {
    return List.generate(entries.length, (i) {
      return FlSpot(i.toDouble(), entries[i].weight);
    });
  }

  void increase() {
    HapticFeedback.selectionClick();

    final current = double.tryParse(controller.text) ?? 0;
    final newValue = (current + 0.1).clamp(0, 999);

    setState(() {
      controller.text = newValue.toStringAsFixed(1);
    });
  }

  void decrease() {
    HapticFeedback.selectionClick();

    final current = double.tryParse(controller.text) ?? 0;
    final newValue = (current - 0.1).clamp(0, 999);

    setState(() {
      controller.text = newValue.toStringAsFixed(1);
    });
  }

  void save() async {
    final newWeight = double.tryParse(weight.toStringAsFixed(1));
    if (newWeight != null) {
      await ProfileService().updateWeightHistory(weight);
    }
    close();
  }

  void close() {
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);
    final spots = buildSpots(entries);

    return DraggableScrollableSheet(
      initialChildSize: 0.65,
      minChildSize: 0.60,
      maxChildSize: 0.65,
      snapSizes: const [0.60, 0.65],
      snap: true,
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade400,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),

              SizedBox(
                height: 48,
                child: Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back),
                      color: Theme.of(context).dividerColor,
                      onPressed: close,
                    ),
                    const Spacer(),
                    IconButton(
                      icon: const Icon(Icons.save),
                      color: Theme.of(context).dividerColor,
                      onPressed: () async => save(),
                    ),
                  ],
                ),
              ),

              Text(
                "История веса",
                style: Theme.of(context).textTheme.titleMedium,
              ),

              const SizedBox(height: 12),

              SegmentedButton<WeightPeriod>(
                style: SegmentedButton.styleFrom(
                  side: BorderSide(
                    color: Theme.of(context).dividerColor,
                    width: 2,
                  ),
                  foregroundColor: Theme.of(context).dividerColor,
                  selectedForegroundColor: Theme.of(
                    context,
                  ).colorScheme.surface,
                ),
                segments: [
                  ButtonSegment(
                    value: WeightPeriod.month,
                    label: Text("Месяц"),
                  ),
                  ButtonSegment(value: WeightPeriod.year, label: Text("Год")),
                  ButtonSegment(value: WeightPeriod.all, label: Text("Все")),
                ],
                selected: {period},
                onSelectionChanged: (value) {
                  setState(() {
                    period = value.first;
                  });
                },
              ),

              const SizedBox(height: 16),

              if (entries.isEmpty)
                WeightChartPlaceholder(message: "История веса пока пуста")
              // SizedBox(
              //   height: 200,
              //   child: Center(
              //     child: Column(
              //       mainAxisAlignment: MainAxisAlignment.center,
              //       children: [
              //         Icon(
              //           Icons.monitor_weight_outlined,
              //           size: 72,
              //           color: Theme.of(
              //             context,
              //           ).colorScheme.primary.withAlpha(128),
              //         ),
              //         const SizedBox(height: 8),
              //         Text(
              //           "История веса пока пуста",
              //           style: Theme.of(context).textTheme.titleLarge!
              //               .copyWith(
              //                 inherit: true,
              //                 color: Theme.of(
              //                   context,
              //                 ).colorScheme.primary.withAlpha(128),
              //               ),
              //         ),
              //       ],
              //     ),
              //   ),
              // )
              else if (entries.length <= 3)
                WeightChartPlaceholder(
                  message:
                      "В истории слишком мало записей для отображения",
                )
              else
                SizedBox(
                  height: 200,
                  child: LineChart(
                    LineChartData(
                      gridData: FlGridData(show: true),

                      titlesData: FlTitlesData(
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            interval: 1,
                            getTitlesWidget: (value, meta) {
                              final index = value.toInt();

                              if (index >= entries.length) {
                                return const SizedBox();
                              }

                              final date = entries[index].date;

                              return Text(
                                "${date.day}.${date.month}",
                                style: const TextStyle(fontSize: 10),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(showTitles: true),
                        ),
                      ),

                      borderData: FlBorderData(show: false),

                      lineBarsData: [
                        LineChartBarData(
                          spots: spots,
                          isCurved: true,
                          barWidth: 3,
                          dotData: FlDotData(show: true),
                        ),
                      ],
                    ),
                  ),
                ),

              const SizedBox(height: 16),

              Center(
                child: WeightStepper(
                  weight: weight,
                  onChanged: (value) {
                    setState(() {
                      weight = value;
                    });
                  },
                ),
              ),

              // Row(
              //   children: [
              //     Expanded(
              //       child: Center(
              //         child: IconButton(
              //           onPressed: decrease,
              //           icon: const Icon(Icons.remove_circle),
              //           color: Theme.of(context).dividerColor,
              //           iconSize: 28,
              //         ),
              //       ),
              //     ),
              //
              //     Expanded(
              //       child: Center(
              //         child: Row(
              //           mainAxisSize: MainAxisSize.min,
              //           children: [
              //             SizedBox(
              //               width: 60,
              //               child: TextField(
              //                 controller: controller,
              //
              //                 keyboardType: const TextInputType.numberWithOptions(decimal: true),
              //                 inputFormatters: [
              //                   WeightInputFormatter(),
              //                 ],
              //                 textAlign: TextAlign.center,
              //                 style: Theme.of(context)
              //                     .textTheme
              //                     .titleLarge!
              //                     .copyWith(fontSize: 28),
              //                 decoration: const InputDecoration(
              //                   border: InputBorder.none,
              //                   isDense: true,
              //                 ),
              //               ),
              //             ),
              //
              //             const SizedBox(width: 6),
              //
              //             Text(
              //               "кг",
              //               style: Theme.of(context)
              //                   .textTheme
              //                   .titleLarge!
              //                   .copyWith(fontSize: 28),
              //             ),
              //           ],
              //         ),
              //       ),
              //     ),
              //
              //     Expanded(
              //       child: Center(
              //         child: IconButton(
              //           onPressed: increase,
              //           icon: const Icon(Icons.add_circle),
              //           color: Theme.of(context).dividerColor,
              //           iconSize: 28,
              //         ),
              //       ),
              //     ),
              //   ],
              // )
            ],
          ),
        );
      },
    );
  }
}

class HealthSummaryModal extends StatelessWidget {
  const HealthSummaryModal({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 450,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Сводка здоровья",
            style: Theme.of(context).textTheme.titleLarge,
          ),

          const SizedBox(height: 20),

          Card(
            child: ListTile(
              leading: const Icon(Icons.favorite),
              title: const Text("Health score"),
              subtitle: const Text("92% • всё в норме"),
            ),
          ),

          const SizedBox(height: 16),

          Text(
            "Последние события",
            style: Theme.of(context).textTheme.titleMedium,
          ),

          const SizedBox(height: 8),

          const Expanded(child: HealthEventsList()),
        ],
      ),
    );
  }
}

class HealthEventsList extends StatelessWidget {
  const HealthEventsList({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: const [
        ListTile(
          leading: Icon(Icons.monitor_weight),
          title: Text("Вес обновлен"),
          subtitle: Text("8.5 кг • сегодня"),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.vaccines),
          title: Text("Вакцинация"),
          subtitle: Text("2 апреля"),
        ),
        Divider(),
        ListTile(
          leading: Icon(Icons.local_hospital),
          title: Text("Визит к ветеринару"),
          subtitle: Text("10 марта"),
        ),
      ],
    );
  }
}
