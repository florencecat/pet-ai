import 'package:flutter/material.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/theme/widgets/swipeable_event_card.dart';

class EventPreviewBlock extends StatelessWidget {
  final List<PetEvent> events;
  final void Function(PetEvent event) onTap;
  final void Function(DateTime date) onOpenCalendar;
  final void Function(PetEvent event)? onEdit;
  final void Function(PetEvent event)? onDelete;

  /// Callback for the completion checkbox. When provided, a checkbox is shown
  /// on each card; when the user taps it the event is toggled.
  final void Function(PetEvent event, bool completed)? onCompletedChanged;

  const EventPreviewBlock({
    super.key,
    required this.events,
    required this.onTap,
    required this.onOpenCalendar,
    this.onEdit,
    this.onDelete,
    this.onCompletedChanged,
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
              const SizedBox(height: 12),
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
        return SwipeableEventCard(
          event: event,
          onTap: () => onTap(event),
          onEdit: onEdit != null ? () => onEdit!(event) : null,
          onDelete: onDelete != null ? () => onDelete!(event) : null,
          trailingCallback: () => onOpenCalendar(event.dateTime),
          onCompletedChanged: onCompletedChanged != null
              ? (val) => onCompletedChanged!(event, val)
              : null,
        );
      }).toList(),
    );
  }
}
