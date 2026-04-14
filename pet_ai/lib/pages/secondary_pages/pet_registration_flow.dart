import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:pet_ai/models/species.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/breed_selector.dart';
import 'package:pet_ai/theme/widgets/glass_card.dart';

class PetRegistrationFlow extends StatefulWidget {
  const PetRegistrationFlow({super.key});

  @override
  State<PetRegistrationFlow> createState() => _PetRegistrationFlowState();
}

class _PetRegistrationFlowState extends State<PetRegistrationFlow> {
  int _currentStep = 0;
  static const _totalSteps = 4;

  final PetProfile _profile = PetProfile();
  final _nameCtrl = TextEditingController();
  final _breedCtrl = TextEditingController();
  DateTime? _birthDate;
  Gender _gender = Gender.none;
  File? _profileImage;
  PetSpecies _selectedSpecies = BuiltInSpecies.other;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _breedCtrl.dispose();
    super.dispose();
  }

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

  void _nextStep() {
    if (_currentStep == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Введите имя питомца')));
      return;
    }
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep += 1);
    } else {
      _saveProfileAndFinish();
    }
  }

  void _prevStep() {
    if (_currentStep > 0) setState(() => _currentStep -= 1);
  }

  Future<void> _saveProfileAndFinish() async {
    _profile.name = _nameCtrl.text.trim();
    _profile.species = _selectedSpecies;
    _profile.breed = _breedCtrl.text.trim();
    _profile.birthDate = _birthDate;
    _profile.gender = _gender;
    _profile.profileImage = _profileImage;

    await ProfileService().saveProfile(_profile);
    await ProfileService().setActiveProfile(_profile.id);
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/');
    }
  }

  InputDecoration _input(String label, {Widget? suffixIcon}) {
    return InputDecoration(
      labelText: label,
      labelStyle: Theme.of(context).textTheme.bodyLarge,
      filled: true,
      fillColor: ThemeColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      suffixIcon: suffixIcon,
    );
  }

  Widget _buildStepContent() {
    switch (_currentStep) {
      case 0:
        return _StepBasic(
          nameCtrl: _nameCtrl,
          breedCtrl: _breedCtrl,
          selectedSpecies: _selectedSpecies,
          onSpeciesChanged: (v) => setState(() => _selectedSpecies = v),
          inputDecoration: _input,
        );
      case 1:
        return _StepDetails(
          birthDate: _birthDate,
          gender: _gender,
          formatDate: _formatDate,
          onPickDate: _pickBirthDate,
          onGenderChanged: (g) => setState(() => _gender = g),
          inputDecoration: _input,
        );
      case 2:
        return _StepPhoto(
          profileImage: _profileImage,
          profileId: _profile.id,
          onImagePicked: (file) => setState(() => _profileImage = file),
        );
      case 3:
        return _StepSummary(
          name: _nameCtrl.text,
          species: _selectedSpecies,
          breed: _breedCtrl.text,
          birthDate: _formatDate(_birthDate),
          gender: _gender,
          profileImage: _profileImage,
        );
      default:
        return const SizedBox();
    }
  }

  @override
  Widget build(BuildContext context) {
    final stepTitles = ['Основное', 'Данные', 'Фото', 'Готово'];

    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: pageGradientDecoration,
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 16, 0),
                child: Row(
                  children: [
                    if (_currentStep > 0)
                      IconButton(
                        icon: const Icon(Icons.arrow_back),
                        color: ThemeColors.textPrimary,
                        onPressed: _prevStep,
                      )
                    else
                      const SizedBox(width: 48),
                    Expanded(
                      child: Text(
                        stepTitles[_currentStep],
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    const SizedBox(width: 48),
                  ],
                ),
              ),

              // Step indicator
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 40,
                  vertical: 16,
                ),
                child: Row(
                  children: List.generate(_totalSteps, (i) {
                    return Expanded(
                      child: Container(
                        height: 4,
                        margin: const EdgeInsets.symmetric(horizontal: 3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(2),
                          color: i <= _currentStep
                              ? ThemeColors.primary
                              : ThemeColors.primary.withAlpha(51),
                        ),
                      ),
                    );
                  }),
                ),
              ),

              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: SingleChildScrollView(
                    key: ValueKey(_currentStep),
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: _buildStepContent(),
                  ),
                ),
              ),

              // Bottom buttons
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 16),
                child: SizedBox(
                  width: double.infinity,
                  child: _currentStep == _totalSteps - 1
                      ? GlassCard(
                          color: ThemeColors.primary,
                          callback: _saveProfileAndFinish,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.check,
                                  color: ThemeColors.white,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'Завершить и сохранить',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        color: ThemeColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        )
                      : GlassCard(
                          color: ThemeColors.primary,
                          callback: _nextStep,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 6),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'Далее',
                                  style: Theme.of(context).textTheme.bodyMedium!
                                      .copyWith(
                                        color: ThemeColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(width: 6),
                                const Icon(
                                  Icons.arrow_forward,
                                  color: ThemeColors.white,
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 0: Name, Species, Breed ──────────────────────────────────────────

class _StepBasic extends StatelessWidget {
  final TextEditingController nameCtrl;
  final TextEditingController breedCtrl;
  final PetSpecies selectedSpecies;
  final ValueChanged<PetSpecies> onSpeciesChanged;
  final InputDecoration Function(String, {Widget? suffixIcon}) inputDecoration;

  const _StepBasic({
    required this.nameCtrl,
    required this.breedCtrl,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        TextField(
          controller: nameCtrl,
          decoration: inputDecoration('Имя питомца'),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<PetSpecies>(
          decoration: inputDecoration('Вид'),
          dropdownColor: ThemeColors.white,
          items: BuiltInSpecies.all
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(
                    '${s.emoji} ${s.name}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                ),
              )
              .toList(),
          onChanged: (v) {
            if (v != null) onSpeciesChanged(v);
          },
        ),
        const SizedBox(height: 12),
        GestureDetector(
          onTap: () async {
            final result = await showBreedSelector(context);
            if (result != null && result.isNotEmpty) {
              breedCtrl.text = result;
            }
          },
          child: AbsorbPointer(
            child: TextField(
              controller: breedCtrl,
              decoration: inputDecoration(
                'Порода',
                suffixIcon: const Icon(Icons.arrow_drop_down),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Step 1: Birth date, Gender ────────────────────────────────────────────

class _StepDetails extends StatelessWidget {
  final DateTime? birthDate;
  final Gender gender;
  final String Function(DateTime?) formatDate;
  final VoidCallback onPickDate;
  final ValueChanged<Gender> onGenderChanged;
  final InputDecoration Function(String, {Widget? suffixIcon}) inputDecoration;

  const _StepDetails({
    required this.birthDate,
    required this.gender,
    required this.formatDate,
    required this.onPickDate,
    required this.onGenderChanged,
    required this.inputDecoration,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        GestureDetector(
          onTap: onPickDate,
          child: AbsorbPointer(
            child: TextField(
              decoration: inputDecoration(
                'Дата рождения',
                suffixIcon: Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: Icon(
                    Icons.calendar_today,
                    color: Theme.of(context).dividerColor,
                    size: 18,
                  ),
                ),
              ),
              controller: TextEditingController(text: formatDate(birthDate)),
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<Gender>(
          style: SegmentedButton.styleFrom(
            padding: const EdgeInsets.all(12),
            side: const BorderSide(style: BorderStyle.none),
            backgroundColor: ThemeColors.white,
            foregroundColor: Theme.of(context).dividerColor,
            selectedForegroundColor: Theme.of(context).colorScheme.surface,
            selectedBackgroundColor: Theme.of(context).colorScheme.primary,
          ),
          segments: const <ButtonSegment<Gender>>[
            ButtonSegment(
              value: Gender.male,
              label: Text("Мальчик"),
              icon: Icon(Icons.male),
            ),
            ButtonSegment(
              value: Gender.female,
              label: Text("Девочка"),
              icon: Icon(Icons.female),
            ),
          ],
          selected: {gender},
          onSelectionChanged: (v) => onGenderChanged(v.first),
        ),
      ],
    );
  }
}

// ─── Step 2: Photo ─────────────────────────────────────────────────────────

class _StepPhoto extends StatelessWidget {
  final File? profileImage;
  final String profileId;
  final ValueChanged<File> onImagePicked;

  const _StepPhoto({
    required this.profileImage,
    required this.profileId,
    required this.onImagePicked,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      children: [
        const SizedBox(height: 32),
        Center(
          child: GestureDetector(
            onTap: () async {
              final path = await ProfileService().pickProfileImage(profileId);
              if (path != null) {
                onImagePicked(File(path));
              }
            },
            child: Stack(
              children: [
                Container(
                  width: 160,
                  height: 160,
                  decoration: BoxDecoration(
                    border: Border.all(color: ThemeColors.primary, width: 4),
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        theme.colorScheme.primary.withAlpha(64),
                        theme.colorScheme.primary.withAlpha(2),
                      ],
                    ),
                  ),
                  child: ClipOval(
                    child: profileImage == null
                        ? const Icon(
                            Icons.pets,
                            size: 70,
                            color: ThemeColors.primary,
                          )
                        : Image.file(profileImage!, fit: BoxFit.cover),
                  ),
                ),
                Positioned(
                  bottom: 4,
                  right: 4,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.camera_alt,
                      size: 20,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          profileImage == null
              ? 'Нажмите, чтобы выбрать фото'
              : 'Нажмите, чтобы заменить',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

// ─── Step 3: Summary ───────────────────────────────────────────────────────

class _StepSummary extends StatelessWidget {
  final String name;
  final PetSpecies species;
  final String breed;
  final String birthDate;
  final Gender gender;
  final File? profileImage;

  const _StepSummary({
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.profileImage,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 16),
        if (profileImage != null)
          CircleAvatar(radius: 50, backgroundImage: FileImage(profileImage!))
        else
          CircleAvatar(
            radius: 50,
            backgroundColor: ThemeColors.primary.withAlpha(51),
            child: const Icon(Icons.pets, size: 40, color: ThemeColors.primary),
          ),
        const SizedBox(height: 20),
        GlassPlate(
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                _summaryRow(
                  context,
                  Icons.pets,
                  'Имя',
                  name.isEmpty ? 'не указано' : name,
                ),
                _summaryRow(
                  context,
                  Icons.category,
                  'Вид',
                  '${species.emoji} ${species.name}',
                ),
                _summaryRow(
                  context,
                  Icons.badge,
                  'Порода',
                  breed.isEmpty ? 'не указана' : breed,
                ),
                _summaryRow(context, Icons.cake, 'Дата рождения', birthDate),
                _summaryRow(
                  context,
                  gender.icon ?? Icons.help_outline,
                  'Пол',
                  gender.label,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _summaryRow(
    BuildContext context,
    IconData icon,
    String label,
    String value,
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ThemeColors.primary),
          const SizedBox(width: 12),
          Text(label, style: Theme.of(context).textTheme.bodySmall),
          const Spacer(),
          Text(value, style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }
}
