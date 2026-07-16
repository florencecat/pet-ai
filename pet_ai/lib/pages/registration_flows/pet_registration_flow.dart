import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';
import 'package:image_picker/image_picker.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/pages/registration_flows/user_registration_flow.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/ai_service.dart';
import 'package:pet_satellite/services/authentification_service.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/widgets/breed_selector.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

// ─── Species display list ─────────────────────────────────────────────────────

class _SpeciesOption {
  final PetSpecies species;
  final String emoji;
  const _SpeciesOption(this.species, this.emoji);
}

const _kSpeciesOptions = [
  _SpeciesOption(BuiltInSpecies.dog, '🐕'),
  _SpeciesOption(BuiltInSpecies.cat, '🐈'),
  _SpeciesOption(BuiltInSpecies.rabbit, '🐇'),
  _SpeciesOption(BuiltInSpecies.other, '🐦'),
];

// ─── Widget helpers ───────────────────────────────────────────────────────────

Widget _card({required Widget child, EdgeInsets? padding, Color? color}) {
  return Container(
    padding: padding ?? const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: color ?? ThemeColors.white,
      borderRadius: BorderRadius.circular(20),
    ),
    child: child,
  );
}

// ─── Main flow widget ─────────────────────────────────────────────────────────

class PetRegistrationFlow extends StatefulWidget {
  const PetRegistrationFlow({super.key});

  @override
  State<PetRegistrationFlow> createState() => _PetRegistrationFlowState();
}

class _PetRegistrationFlowState extends State<PetRegistrationFlow> {
  int _step = 0;
  static const _totalSteps = 4;

  // Step 1
  final _nameCtrl = TextEditingController();
  PetSpecies _species = BuiltInSpecies.dog;
  bool _breedInputAvaliable = true;
  final _breedCtrl = TextEditingController();
  PetBreed _breed = PetBreed.empty();

  // Step 2
  DateTime? _birthDate;
  bool _unknownDate = false;
  Gender _gender = Gender.none;
  bool _castrated = false;

  // Step 3
  File? _photo;

  // Step 4 — необязательные доп. данные (собираются здесь, применяются в _finish)
  final _weightCtrl = TextEditingController();
  final _allergiesCtrl = TextEditingController();
  final _chronicCtrl = TextEditingController();
  final Set<TreatmentKind> _treatments = {};

