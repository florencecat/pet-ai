import 'package:flutter/material.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/theme/widgets/draggable_bottom_sheet.dart';

/// Generic bottom-sheet selector backed by [DraggableBottomSheet].
///
/// Returns the chosen id, or `null` if the user dismissed without selecting.
Future<String?> showItemSelector(
  BuildContext context, {
  required Map<String, String> items,
  required String hintText,
  IconData leadingIcon = Icons.list,
  Future<String?> Function()? onAddCustomItem,
  String addCustomItemLabel = 'Добавить свой вариант',
}) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (context) {
      return DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: DraggableBottomSheet(
              allItems: items,
              hintText: hintText,
              scrollController: scrollController,
              onAddCustomItem: onAddCustomItem,
              addCustomItemLabel: addCustomItemLabel,
            ),
          );
        },
      );
    },
  );
  return result;
}

/// Convenience wrapper: breed selector with custom-breed support.
Future<String?> showBreedSelector(
  BuildContext context,
  PetSpecies species,
) async {
  final customBreeds = await PetBreedService.loadCustomBreeds(species.id);
  final allBreeds = [
    ...PetBreedService.breedsBySpecies(species),
    ...customBreeds,
  ];

  if (!context.mounted) return null;

  return showItemSelector(
    context,
    items: Map.fromEntries(allBreeds.map((b) => MapEntry(b.id, b.name))),
    hintText: 'Поиск породы...',
    leadingIcon: Icons.pets,
    addCustomItemLabel: 'Добавить свою породу',
    onAddCustomItem: () => _showAddCustomBreedSheet(context, species.id),
  );
}

Future<String?> _showAddCustomBreedSheet(
  BuildContext context,
  String speciesId,
) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _AddCustomBreedSheet(speciesId: speciesId),
  );
}

class _AddCustomBreedSheet extends StatefulWidget {
  final String speciesId;

  const _AddCustomBreedSheet({required this.speciesId});

  @override
  State<_AddCustomBreedSheet> createState() => _AddCustomBreedSheetState();
}

class _AddCustomBreedSheetState extends State<_AddCustomBreedSheet> {
  final _ctrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final name = _ctrl.text.trim();
    if (name.isEmpty) return;
    setState(() => _saving = true);
    final breed = await PetBreedService.saveCustomBreed(widget.speciesId, name);
    if (mounted) Navigator.pop(context, breed.id);
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(color: Colors.black26, blurRadius: 10, offset: Offset(0, -2)),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 50,
              height: 5,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Добавить свою породу',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Название породы',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _confirm(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: _saving ? null : _confirm,
            child: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Сохранить'),
          ),
        ],
      ),
    );
  }
}
