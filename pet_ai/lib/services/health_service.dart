import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

class UpdateWeightModal extends StatefulWidget {
  const UpdateWeightModal({super.key});

  @override
  State<UpdateWeightModal> createState() => _UpdateWeightModalState();
}

class _UpdateWeightModalState extends State<UpdateWeightModal> {
  final controller = TextEditingController();

  late double weight;
  final List<FlSpot> weightHistory = const [
    FlSpot(0, 8),
    FlSpot(1, 8.2),
    FlSpot(2, 8.3),
    FlSpot(3, 8.5),
  ];

  @override
  void initState() {
    super.initState();
    weight = weightHistory.last.y;
  }


  void increase() {
    setState(() {
      weight = double.parse((weight + 0.1).toStringAsFixed(1));
    });
  }

  void decrease() {
    setState(() {
      weight = double.parse((weight - 0.1).toStringAsFixed(1));
    });
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return DraggableScrollableSheet(
      initialChildSize: 0.55,
      minChildSize: 0.50,
      maxChildSize: 0.55,
      snapSizes: const [0.50, 0.55],
      snap: true,
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: const BoxDecoration(
            color: Colors.white,
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
              Padding(
                padding: EdgeInsets.only(bottom: bottom),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  height: 420,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Обновить вес",
                        style: Theme.of(context).textTheme.titleLarge,
                      ),

                      const SizedBox(height: 20),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [

                          IconButton(
                            onPressed: decrease,
                            icon: const Icon(Icons.remove_circle),
                            color: Theme.of(context).dividerColor,
                            iconSize: 28,
                          ),

                          Container(
                            width: 80,
                            alignment: Alignment.center,
                            child: Text(
                              weight.toStringAsFixed(1),
                              style: Theme.of(context).textTheme.titleLarge!.copyWith(inherit: true, fontSize: 28),
                            ),
                          ),

                          IconButton(
                            onPressed: increase,
                            icon: const Icon(Icons.add_circle),
                            color: Theme.of(context).dividerColor,
                            iconSize: 28,
                          ),
                        ],
                      ),

                      const SizedBox(height: 20),

                      Text(
                        "История веса",
                        style: Theme.of(context).textTheme.titleMedium,
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: LineChart(
                          LineChartData(
                            borderData: FlBorderData(show: false),
                            gridData: FlGridData(show: true),
                            titlesData: FlTitlesData(show: false),
                            lineBarsData: [
                              LineChartBarData(
                                spots: weightHistory,
                                isCurved: true,
                                barWidth: 3,
                                dotData: FlDotData(show: true),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      SizedBox(
                        width: double.infinity,
                        child: TextButton(
                          onPressed: () {
                            final weight = double.tryParse(controller.text);
                            if (weight == null) return;

                            // TODO сохранить вес

                            Navigator.pop(context);
                          },
                          child: const Text("Сохранить"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
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
