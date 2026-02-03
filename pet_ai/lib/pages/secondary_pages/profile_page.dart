import 'package:flutter/material.dart';

import 'package:intl/intl.dart';
import 'package:pet_ai/theme/app_styles.dart';

import '../../services/profile_service.dart';

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _weightController = TextEditingController();
  final _notesController = TextEditingController();

  DateTime? _birthDate;
  String _gender = 'Не указан';

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    setState(() => _loading = true);

    final profile = await ProfileService().loadProfile();
    _nameController.text = profile.name;
    _breedController.text = profile.breed;
    _weightController.text = profile.weightKg?.toString() ?? '';
    _notesController.text = profile.notes;
    _birthDate = profile.birthDate;
    _gender = profile.gender;
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    final weight = double.tryParse(_weightController.text.replaceAll(',', '.'));

    final profile = PetProfile(
      name: _nameController.text.trim(),
      breed: _breedController.text.trim(),
      birthDate: _birthDate,
      weightKg: weight,
      gender: _gender,
      notes: _notesController.text.trim(),
    );

    await ProfileService().saveProfile(profile);

    if (mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Профиль сохранён')));
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();
    final initial = _birthDate ?? DateTime(now.year - 1);
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
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

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Профиль питомца'),
        actions: [
          IconButton(
            onPressed: _saveProfile,
            icon: const Icon(Icons.save),
            tooltip: 'Сохранить',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Form(
                key: _formKey,
                child: ListView(
                  children: [
                    // --- Avatar / Фото (плейсхолдер) ---
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
                            ),
                            child: const Icon(
                              Icons.pets,
                              size: 60,
                              color: Colors.grey,
                            ),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: FloatingActionButton.small(
                              heroTag: 'edit_photo',
                              onPressed: () {
                                // TODO: добавить выбор/съём фото (image_picker и сохранение пути/байтов)
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Выбор фото: TODO'),
                                  ),
                                );
                              },
                              backgroundColor: secondaryColor,
                              child: const Icon(Icons.edit, size: 18),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // --- Name ---
                    TextFormField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'Имя питомца',
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) =>
                          v == null || v.trim().isEmpty ? 'Введите имя' : null,
                    ),
                    const SizedBox(height: 12),

                    // --- Breed ---
                    TextFormField(
                      controller: _breedController,
                      decoration: const InputDecoration(
                        labelText: 'Порода',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),

                    // --- Row: Birthdate & Weight ---
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _pickBirthDate,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 14),
                              child: Row(
                                children: [
                                  Text(_formatDate(_birthDate)),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextFormField(
                            controller: _weightController,
                            decoration: const InputDecoration(
                              labelText: 'Вес (кг)',
                              border: OutlineInputBorder(),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) return null;
                              final val = double.tryParse(
                                v.replaceAll(',', '.'),
                              );
                              if (val == null || val <= 0)
                                return 'Неверный вес';
                              return null;
                            },
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 12),

                    // --- Gender ---
                    DropdownButtonFormField<String>(
                      initialValue: _gender,
                      items: const [
                        DropdownMenuItem(
                          value: 'Не указан',
                          child: Text('Не указан'),
                        ),
                        DropdownMenuItem(
                          value: 'Мальчик',
                          child: Text('Мальчик'),
                        ),
                        DropdownMenuItem(
                          value: 'Девочка',
                          child: Text('Девочка'),
                        ),
                      ],
                      onChanged: (v) =>
                          setState(() => _gender = v ?? 'Не указан'),
                      decoration: const InputDecoration(
                        labelText: 'Пол',
                        border: OutlineInputBorder(),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // --- Notes ---
                    TextFormField(
                      controller: _notesController,
                      decoration: const InputDecoration(
                        labelText: 'Заметки',
                        border: OutlineInputBorder(),
                      ),
                      maxLines: 4,
                    ),

                    const SizedBox(height: 20)
                  ],
                ),
              ),
            ),
    );
  }
}