  // Cloud restore / finish loading
  bool _isFinishing = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _weightCtrl.dispose();
    _allergiesCtrl.dispose();
    _chronicCtrl.dispose();
    super.dispose();
  }

  // ── Cloud restore ─────────────────────────────────────────────────────────

  /// Флоу «Восстановить из облака»:
  /// авторизация → проверка данных → fullRestore() → навигация на главный экран.
  /// Создание питомца пропускается — профиль восстанавливается с сервера.
  Future<void> _openRestoreFromCloud() async {
    final sync = CloudSyncService.instance;

    // 1. Авторизация (если ещё не выполнена).
    if (!sync.isAuthenticated) {
      final result = await Navigator.of(context).push<UserProfile?>(
        MaterialPageRoute(
          builder: (_) => const UserLoginPage(),
          fullscreenDialog: true,
        ),
      );
      if (result == null || !mounted) return; // пользователь отменил вход
    }

    if (!mounted) return;

    // 2. Проверяем, есть ли данные на сервере.
    final hasRemote = await sync.checkHasRemoteData();
    if (!mounted) return;

    if (!hasRemote) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Данных на сервере не найдено'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    // 3. Данные найдены — восстанавливаем немедленно.
    setState(() => _isFinishing = true);
    try {
      await sync.fullRestore();
      await AIChatController.restoreThreadsFromCloud();
      if (mounted) Navigator.pushReplacementNamed(context, '/');
    } catch (_) {
      if (mounted) {
        setState(() => _isFinishing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Не удалось загрузить данные с сервера'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _pickPhoto(ImageSource source) async {
    try {
      // Единый механизм выбора + кадрирования (как в редактировании профиля).
      final file = await PetProfileService().pickAndCropImage(source: source);
      if (file != null && mounted) {
        setState(() => _photo = file);
      }
    } catch (_) {}
  }

  void _next() {
    if (_step == 0 && _nameCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Введите кличку питомца'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }
    if (_step < _totalSteps - 1) {
      setState(() => _step++);
    } else {
      _finish();
    }
  }

  void _back() {
    if (_step > 0) setState(() => _step--);
  }

  Future<void> _finish() async {
    setState(() => _isFinishing = true);

    final profile = Pet(
      name: _nameCtrl.text.trim(),
      species: _species,
      breed: _breed,
      birthDate: _unknownDate ? null : _birthDate,
      gender: _gender,
      castrated: _castrated,
      profileImage: _photo,
    );

    // ── Необязательные доп. данные с финального шага ──────────────────────
    final weight = double.tryParse(
      _weightCtrl.text.trim().replaceAll(',', '.'),
    );
    if (weight != null && weight > 0) {
      profile.weightHistory.addWeight(weight);
    }

    final now = DateTime.now();
    for (final kind in _treatments) {
      // Отмеченные мероприятия считаем сделанными сегодня; следующую дату
      // рассчитываем по стандартному интервалу вида обработки.
      profile.treatmentHistory.add(
        TreatmentEntry(
          date: now,
          kind: kind,
          nextDate: now.add(kind.defaultInterval),
        ),
      );
    }

    profile.allergies = _allergiesCtrl.text.trim();
    profile.chronicConditions = _chronicCtrl.text.trim();

    // Переносим выбранное фото в постоянный каталог приложения (id уже есть).
    if (_photo != null) {
      try {
        final path = await PetProfileService().saveAvatar(profile.id, _photo!.path);
        profile.profileImage = File(path);
      } catch (_) {
        // Если не удалось — оставляем временный путь (не критично).
      }
    }

    await PetProfileService().saveProfile(profile);
    await PetProfileService().setActiveProfile(profile.id);

    // Push pet identity to cloud so it can be restored on a new device.
    // owner = id пользователя (createRule требует user = auth.id).
    final uid = CloudSyncService.instance.userId;
    if (uid != null) {
      CloudSyncService.instance.pushAsync('pets', profile, uid);
    }

    if (mounted) Navigator.pushReplacementNamed(context, '/');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: ThemeColors.background,
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _Header(
                  step: _step,
                  totalSteps: _totalSteps,
                  onBack: _step > 0 ? _back : null,
                  onClose: _step == 0 && Navigator.of(context).canPop()
                      ? () => Navigator.of(context).pop()
                      : null,
                ),
                Expanded(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 220),
                    transitionBuilder: (child, anim) => FadeTransition(
                      opacity: anim,
                      child: SlideTransition(
                        position:
                            Tween<Offset>(
                              begin: const Offset(0.04, 0),
                              end: Offset.zero,
                            ).animate(
                              CurvedAnimation(
                                parent: anim,
                                curve: Curves.easeOut,
                              ),
                            ),
                        child: child,
                      ),
                    ),
                    child: KeyedSubtree(
                      key: ValueKey(_step),
                      child: _buildStep(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Full-screen loading overlay while saving + pulling cloud data.
          if (_isFinishing)
            Positioned.fill(
              child: Container(
                color: Colors.black.withAlpha(60),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 24,
                    ),
                    decoration: BoxDecoration(
                      color: ThemeColors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: context
                              .read<AppearanceController>()
                              .secondaryColor,
                          strokeWidth: 3,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Загружаем данные с сервера…',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      case 0:
        return _Step1(
          nameCtrl: _nameCtrl,
          selectedSpecies: _species,
          onSpeciesChanged: (s) => setState(() {
            if (s != _species) {
              _species = s;
              _breed = PetBreed.empty();
              _breedInputAvaliable = _species != BuiltInSpecies.other;
            }
          }),
          breedInputAvaliable: _breedInputAvaliable,
          breedCtrl: _breedCtrl,
          selectedBreed: _breed,
          onBreedChanged: (b) => setState(() {
            if (b != _breed) {
              _breed = b;
              _breedCtrl.text = _breed.name;
            }
          }),
          popularBreeds: PetBreedService.popularBreedsBySpecies(_species),
          onNext: _next,
          onExit: () => Navigator.of(context).pop(),
          onRestore: _openRestoreFromCloud,
        );
      case 1:
        return _Step2(
          petName: _nameCtrl.text.trim(),
          birthDate: _birthDate,
          unknownDate: _unknownDate,
          gender: _gender,
          castrated: _castrated,
          onDateChanged: (d) => setState(() => _birthDate = d),
          onUnknownDate: (v) => setState(() {
            _unknownDate = v;
            if (v) _birthDate = null;
          }),
          onGenderChanged: (g) => setState(() => _gender = g),
          onCastratedChanged: (v) => setState(() => _castrated = v),
          onBack: _back,
          onNext: _next,
        );
      case 2:
        return _Step3(
          petName: _nameCtrl.text.trim(),
          photo: _photo,
          onPickPhoto: _pickPhoto,
          onBack: _back,
          onNext: _next,
        );
      case 3:
        return _Step4(
          petName: _nameCtrl.text.trim(),
          species: _species,
          breed: _breed,
          birthDate: _unknownDate ? null : _birthDate,
          gender: _gender,
          castrated: _castrated,
          photo: _photo,
          weightCtrl: _weightCtrl,
          allergiesCtrl: _allergiesCtrl,
          chronicCtrl: _chronicCtrl,
          treatments: _treatments,
          onTreatmentToggle: (kind) => setState(() {
            if (!_treatments.remove(kind)) _treatments.add(kind);
          }),
          onBack: _back,
          onFinish: _finish,
        );
      default:
        return const SizedBox.shrink();
    }
  }
}

// ─── Header with progress bar ─────────────────────────────────────────────────

class _Header extends StatelessWidget {
  final int step;
  final int totalSteps;
  final VoidCallback? onBack;
  final VoidCallback? onClose;

  const _Header({
    required this.step,
    required this.totalSteps,
    this.onBack,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final isLast = step == totalSteps - 1;
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 12, 16, 0),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  isLast ? 'Готово' : 'Новый питомец',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Progress segments
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: List.generate(totalSteps, (i) {
                final active = i <= step;
                final current = i == step;
                return Expanded(
                  flex: current ? 3 : 1,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    height: 4,
                    margin: EdgeInsets.only(right: i < totalSteps - 1 ? 6 : 0),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color: active
                          ? context.watch<AppearanceController>().secondaryColor
                          : context
                                .watch<AppearanceController>()
                                .primaryColor
                                .withAlpha(92),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// ─── Step 1: Name / Species / Breed ──────────────────────────────────────────

class _Step1 extends StatelessWidget {
  final TextEditingController nameCtrl;
  final PetSpecies selectedSpecies;
  final ValueChanged<PetSpecies> onSpeciesChanged;
  final bool breedInputAvaliable;
  final TextEditingController breedCtrl;
  final PetBreed selectedBreed;
  final ValueChanged<PetBreed> onBreedChanged;
  final List<PetBreed> popularBreeds;
  final VoidCallback onNext;
  final VoidCallback onExit;
  final VoidCallback onRestore;

  const _Step1({
    required this.nameCtrl,
    required this.selectedSpecies,
    required this.onSpeciesChanged,
    required this.breedInputAvaliable,
    required this.breedCtrl,
    required this.selectedBreed,
    required this.onBreedChanged,
    required this.popularBreeds,
    required this.onNext,
    required this.onExit,
    required this.onRestore,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Расскажите о новом\nдруге',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 24),

                // ── Кличка ───────────────────────────────────────────────
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: TextField(
                    controller: nameCtrl,
                    style: Theme.of(context).textTheme.bodyLarge,
                    cursorColor: context
                        .watch<AppearanceController>()
                        .secondaryColor,
                    decoration: InputDecoration(
                      labelText: 'Кличка',
                      labelStyle: Theme.of(context).textTheme.bodyMedium!
                          .copyWith(
                            color: context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(172),
                          ),
                      border: InputBorder.none,
                    ),
                    maxLength: 20,
                  ),
                ),

                const SizedBox(height: 12),

                // ── Вид (2×2 tiles) ───────────────────────────────────────
                GridView.count(
                  crossAxisCount: 4,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.9,
                  children: _kSpeciesOptions.map((opt) {
                    final selected = selectedSpecies == opt.species;
                    return GestureDetector(
                      onTap: () => onSpeciesChanged(opt.species),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        decoration: BoxDecoration(
                          color: selected
                              ? context
                                    .watch<AppearanceController>()
                                    .primaryColor
                                    .withAlpha(128)
                              : ThemeColors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: selected
                                ? context
                                      .watch<AppearanceController>()
                                      .secondaryColor
                                : context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                      .withAlpha(92),
                            width: selected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              opt.emoji,
                              style: const TextStyle(fontSize: 30),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              opt.species.name,
                              style: Theme.of(context).textTheme.bodySmall!
                                  .copyWith(fontWeight: FontWeight.w600),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                ),

                const SizedBox(height: 12),

                // ── Порода ────────────────────────────────────────────────
                GestureDetector(
                  onTap: breedInputAvaliable
                      ? () async {
                          final breed = await showBreedSelector(
                            context,
                            selectedSpecies,
                          );
                          if (breed != null && !breed.isEmpty) {
                            onBreedChanged(breed);
                          }
                        }
                      : null,
                  child: _card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 4,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: AbsorbPointer(
                            child: TextField(
                              controller: breedCtrl,
                              style: Theme.of(context).textTheme.bodyLarge,
                              decoration: InputDecoration(
                                labelText: 'Порода',
                                labelStyle: Theme.of(context)
                                    .textTheme
                                    .bodyMedium!
                                    .copyWith(
                                      color: context
                                          .watch<AppearanceController>()
                                          .secondaryColor
                                          .withAlpha(
                                            breedInputAvaliable ? 172 : 64,
                                          ),
                                    ),
                                border: InputBorder.none,
                              ),
                            ),
                          ),
                        ),
                        if (breedInputAvaliable)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context
                                .watch<AppearanceController>()
                                .secondaryColor
                                .withAlpha(128),
                            size: 20,
                          ),
                      ],
                    ),
                  ),
                ),

                // ── Часто выбирают ────────────────────────────────────────
                if (popularBreeds.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    'Часто выбирают',
                    style: Theme.of(context).textTheme.bodySmall!.copyWith(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor
                          .withAlpha(172),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: popularBreeds
                        .map(
                          (b) => GestureDetector(
                            onTap: () => onBreedChanged(b),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: ThemeColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                      .withAlpha(92),
                                ),
                              ),
                              child: Text(
                                b.name,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ],

                // ── Восстановить из облака ────────────────────────────────
                if (!GetIt.instance<AuthService>().isAuthenticated) ...[
                  const SizedBox(height: 24),
                  _RestoreCloudLink(onTap: onRestore),
                ]
              ],
            ),
          ),
        ),
        _BottomBar(
          onNext: onNext,
          onExit: Navigator.of(context).canPop() ? onExit : null,
          label: 'Дальше',
        ),
      ],
    );
  }
}

// ─── Restore-from-cloud link ──────────────────────────────────────────────────

/// Shown at the bottom of Step 1.
/// Tapping starts the auth → check → fullRestore → navigate flow.
class _RestoreCloudLink extends StatelessWidget {
  final VoidCallback onTap;

  const _RestoreCloudLink({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return Center(
      child: GestureDetector(
        onTap: onTap,
        child: RichText(
          text: TextSpan(
            style: theme.textTheme.bodySmall?.copyWith(
              color: Colors.grey.shade400,
            ),
            children: [
              const TextSpan(text: 'Уже пользовались приложением? '),
              TextSpan(
                text: 'Восстановить из облака',
                style: TextStyle(
                  color: ac.secondaryColor,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.underline,
                  decorationColor: ac.secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Step 2: Birth date / Gender / Castrated ─────────────────────────────────

class _Step2 extends StatelessWidget {
  final String petName;
  final DateTime? birthDate;
  final bool unknownDate;
  final Gender gender;
  final bool castrated;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<bool> onUnknownDate;
  final ValueChanged<Gender> onGenderChanged;
  final ValueChanged<bool> onCastratedChanged;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step2({
    required this.petName,
    required this.birthDate,
    required this.unknownDate,
    required this.gender,
    required this.castrated,
    required this.onDateChanged,
    required this.onUnknownDate,
    required this.onGenderChanged,
    required this.onCastratedChanged,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final name = petName.isNotEmpty ? petName : 'питомца';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Когда родился\n$name?',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),

                const SizedBox(height: 20),

                // ── Wheel date picker ─────────────────────────────────────
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: unknownDate ? 0.35 : 1.0,
                  child: IgnorePointer(
                    ignoring: unknownDate,
                    child: _DateWheelPicker(
                      initialDate: birthDate ?? DateTime.now(),
                      onChanged: onDateChanged,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                // ── "Не знаю точную дату" ─────────────────────────────────
                GestureDetector(
                  onTap: () => onUnknownDate(!unknownDate),
                  child: Row(
                    children: [
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        width: 20,
                        height: 20,
                        decoration: BoxDecoration(
                          color: unknownDate
                              ? context
                                    .watch<AppearanceController>()
                                    .secondaryColor
                              : ThemeColors.white,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: unknownDate
                                ? context
                                      .watch<AppearanceController>()
                                      .secondaryColor
                                : context
                                      .watch<AppearanceController>()
                                      .primaryColor
                                      .withAlpha(92),
                            width: 1.5,
                          ),
                        ),
                        child: unknownDate
                            ? const Icon(
                                Icons.check,
                                size: 14,
                                color: Colors.white,
                              )
                            : null,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Не знаю точную дату',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),

                // ── Пол ───────────────────────────────────────────────────
                Text(
                  'Пол',
                  style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                    color: context
                        .watch<AppearanceController>()
                        .secondaryColor
                        .withAlpha(172),
                  ),
                ),
                const SizedBox(height: 8),
                GlassGenderSelector(gender: gender, onChanged: onGenderChanged),

                const SizedBox(height: 16),

                // ── Стерилизован / кастрирован ───────────────────────────
                GestureDetector(
                  onTap: () => onCastratedChanged(!castrated),
                  child: _card(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Стерилизован / кастрирован',
                                style: Theme.of(context).textTheme.bodyLarge!
                                    .copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Учитывается при расчёте нормы питания',
                                style: Theme.of(context).textTheme.bodySmall!
                                    .copyWith(
                                      color: context
                                          .watch<AppearanceController>()
                                          .secondaryColor
                                          .withAlpha(172),
                                    ),
                              ),
                            ],
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            color: castrated
                                ? context
                                      .watch<AppearanceController>()
                                      .secondaryColor
                                : ThemeColors.white,
                            borderRadius: BorderRadius.circular(7),
                            border: Border.all(
                              color: castrated
                                  ? context
                                        .watch<AppearanceController>()
                                        .secondaryColor
                                  : context
                                        .watch<AppearanceController>()
                                        .primaryColor
                                        .withAlpha(92),
                              width: 1.5,
                            ),
                          ),
                          child: castrated
                              ? const Icon(
                                  Icons.check,
                                  size: 16,
                                  color: Colors.white,
                                )
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(onNext: onNext, onBack: onBack, label: 'Дальше'),
      ],
    );
  }
}

// ─── Date wheel picker ────────────────────────────────────────────────────────

class _DateWheelPicker extends StatefulWidget {
  final DateTime initialDate;
  final ValueChanged<DateTime> onChanged;

  const _DateWheelPicker({required this.initialDate, required this.onChanged});

  @override
  State<_DateWheelPicker> createState() => _DateWheelPickerState();
}

class _DateWheelPickerState extends State<_DateWheelPicker> {
  late int _day;
  late int _month;
  late int _year;

  late FixedExtentScrollController _dayCtrl;
  late FixedExtentScrollController _monthCtrl;
  late FixedExtentScrollController _yearCtrl;

  final int _startYear = 2000;

  @override
  void initState() {
    super.initState();
    _day = widget.initialDate.day;
    _month = widget.initialDate.month;
    _year = widget.initialDate.year;
    _dayCtrl = FixedExtentScrollController(initialItem: _day - 1);
    _monthCtrl = FixedExtentScrollController(initialItem: _month - 1);
    _yearCtrl = FixedExtentScrollController(initialItem: _year - _startYear);
  }

  @override
  void dispose() {
    _dayCtrl.dispose();
    _monthCtrl.dispose();
    _yearCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      decoration: BoxDecoration(
        color: ThemeColors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: CupertinoDatePicker(
        mode: CupertinoDatePickerMode.date,
        onDateTimeChanged: widget.onChanged,
        maximumDate: DateTime.now(),
        initialDateTime: widget.initialDate,
      ),
    );
  }
}

// ─── Step 3: Photo ────────────────────────────────────────────────────────────

class _Step3 extends StatelessWidget {
  final String petName;
  final File? photo;
  final Future<void> Function(ImageSource) onPickPhoto;
  final VoidCallback onBack;
  final VoidCallback onNext;

  const _Step3({
    required this.petName,
    required this.photo,
    required this.onPickPhoto,
    required this.onBack,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final name = petName.isNotEmpty ? petName : 'питомца';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Покажите\n$name',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 8),
                Text(
                  'Фото появится на главной и в карточке для врача. Можно пропустить и добавить позже.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 28),

                // ── Photo preview ─────────────────────────────────────────
                Center(
                  child: Stack(
                    children: [
                      Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: context
                                .watch<AppearanceController>()
                                .primaryColor,
                            width: 4,
                          ),
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              context
                                  .watch<AppearanceController>()
                                  .primaryColor
                                  .withAlpha(64),
                              context
                                  .watch<AppearanceController>()
                                  .primaryColor
                                  .withAlpha(2),
                            ],
                          ),
                        ),
                        child: ClipOval(
                          child: photo == null
                              ? Icon(
                                  Icons.pets,
                                  size: 70,
                                  color: context
                                      .watch<AppearanceController>()
                                      .primaryColor,
                                )
                              : Image.file(photo!, fit: BoxFit.cover),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 28),

                // ── Camera / Gallery cards ────────────────────────────────
                Row(
                  children: [
                    Expanded(
                      child: GlassSourceCard(
                        type: SourceCardType.camera,
                        color: ThemeColors.cameraImageSource,
                        onTap: () => onPickPhoto(ImageSource.camera),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GlassSourceCard(
                        type: SourceCardType.gallery,
                        color: ThemeColors.galleryImageSource,
                        onTap: () => onPickPhoto(ImageSource.gallery),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        _BottomBar(onNext: onNext, onBack: onBack, label: 'Дальше'),
      ],
    );
  }
}

// ─── Step 4: Summary ──────────────────────────────────────────────────────────

class _Step4 extends StatefulWidget {
  final String petName;
  final PetSpecies species;
  final PetBreed breed;
  final DateTime? birthDate;
  final Gender gender;
  final bool castrated;
  final File? photo;
  final TextEditingController weightCtrl;
  final TextEditingController allergiesCtrl;
  final TextEditingController chronicCtrl;
  final Set<TreatmentKind> treatments;
  final ValueChanged<TreatmentKind> onTreatmentToggle;
  final VoidCallback onBack;
  final Future<void> Function() onFinish;

  const _Step4({
    required this.petName,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.castrated,
    required this.photo,
    required this.weightCtrl,
    required this.allergiesCtrl,
    required this.chronicCtrl,
    required this.treatments,
    required this.onTreatmentToggle,
    required this.onBack,
    required this.onFinish,
  });

  @override
  State<_Step4> createState() => _Step4State();
}

class _Step4State extends State<_Step4> {
  // Виды обработок для быстрой отметки при регистрации. «Прочая прививка»
  // требует названия — её добавляют позже в профиле.
  static const _quickTreatments = [
    TreatmentKind.rabies,
    TreatmentKind.ticks,
    TreatmentKind.worms,
  ];

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();

    // Превью-профиль для переиспользуемых виджетов карточки питомца.
    final previewPet = Pet(
      name: widget.petName,
      species: widget.species,
      breed: widget.breed,
      birthDate: widget.birthDate,
      gender: widget.gender,
      castrated: widget.castrated,
      profileImage: widget.photo,
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Знакомьтесь,\n${widget.petName.isNotEmpty ? widget.petName : "питомец"}',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
                const SizedBox(height: 6),
                Text(
                  'Проверьте данные. Дополнительные поля можно добавить сейчас или позже в настройках профиля.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),

                const SizedBox(height: 20),

                // ── Hero card ─────────────────────────────────────────────
                _card(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: PetProfileService().buildProfileDescription(
                    context,
                    previewPet,
                    leading: PetProfileService().buildProfileAvatar(
                      context,
                      previewPet,
                      size: 28,
                    ),
                    titleTheme: Theme.of(context).textTheme.titleMedium!
                        .copyWith(fontWeight: FontWeight.w700),
                    additional: widget.castrated
                        ? [
                            SoftGlassBadge(
                              color: ac.secondaryColor,
                              label: 'Кастрирован',
                            ),
                          ]
                        : null,
                  ),
                ),

                const SizedBox(height: 20),

                // ── "Хотите добавить?" ────────────────────────────────────
                Text(
                  'Хотите добавить?',
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge!.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 10),

                // Текущий вес
                _OptionalExpandCard(
                  icon: Icons.monitor_weight_outlined,
                  label: 'Текущий вес',
                  color: const Color(0xFFE8B86A),
                  filled: widget.weightCtrl.text.trim().isNotEmpty,
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.weightCtrl,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          onChanged: (_) => setState(() {}),
                          cursorColor: ac.secondaryColor,
                          style: Theme.of(context).textTheme.bodyLarge,
                          decoration: const InputDecoration(
                            hintText: 'Например, 4.2',
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        ),
                      ),
                      Text(
                        'кг',
                        style: Theme.of(context).textTheme.bodyMedium!.copyWith(
                          color: ac.secondaryColor.withAlpha(172),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // История прививок / обработок
                _OptionalExpandCard(
                  icon: Icons.vaccines_outlined,
                  label: 'История прививок',
                  color: const Color(0xFF6FB888),
                  filled: widget.treatments.isNotEmpty,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Отметьте недавно сделанные — рассчитаем следующую дату.',
                        style: Theme.of(context).textTheme.bodySmall!.copyWith(
                          color: ac.secondaryColor.withAlpha(172),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _quickTreatments.map((kind) {
                          final selected = widget.treatments.contains(kind);
                          return GestureDetector(
                            onTap: () => widget.onTreatmentToggle(kind),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 160),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: selected
                                    ? kind.color.withAlpha(38)
                                    : ThemeColors.white,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: selected
                                      ? kind.color
                                      : ac.primaryColor.withAlpha(92),
                                  width: selected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    selected ? Icons.check : kind.icon,
                                    size: 16,
                                    color: selected
                                        ? kind.color
                                        : ac.secondaryColor.withAlpha(172),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    kind.shortLabel,
                                    style: Theme.of(context).textTheme.bodySmall!
                                        .copyWith(
                                          color: selected
                                              ? kind.color
                                              : ac.secondaryColor,
                                          fontWeight: selected
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Аллергии и хронические болезни
                _OptionalExpandCard(
                  icon: Icons.warning_amber_rounded,
                  label: 'Аллергии и хроники',
                  color: const Color(0xFFD599C0),
                  filled:
                      widget.allergiesCtrl.text.trim().isNotEmpty ||
                      widget.chronicCtrl.text.trim().isNotEmpty,
                  child: Column(
                    children: [
                      _OnboardingField(
                        controller: widget.allergiesCtrl,
                        label: 'Аллергии',
                        hint: 'Например, курица, пыльца',
                        onChanged: () => setState(() {}),
                      ),
                      const SizedBox(height: 10),
                      _OnboardingField(
                        controller: widget.chronicCtrl,
                        label: 'Хронические болезни',
                        hint: 'Например, МКБ',
                        onChanged: () => setState(() {}),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _BottomBar(
          onNext: () => widget.onFinish(),
          onBack: widget.onBack,
          label: 'Готово',
          nextIcon: Icons.check_rounded,
        ),
      ],
    );
  }
}

// ─── Раскрывающаяся карточка доп. данных ─────────────────────────────────────

class _OptionalExpandCard extends StatefulWidget {
  final IconData icon;
  final String label;
  final Color color;
  final bool filled;
  final Widget child;

  const _OptionalExpandCard({
    required this.icon,
    required this.label,
    required this.color,
    required this.filled,
    required this.child,
  });

  @override
  State<_OptionalExpandCard> createState() => _OptionalExpandCardState();
}

class _OptionalExpandCardState extends State<_OptionalExpandCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final active = widget.filled || _expanded;

    return Container(
      decoration: BoxDecoration(
        color: ThemeColors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: active
              ? widget.color.withAlpha(128)
              : ac.primaryColor.withAlpha(92),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _expanded = !_expanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: widget.color.withAlpha(30),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(widget.icon, size: 18, color: widget.color),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    widget.label,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const Spacer(),
                  if (widget.filled && !_expanded)
                    Icon(Icons.check_circle, size: 22, color: widget.color)
                  else
                    AnimatedRotation(
                      turns: _expanded ? 0.25 : 0.0,
                      duration: const Duration(milliseconds: 180),
                      child: Icon(
                        Icons.chevron_right,
                        size: 22,
                        color: ac.primaryColor.withAlpha(128),
                      ),
                    ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                    child: widget.child,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

// ─── Поле ввода на онбординге ────────────────────────────────────────────────

class _OnboardingField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;
  final VoidCallback onChanged;

  const _OnboardingField({
    required this.controller,
    required this.label,
    required this.hint,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    return TextField(
      controller: controller,
      onChanged: (_) => onChanged(),
      cursorColor: ac.secondaryColor,
      style: Theme.of(context).textTheme.bodyMedium,
      minLines: 1,
      maxLines: 3,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        isDense: true,
        labelStyle: Theme.of(context).textTheme.bodyMedium!.copyWith(
          color: ac.secondaryColor.withAlpha(172),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.primaryColor.withAlpha(92)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: ac.secondaryColor),
        ),
      ),
    );
  }
}

// ─── Bottom action bar ────────────────────────────────────────────────────────

class _BottomBar extends StatelessWidget {
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback? onExit;
  final String label;
  final IconData nextIcon;

  const _BottomBar({
    required this.onNext,
    this.onBack,
    this.onExit,
    required this.label,
    this.nextIcon = Icons.arrow_forward_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Row(
        children: [
          if (onExit != null) ...[
            GestureDetector(
              onTap: onExit,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: ThemeColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context
                        .watch<AppearanceController>()
                        .primaryColor
                        .withAlpha(92),
                  ),
                ),
                child: Icon(
                  Icons.close_rounded,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(192),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          if (onBack != null) ...[
            GestureDetector(
              onTap: onBack,
              child: Container(
                width: 50,
                height: 54,
                decoration: BoxDecoration(
                  color: ThemeColors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: context
                        .watch<AppearanceController>()
                        .primaryColor
                        .withAlpha(92),
                  ),
                ),
                child: Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: context
                      .watch<AppearanceController>()
                      .secondaryColor
                      .withAlpha(192),
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: GestureDetector(
              onTap: onNext,
              child: Container(
                height: 54,
                decoration: BoxDecoration(
                  color: context.watch<AppearanceController>().secondaryColor,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: context
                          .watch<AppearanceController>()
                          .secondaryColor
                          .withAlpha(70),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium!.copyWith(
                        color: ThemeColors.white,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(nextIcon, color: Colors.white, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
