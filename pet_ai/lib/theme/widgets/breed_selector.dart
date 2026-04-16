import 'package:flutter/material.dart';
import 'package:pet_ai/theme/widgets/draggable_bottom_sheet.dart';

/// Generic bottom-sheet selector backed by [DraggableBottomSheet].
///
/// Returns the chosen string, or `null` if the user dismissed without selecting.
Future<String?> showItemSelector(
  BuildContext context, {
  required List<String> items,
  required String hintText,
  IconData leadingIcon = Icons.list,
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
              leadingIcon: leadingIcon,
              scrollController: scrollController,
            ),
          );
        },
      );
    },
  );
  return result;
}

/// Convenience wrapper: breed selector.
Future<String?> showBreedSelector(BuildContext context) async {
  const allBreeds = [
    'Абиссинская',
    'Акита-ину',
    'Алабай',
    'Английский бульдог',
    'Бигль',
    'Бишон фризе',
    'Бордоский дог',
    'Вельш-корги пемброк',
    'Вельш-корги кардиган',
    'Доберман',
    'Йоркширский терьер',
    'Кане-корсо',
    'Лабрадор ретривер',
    'Мопс',
    'Немецкая овчарка',
    'Першерон',
    'Польская низинная овчарка',
    'Померанский шпиц',
    'Ретривер (золотистый)',
    'Русский той',
    'Самоед',
    'Сибирский хаски',
    'Такса',
    'Французский бульдог',
    'Чихуахуа',
    'Шпиц',
    'Ши-тцу',
    'Шнауцер',
  ];

  return showItemSelector(
    context,
    items: allBreeds,
    hintText: 'Поиск породы...',
    leadingIcon: Icons.pets,
  );
}
