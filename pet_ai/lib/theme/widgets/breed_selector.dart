import 'package:pet_ai/theme/widgets/draggable_bottom_sheet.dart';
import 'package:flutter/material.dart';

Future<String?> showBreedSelector(BuildContext context) async {
  final List<String> allBreeds = [
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
              allItems: allBreeds,
              hintText: 'Поиск породы...',
              leadingIcon: Icons.pets,
              scrollController: scrollController,
            ),
          );
        },
      );
    },
  );

  return result;
}