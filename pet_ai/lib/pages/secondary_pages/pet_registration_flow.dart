import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../services/profile_service.dart';
import '../../theme/widgets/draggable_bottom_sheet.dart';

class PetRegistrationFlow extends StatefulWidget {
  final VoidCallback onComplete;
  const PetRegistrationFlow({super.key, required this.onComplete});

  @override
  State<PetRegistrationFlow> createState() => _PetRegistrationFlowState();
}

class _PetRegistrationFlowState extends State<PetRegistrationFlow> {
  int _currentStep = 0;

  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  DateTime? _birthDate;
  final _weightCtrl = TextEditingController();
  String _gender = 'Не указан';
  final _notesCtrl = TextEditingController();

  Future<void> _showBreedSelector() async {
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
      backgroundColor:
          Colors.transparent,
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

    if (result != null && result.isNotEmpty) {
      setState(() {
        _breedCtrl.text = result;
      });
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime(now.year - 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Не указано';
    return DateFormat('dd.MM.yyyy').format(d);
  }

  Future<void> _saveProfileAndFinish() async {
    // Простая валидация
    if (_nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите имя питомца')));
      return;
    }

    final profile = PetProfile(
      name: _nameCtrl.text.trim(),
      breed: _breedCtrl.text.trim(),
      birthDate: _birthDate,
      weightKg: double.tryParse(_weightCtrl.text.replaceAll(',', '.')),
      gender: _gender,
      notes: _notesCtrl.text.trim(),
    );

    await ProfileService().saveProfile(profile);

    widget.onComplete();
  }

  List<Step> _buildSteps() {
    return [
      Step(
        title: const Text('Основное'),
        content: Column(
          children: [
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(labelText: 'Имя'),
            ),
            const SizedBox(height: 8),

            GestureDetector(
              onTap: _showBreedSelector,
              child: AbsorbPointer(
                child: TextField(
                  controller: _breedCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Порода',
                    suffixIcon: Icon(Icons.arrow_drop_down),
                  ),
                ),
              ),
            ),

            // DropdownButtonFormField<String>(
            //   items: const [
            //     DropdownMenuItem(value: 'Не указана', child: Text('Не указана')),
            //     DropdownMenuItem(value: 'Корги', child: Text('Корги')),
            //     DropdownMenuItem(value: 'Сиба-ину', child: Text('Сиба-ину')),
            //   ],
            //   onChanged: (v) => setState(() => _breedCtrl.text = v ?? 'Не указан'),
            //   decoration: const InputDecoration(labelText: 'Порода'),
            // ),
          ],
        ),
        isActive: _currentStep >= 0,
      ),
      Step(
        title: const Text('Данные'),
        content: Column(
          children: [
            OutlinedButton.icon(
              onPressed: _pickBirthDate,
              icon: const Icon(Icons.calendar_today),
              label: Text('Дата рождения: ${_formatDate(_birthDate)}'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _weightCtrl,
              decoration: const InputDecoration(labelText: 'Вес (кг)'),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              items: const [
                DropdownMenuItem(value: 'Не указан', child: Text('Не указан')),
                DropdownMenuItem(value: 'Мальчик', child: Text('Мальчик')),
                DropdownMenuItem(value: 'Девочка', child: Text('Девочка')),
              ],
              onChanged: (v) => setState(() => _gender = v ?? 'Не указан'),
              decoration: const InputDecoration(labelText: 'Пол'),
            ),
          ],
        ),
        isActive: _currentStep >= 1,
      ),
      Step(
        title: const Text('Дополнительно'),
        content: Column(
          children: [
            // Фото можно реализовать отдельно; пока заглушка
            const Text('Фото питомца можно добавить позже'),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(labelText: 'Заметки'),
              maxLines: 3,
            ),
          ],
        ),
        isActive: _currentStep >= 2,
      ),
      Step(
        title: const Text('Готово'),
        content: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Имя: ${_nameCtrl.text}'),
            Text('Порода: ${_breedCtrl.text}'),
            Text('Дата рождения: ${_formatDate(_birthDate)}'),
            Text('Вес: ${_weightCtrl.text}'),
            Text('Пол: $_gender'),
            const SizedBox(height: 12),
          ],
        ),
        isActive: _currentStep >= 3,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Регистрация питомца')),
      body: Stepper(
        currentStep: _currentStep,
        onStepContinue: () {
          if (_currentStep < _buildSteps().length - 1) {
            setState(() => _currentStep += 1);
          } else {
            _saveProfileAndFinish();
          }
        },
        onStepCancel: () {
          if (_currentStep > 0) setState(() => _currentStep -= 1);
        },
        steps: _buildSteps(),
        controlsBuilder: (context, details) {
          return Padding(
            padding: EdgeInsetsGeometry.only(left: 8, top: 8),
            child: Row(
              children: [
                if (_currentStep == 3)
                  ElevatedButton.icon(
                    onPressed: _saveProfileAndFinish,
                    icon: const Icon(Icons.check),
                    label: const Text('Завершить и сохранить'),
                  ),
                if (_currentStep <= 2)
                  ElevatedButton(
                    onPressed: details.onStepContinue,
                    child: const Text('Далее'),
                  ),
                const SizedBox(width: 8),
                if (_currentStep > 0)
                  TextButton(
                    onPressed: details.onStepCancel,
                    child: const Text('Назад'),
                  ),
              ],
            ),
          );
        },
      ),
    );
  }
}
