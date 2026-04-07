import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/services.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/weight_stepper.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/models/weight.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;

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

  bool change = false;
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
    if (Navigator.of(context).mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void close() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);
    final spots = buildSpots(entries);

    return DraggableScrollableSheet(
      minChildSize: 0.50,
      maxChildSize: 0.60,
      snap: true,
      builder: (context, scrollController) {
        return Scaffold(
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          floatingActionButton: WeightStepper(
              weight: weight,
              onChanged: (value) {
                setState(() {
                  change = true;
                  weight = value;
                });
              },
          ),
          body: AnimatedContainer(
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
                        onPressed: change ? () async => save() : null,
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
                else if (entries.length <= 3)
                  WeightChartPlaceholder(
                    message: "В истории слишком мало записей для отображения",
                  )
                else
                  Padding(
                    padding: EdgeInsetsGeometry.fromLTRB(5, 10, 10, 10),
                    child: SizedBox(
                      height: 200,
                      child: LineChart(
                        LineChartData(
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: true,
                            horizontalInterval: 1,
                            verticalInterval: 1,
                            getDrawingHorizontalLine: (value) {
                              return const FlLine(
                                color: ThemeColors.primary,
                                strokeWidth: 1,
                              );
                            },
                            getDrawingVerticalLine: (value) {
                              return const FlLine(
                                color: ThemeColors.primary,
                                strokeWidth: 1,
                              );
                            },
                          ),
                          borderData: FlBorderData(
                            show: true,
                            border: Border.all(color: ThemeColors.border),
                          ),
                          titlesData: FlTitlesData(
                            show: true,
                            rightTitles: const AxisTitles(),
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                reservedSize: 30,
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  final index = value.toInt();

                                  if (index >= entries.length || index == 0) {
                                    return const SizedBox();
                                  }

                                  final date = entries[index].date;

                                  return Text(
                                    "${date.day}.${date.month}",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  );
                                },
                              ),
                            ),
                            leftTitles: AxisTitles(
                              sideTitles: SideTitles(
                                reservedSize: 42,
                                showTitles: true,
                                interval: 1,
                                getTitlesWidget: (value, meta) {
                                  return Text(
                                    value.toStringAsFixed(1),
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleSmall,
                                  );
                                },
                              ),
                            ),
                          ),
                          minY:
                              entries.reduce((min, entry) {
                                return entry.weight < min.weight ? entry : min;
                              }).weight *
                              0.975,
                          lineBarsData: [
                            LineChartBarData(
                              spots: spots,
                              isCurved: true,
                              barWidth: 3,
                              gradient: LinearGradient(
                                colors: ThemeColors.gradientColors,
                              ),
                              dotData: FlDotData(show: true),
                              belowBarData: BarAreaData(
                                show: true,
                                gradient: LinearGradient(
                                  colors: ThemeColors.gradientColors
                                      .map(
                                        (color) => color.withValues(alpha: 0.3),
                                      )
                                      .toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class UpdateMoodModal extends StatefulWidget {
  final PetProfile profile;

  const UpdateMoodModal({super.key, required this.profile});

  @override
  State<UpdateMoodModal> createState() => _UpdateMoodModalState();
}

class _UpdateMoodModalState extends State<UpdateMoodModal> {
  WeightPeriod period = WeightPeriod.month;

  bool change = false;

  late MoodHistory history;
  PetMood? selectedMood;

  @override
  void initState() {
    super.initState();
    history = widget.profile.moodHistory;
  }

  List<FlSpot> buildSpots(List<MoodEntry> entries) {
    return List.generate(entries.length, (i) {
      return FlSpot(i.toDouble(), entries[i].mood.value.toDouble());
    });
  }

  void save() async {
    if (selectedMood != null) {
      await ProfileService().updateMoodHistory(
        MoodEntry(date: DateTime.now(), mood: selectedMood!),
      );
    }

    if (Navigator.of(context).mounted) {
      Navigator.of(context).pop(true);
    }
  }

  void close() {
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final entries = history.filterByPeriod(period);
    final spots = buildSpots(entries);

    return DraggableScrollableSheet(
      minChildSize: 0.40,
      maxChildSize: 0.50,
      snap: true,
      builder: (context, scrollController) {
        return Scaffold(
            floatingActionButton: Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: PetMood.values.map((mood) {
                final isSelected = selectedMood == mood;

                return GestureDetector(
                  onTap: () {
                    setState(() {
                      selectedMood = mood;
                      change = true;
                    });
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 65,
                    height: 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? ThemeColors.primary
                          : ThemeColors.primary.withValues(alpha: 0.1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          mood.icon,
                          size: 26,
                          color: isSelected
                              ? ThemeColors.background
                              : ThemeColors.border,
                        ),
                        Text(
                          mood.label,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleSmall!
                              .copyWith(
                            inherit: true,
                            fontSize: 9,
                            color: isSelected
                                ? ThemeColors.background
                                : ThemeColors.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
          body: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
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
                      onPressed: change ? save : null,
                    ),
                  ],
                ),
              ),

              Text(
                "Настроение питомца",
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
                segments: const [
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
                const WeightChartPlaceholder(
                  message: "История настроения пуста",
                )
              else if (entries.length <= 3)
                const WeightChartPlaceholder(
                  message: "Слишком мало записей для графика",
                )
              else
                Padding(
                  padding: const EdgeInsets.fromLTRB(5, 10, 10, 10),
                  child: SizedBox(
                    height: 200,
                    child: LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: true,
                          horizontalInterval: 1,
                          verticalInterval: 1,
                          getDrawingHorizontalLine: (value) {
                            return const FlLine(
                              color: ThemeColors.primary,
                              strokeWidth: 1,
                            );
                          },
                          getDrawingVerticalLine: (value) {
                            return const FlLine(
                              color: ThemeColors.primary,
                              strokeWidth: 1,
                            );
                          },
                        ),
                        borderData: FlBorderData(
                          show: true,
                          border: Border.all(color: ThemeColors.border),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          rightTitles: const AxisTitles(),
                          topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              reservedSize: 30,
                              showTitles: true,
                              getTitlesWidget: (value, meta) {
                                final index = value.toInt();

                                if (index >= entries.length || index == 0) {
                                  return const SizedBox();
                                }

                                final date = entries[index].date;

                                return Text(
                                  "${date.day}.${date.month}",
                                  style: Theme.of(context).textTheme.titleSmall,
                                );
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              reservedSize: 42,
                              showTitles: true,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                return Text(
                                  value.toInt().toString(),
                                  style: Theme.of(context).textTheme.titleSmall,
                                );
                              },
                            ),
                          ),
                        ),
                        minY: 1,
                        maxY: 5,
                        lineBarsData: [
                          LineChartBarData(
                            spots: spots,
                            isCurved: true,
                            barWidth: 3,
                            gradient: LinearGradient(
                              colors: ThemeColors.gradientColors,
                            ),
                            dotData: FlDotData(show: true),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                colors: ThemeColors.gradientColors
                                    .map((c) => c.withValues(alpha: 0.3))
                                    .toList(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 16),


            ],
          ),
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

class UpdateNotesModal extends StatefulWidget {
  const UpdateNotesModal({super.key});

  @override
  State<UpdateNotesModal> createState() => _UpdateNotesModalState();
}

class _UpdateNotesModalState extends State<UpdateNotesModal> {
  final TextEditingController _controller = TextEditingController();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;

  Future<void> _toggleListening() async {
    if (!_isListening) {
      bool available = await _speech.initialize();
      if (available) {
        setState(() => _isListening = true);
        _speech.listen(
          onResult: (result) {
            setState(() {
              _controller.text = result.recognizedWords;
              _controller.selection = TextSelection.fromPosition(
                TextPosition(offset: _controller.text.length),
              );
            });
          },
        );
      }
    } else {
      setState(() => _isListening = false);
      _speech.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _speech.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.3,
      minChildSize: 0.2,
      maxChildSize: 0.8,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade400,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: TextField(
                  controller: _controller,
                  maxLines: null,
                  expands: true,
                  scrollController: scrollController,
                  decoration: const InputDecoration(
                    hintText: 'Напишите заметку...',
                    border: InputBorder.none,
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: _toggleListening,
                    icon: Icon(_isListening ? Icons.mic : Icons.mic_none),
                  ),
                  ElevatedButton(
                    onPressed: _controller.text.isEmpty
                        ? null
                        : () {
                            ProfileService().addNote(_controller.text);
                            Navigator.pop(context, true);
                          },
                    child: const Text('Прикрепить'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}
