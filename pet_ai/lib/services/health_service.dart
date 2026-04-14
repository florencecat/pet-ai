import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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


