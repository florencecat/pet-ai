import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/app_colors.dart';

class EventPreviewBlock extends StatelessWidget {
  final List<PetEvent> events;
  final void Function(PetEvent event) onTap;
  final void Function(DateTime date) onOpenCalendar;

  const EventPreviewBlock({
    super.key,
    required this.events,
    required this.onTap,
    required this.onOpenCalendar,
  });

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return SizedBox(
        height: MediaQuery.of(context).size.height * 0.35,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.pets_sharp,
                size: 86,
                color: Theme.of(context).colorScheme.primary.withAlpha(64),
              ),
              SizedBox(height: 12),
              Text(
                'Нет запланированных событий',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary.withAlpha(128),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: events.take(4).map((event) {
        return Card.outlined(
          clipBehavior: Clip.antiAlias,
          shape: cardBorder,
          child: InkWell(
            splashColor: Colors.blue.withAlpha(50),
            onTap: () => onTap(event),
            child: ListTile(
              leading: Icon(event.category.icon, color: event.category.color),
              title: Text(
                event.name,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              subtitle: Text(
                DateFormat('dd.MM.yyyy – HH:mm').format(event.dateTime),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              trailing: IconButton(
                onPressed: () => onOpenCalendar(event.dateTime),
                icon: const Icon(Icons.chevron_right),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}
