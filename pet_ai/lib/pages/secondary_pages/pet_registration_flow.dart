import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pet_ai/models/species.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/breed_selector.dart';

class PetRegistrationFlow extends StatefulWidget {
  const PetRegistrationFlow({super.key});

  @override
  State<PetRegistrationFlow> createState() => _PetRegistrationFlowState();
}

class _PetRegistrationFlowState extends State<PetRegistrationFlow> {
  int _currentStep = 0;

  final PetProfile _profile = PetProfile();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  DateTime? _birthDate;
  Gender _gender = Gender.none;
  File? _profileImage;
  final _notesCtrl = TextEditingController();
  PetSpecies _selectedSpecies = BuiltInSpecies.other;

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _birthDate ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _birthDate = picked);
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'не указана';
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

    _profile.name = _nameCtrl.text.trim();
    _profile.species = _selectedSpecies;
    _profile.breed = _breedCtrl.text.trim();
    _profile.birthDate = _birthDate;
    _profile.gender = _gender;
    _profile.notes = _notesCtrl.text.trim();
    _profile.profileImage = _profileImage;

    await ProfileService().saveProfile(_profile);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
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

            DropdownButtonFormField<PetSpecies>(
              initialValue: _selectedSpecies,
              decoration: const InputDecoration(labelText: 'Вид'),
              items: BuiltInSpecies.all.map((s) => DropdownMenuItem(
                value: s,
                child: Text('${s.emoji} ${s.name}'),
              )).toList(),
              onChanged: (v) {
                if (v != null) setState(() => _selectedSpecies = v);
              },
            ),

            const SizedBox(height: 8),

            GestureDetector(
              onTap: () async {
                final result = await showBreedSelector(context);
                if (result != null && result.isNotEmpty) {
                  setState(() {
                    _breedCtrl.text = result;
                  });
                }
              },
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
            DropdownButtonFormField<String>(
              items: Gender.values.map((g) => DropdownMenuItem(value: g.caption, child: Text(g.label))).toList(),
              onChanged: (v) => setState(() => _gender = Gender.values.firstWhere((g)=> g.caption == v)),
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
            Center(
              child: Stack(
                alignment: Alignment.bottomRight,
                children: [
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: Colors.grey.shade200,
                      shape: BoxShape.circle,
                      border: Border.all(color: ThemeColors.border, width: 4),
                    ),
                    child: _profileImage == null
                        ? const Icon(Icons.pets, size: 60, color: Colors.grey)
                        : CircleAvatar(
                            radius: 26,
                            backgroundImage: FileImage(_profileImage!),
                          ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: FloatingActionButton.small(
                      heroTag: 'edit_photo',
                      onPressed: () async {
                        final path = await ProfileService().pickProfileImage(_profile.id);
                        if (path != null) {
                          setState(() {
                            _profileImage = File(path);
                          });
                        }
                      },
                      backgroundColor: Theme.of(context).colorScheme.primary,
                      child: const Icon(Icons.edit, size: 18),
                    ),
                  ),
                ],
              ),
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
            Text('Имя: ${_nameCtrl.text.isEmpty ? "не указано" : _nameCtrl.text}'),
            Text('Вид: ${_selectedSpecies.name}'),
            Text('Порода: ${_breedCtrl.text.isEmpty ? "не указано" : _breedCtrl.text}'),
            Text('Дата рождения: ${_formatDate(_birthDate)}'),
            Text('Пол: ${_gender.label.toLowerCase()}'),
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
