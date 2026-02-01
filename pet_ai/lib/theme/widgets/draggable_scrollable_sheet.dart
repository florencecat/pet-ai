import 'package:flutter/material.dart';
import 'package:pet_ai/theme/app_styles.dart';

import '../../services/event_service.dart';

enum EventSheetMode { view, create, edit }

final DraggableScrollableController _sheetController =
    DraggableScrollableController();

void collapseSheet() {
  _sheetController.animateTo(
    0.45,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeOutCubic,
  );
}

void expandSheet() {
  _sheetController.animateTo(
    0.9,
    duration: const Duration(milliseconds: 350),
    curve: Curves.easeOutCubic,
  );
}

void closeSheet(BuildContext context) {
  Navigator.of(context).pop();
}

Future<void> deleteEvent(BuildContext context, PetEvent event) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Очистить данные?'),
      content: const Text(
        'Будут удалены все данные питомца, события и настройки. '
        'Приложение будет выглядеть как при первом запуске.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Отмена'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: Colors.red),
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Очистить'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  await EventService().deleteEvent(event);

  if (context.mounted) {
    closeSheet(context);
  }
}

extension EventSheetModeX on EventSheetMode {
  bool get isView => this == EventSheetMode.view;
  bool get isEdit => this == EventSheetMode.edit;
  bool get isCreate => this == EventSheetMode.create;

  bool get isEditable => isEdit || isCreate;
}

class EventDraggableSheet extends StatelessWidget {
  final EventSheetMode mode;
  final PetEvent? event;

  const EventDraggableSheet({super.key, required this.mode, this.event});

  static const double _deleteButtonHeight = 64;

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      controller: _sheetController,
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.85,
      snap: true,
      snapSizes: const [0.45, 0.85],
      builder: (context, scrollController) {
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Stack(
            children: [
              /// SCROLLABLE CONTENT
              ShowEventSheetContent(
                mode: mode,
                event: event,
                scrollController: scrollController,
                bottomPadding: _deleteButtonHeight + 16,
              ),

              // /// STICKY DELETE BUTTON
              // _StickyButton(
              //   onPressed: () {
              //     // confirm delete
              //   },
              // ),
            ],
          ),
        );
      },
    );
  }
}

class ShowEventSheetContent extends StatelessWidget {
  final EventSheetMode mode;
  final PetEvent? event;
  final ScrollController scrollController;
  final double bottomPadding;

  const ShowEventSheetContent({
    super.key,
    required this.mode,
    this.event,
    required this.scrollController,
    required this.bottomPadding,
  });

  @override
  Widget build(BuildContext context) {
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        // DRAG HANDLE
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
                color: mainColor,
                onPressed: () => closeSheet(context),
              ),
              const Spacer(),
              if (EventSheetModeX(mode).isView)
                IconButton(
                  icon: const Icon(Icons.edit),
                  color: mainColor,
                  onPressed: () {},
                ),
              if (EventSheetModeX(mode).isView)
                IconButton(
                  icon: const Icon(Icons.delete),
                  color: dangerColor,
                  onPressed: () => deleteEvent(context, event!)
                ),
              if (EventSheetModeX(mode).isEditable)
                IconButton(
                  icon: const Icon(Icons.check),
                  color: mainColor,
                  onPressed: () => closeSheet(context),
                ),
            ],
          ),
        ),

        if (EventSheetModeX(mode).isEditable)
          TextFormField(
            controller: TextEditingController(),
            decoration: const InputDecoration(labelText: 'Название'),
            validator: (v) =>
                v == null || v.isEmpty ? 'Введите название' : null,
          )
        else
          Text(
            textAlign: TextAlign.center,
            event?.name ?? "",
            style: Theme.of(context).textTheme.headlineSmall,
          ),

        const SizedBox(height: 8),

        if (EventSheetModeX(mode).isEditable)
          TextFormField(
            controller: TextEditingController(),
            decoration: const InputDecoration(labelText: 'Категория'),
            validator: (v) =>
                v == null || v.isEmpty ? 'Введите категорию' : null,
          )
        else
          Text(
            textAlign: TextAlign.center,
            event?.name ?? "",
            style: Theme.of(context).textTheme.bodyLarge,
          ),

        const SizedBox(height: 8),

        if (EventSheetModeX(mode).isEditable)
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(
                    "Выбрать дату",
                    // _selectedDate == null
                    //     ? ''
                    //     : '${_selectedDate!.day}.${_selectedDate!.month}.${_selectedDate!.year}',
                  ),
                  onPressed: () {},
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.access_time),
                  label: Text(
                    "Выбрать время",
                    // _selectedTime == null
                    //     ? 'Выбрать время'
                    //     : _selectedTime!.format(context),
                  ),
                  onPressed: () {},
                ),
              ),
            ],
          )
        else
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.event, size: 18, color: Colors.grey.shade600),
              const SizedBox(width: 6),
              Text(event?.dateTime.toString() ?? ""),
            ],
          ),

        // Text(
        //   event.description ?? 'Без описания',
        //   style: Theme.of(context).textTheme.bodyMedium,
        // ),
      ],
    );
  }
}

class _StickyButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _StickyButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: 16,
      right: 16,
      bottom: 16 + MediaQuery.of(context).padding.bottom,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 48,
          child: OutlinedButton.icon(
            onPressed: onPressed,
            icon: const Icon(Icons.delete_outline),
            label: const Text('Удалить'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.red,
              side: const BorderSide(color: Colors.red),
            ),
          ),
        ),
      ),
    );
  }
}
