import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:pet_ai/services/profile_service.dart';
import 'package:pet_ai/theme/widgets/breed_selector.dart';

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  PetProfile? _profile;

  final _formKey = GlobalKey<FormState>();

  final _dateFormat = 'd MMMM yyyy';
  final _locale = 'ru-RU';

  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _dateController = TextEditingController();
  final _notesController = TextEditingController();

  Gender _gender = Gender.none;
  File? _profileImage;

  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ProfileService().loadActiveProfile();

    if (profile == null) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed("/registration");
      }
      return;
    }

    _profile = profile;
    _nameController.text = _profile!.name;
    _breedController.text = _profile!.breed;
    _dateController.text = _formatDate(_profile!.birthDate);
    _gender = _profile!.gender;
    _profileImage = _profile!.profileImage;

    if (mounted) setState(() => _loading = false);
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    _profile!.name = _nameController.text.trim();
    _profile!.breed = _breedController.text.trim();
    _profile!.birthDate = _parseDate(_dateController.text);
    _profile!.gender = _gender;
    _profile!.profileImage = _profileImage;

    await ProfileService().saveProfile(_profile!);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Профиль сохранён'),
          backgroundColor: ThemeColors.gradientEnd,
        ),
      );
    }
  }

  Future<void> _pickBirthDate() async {
    final now = DateTime.now();

    final picked = await showDatePicker(
      context: context,
      initialDate: _parseDate(_dateController.text) ?? DateTime(now.year - 1),
      firstDate: DateTime(2000),
      lastDate: DateTime(now.year + 5),
      locale: const Locale('ru'),
    );

    if (picked != null) {
      setState(() => _dateController.text = _formatDate(picked));
    }
  }

  String _formatDate(DateTime? d) {
    if (d == null) return 'Дата рождения';
    return DateFormat(_dateFormat, _locale).format(d);
  }

  DateTime? _parseDate(String? value) {
    if (value == null || value.isEmpty) return null;
    return DateFormat(_dateFormat, _locale).tryParse(value);
  }

  InputDecoration _input(String label) {
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: ThemeColors.white,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _breedController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _saveProfile,
        label: const Text('Сохранить'),
        icon: const Icon(Icons.check),
      ),
      body: Container(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : Form(
                key: _formKey,
                child: SafeArea(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      Center(
                        child: GestureDetector(
                          onTap: () async {
                            final path = await ProfileService()
                                .pickProfileImage(_profile!.id);
                            if (path != null) {
                              setState(() => _profileImage = File(path));
                            }
                          },
                          child: Stack(
                            children: [
                              Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  border: BoxBorder.all(
                                    color: ThemeColors.primary,
                                    width: 4,
                                  ),
                                  shape: BoxShape.circle,
                                  gradient: LinearGradient(
                                    colors: [
                                      theme.colorScheme.primary.withAlpha(64),
                                      theme.colorScheme.primary.withAlpha(2),
                                    ],
                                  ),
                                ),
                                child: ClipOval(
                                  child: _profileImage == null
                                      ? const Icon(Icons.pets, size: 50)
                                      : Image.file(
                                          _profileImage!,
                                          fit: BoxFit.cover,
                                        ),
                                ),
                              ),
                              Positioned(
                                bottom: 0,
                                right: 0,
                                child: Container(
                                  padding: const EdgeInsets.all(6),
                                  decoration: BoxDecoration(
                                    color: theme.dividerColor,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.edit,
                                    size: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 28),

                      TextFormField(
                        controller: _nameController,
                        decoration: _input('Имя питомца'),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Введите имя'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      GestureDetector(
                        onTap: () async {
                          final result = await showBreedSelector(context);
                          if (result != null && result.isNotEmpty) {
                            setState(() {
                              _breedController.text = result;
                            });
                          }
                        },
                        child: AbsorbPointer(
                          child: TextFormField(
                            controller: _breedController,
                            decoration: _input('Порода'),
                            validator: (v) => v == null || v.trim().isEmpty
                                ? 'Выберите породу'
                                : null,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),

                      TextFormField(
                        onTap: _pickBirthDate,
                        showCursor: false,
                        controller: _dateController,
                        decoration: InputDecoration(
                          labelText: "Дата рождения",
                          filled: true,
                          fillColor: ThemeColors.white,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(16),
                            borderSide: BorderSide.none,
                          ),
                          suffixIcon: Padding(
                            padding: EdgeInsetsGeometry.only(right: 6),
                            child: Icon(
                              Icons.calendar_today,
                              color: Theme.of(context).dividerColor,
                              size: 18,
                            ),
                          ),
                        ),
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Выберите дату'
                            : null,
                      ),

                      const SizedBox(height: 12),

                      SegmentedButton<Gender>(
                        style: SegmentedButton.styleFrom(
                          padding: EdgeInsetsGeometry.all(12),
                          side: BorderSide(style: BorderStyle.none),
                          backgroundColor: ThemeColors.white,
                          foregroundColor: Theme.of(context).dividerColor,
                          selectedForegroundColor: Theme.of(
                            context,
                          ).colorScheme.surface,
                          selectedBackgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary,
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
                        selected: <Gender>{_gender},
                        onSelectionChanged: (Set<Gender> newSelection) {
                          setState(() {
                            _gender = newSelection.first;
                          });
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
