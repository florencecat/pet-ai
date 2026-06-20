import 'package:flutter/material.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/services/species_service.dart';
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
Future<PetBreed?> showBreedSelector(
  BuildContext context,
  PetSpecies species,
) async {
  final customBreeds = await PetBreedService.loadCustomBreeds(species.id);
  final allBreeds = [
    ...PetBreedService.breedsBySpecies(species),
    ...customBreeds,
  ];

  if (!context.mounted) return null;

  final id = await showItemSelector(
    context,
    items: Map.fromEntries(allBreeds.map((b) => MapEntry(b.id, b.name))),
    hintText: 'Поиск породы...',
    leadingIcon: Icons.pets,
    addCustomItemLabel: 'Добавить свою породу',
    onAddCustomItem: () => _showAddCustomBreedSheet(context, species.id),
  );
  if (id == null) return null;
  return PetBreedService.breedByIdIncludingCustom(species, id);
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

/// Species selector with custom-species support.
Future<PetSpecies?> showSpeciesSelector(BuildContext context) async {
  final customSpecies = await SpeciesService.loadCustomSpecies();
  final allSpecies = [...BuiltInSpecies.all, ...customSpecies];

  if (!context.mounted) return null;

  final id = await showItemSelector(
    context,
    items: Map.fromEntries(
      allSpecies.map(
        (s) => MapEntry(s.id, s.emoji.isEmpty ? s.name : '${s.emoji} ${s.name}'),
      ),
    ),
    hintText: 'Поиск вида...',
    leadingIcon: Icons.category_outlined,
    addCustomItemLabel: 'Добавить свой вид',
    onAddCustomItem: () => _showAddCustomSpeciesSheet(context),
  );
  if (id == null) return null;
  return SpeciesService.speciesByIdIncludingCustom(id);
}

Future<String?> _showAddCustomSpeciesSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => const _AddCustomSpeciesSheet(),
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
  Widget build(BuildContext context) => _AddCustomNameSheet(
    title: 'Добавить свою породу',
    hint: 'Название породы',
    controller: _ctrl,
    saving: _saving,
    onConfirm: _confirm,
  );
}

class _AddCustomSpeciesSheet extends StatefulWidget {
  const _AddCustomSpeciesSheet();

  @override
  State<_AddCustomSpeciesSheet> createState() => _AddCustomSpeciesSheetState();
}

class _AddCustomSpeciesSheetState extends State<_AddCustomSpeciesSheet> {
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
    final species = await SpeciesService.saveCustomSpecies(name);
    if (mounted) Navigator.pop(context, species.id);
  }

  @override
  Widget build(BuildContext context) => _AddCustomNameSheet(
    title: 'Добавить свой вид',
    hint: 'Название вида',
    controller: _ctrl,
    saving: _saving,
    onConfirm: _confirm,
  );
}

class _AddCustomNameSheet extends StatelessWidget {
  final String title;
  final String hint;
  final TextEditingController controller;
  final bool saving;
  final VoidCallback onConfirm;

  const _AddCustomNameSheet({
    required this.title,
    required this.hint,
    required this.controller,
    required this.saving,
    required this.onConfirm,
  });

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
            title,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: hint,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => onConfirm(),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: saving ? null : onConfirm,
            child: saving
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
