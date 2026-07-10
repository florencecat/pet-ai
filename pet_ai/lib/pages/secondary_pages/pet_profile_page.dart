import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:pet_satellite/theme/font_awesome_icons.dart';
import 'package:pet_satellite/theme/widgets/breed_selector.dart';
import 'package:pet_satellite/theme/widgets/confirm_delete.dart';
import 'package:pet_satellite/theme/widgets/draggable_sheets/pet_image_source_sheet.dart';
import 'package:pet_satellite/theme/widgets/glass_widgets.dart';
import 'package:pet_satellite/theme/widgets/pressable.dart';
import 'package:pet_satellite/theme/widgets/switch.dart';
import 'package:provider/provider.dart';
import 'package:pet_satellite/models/pet_profile.dart';

// ─── Page ────────────────────────────────────────────────────────────────────

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  Pet? _profile;
  bool _loading = true;
  bool _paletteChanged = false;
  // Профиль удалён — блокирует авто-сохранение при закрытии страницы (иначе
  // PopScope повторно добавил бы удалённого питомца через saveProfile).
  bool _deleted = false;
  // Bumped on each avatar pick so the Image widget re-resolves its FileImage.
  // The avatar path is deterministic (avatar_<id>.png), so FileImage equality
  // by path prevents re-resolution after the file is overwritten.
  int _avatarVersion = 0;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  // ── Load ──────────────────────────────────────────────────────────────────

  Future<void> _loadProfile() async {
    final profile = await PetProfileService().loadActiveProfile();
    if (profile == null) {
      if (mounted) Navigator.of(context).pushReplacementNamed('/registration');
      return;
    }
    if (mounted) {
      setState(() {
        _profile = profile;
        _loading = false;
      });
    }
  }

  // ── Save ──────────────────────────────────────────────────────────────────

  Future<void> _saveProfile() async {
    if (_profile == null || _deleted) return;
    try {
      await PetProfileService().saveProfile(_profile!);
    } catch (_) {}
    // Fire-and-forget cloud upsert профиля (owner = id пользователя).
    final uid = CloudSyncService.instance.userId;
    if (uid != null) {
      CloudSyncService.instance.pushAsync('pets', _profile!, uid);
    }
  }

  Future<void> _savePalette() async {
    if (_profile == null) return;
    final appearance = mounted ? context.read<AppearanceController>() : null;
    try {
      appearance?.updatePetPalette(_profile!.palette);
    } catch (_) {}
  }

  // ── Field editors ─────────────────────────────────────────────────────────

  Future<void> _editName() async {
    final result = await _showTextSheet(
      context,
      title: 'Кличка',
      initialValue: _profile!.name,
      limit: 20,
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() => _profile!.name = result.trim());
    }
  }

  Future<void> _editSpecies() async {
    final species = await showSpeciesSelector(context);
    if (species != null && species.id != _profile!.species.id) {
      setState(() {
        _profile!.species = species;
        _profile!.breed = const PetBreed.empty();
      });
    }
  }

  Future<void> _editBreed() async {
    final breed = await showBreedSelector(context, _profile!.species);
    if (breed != null && !breed.isEmpty) {
      setState(() => _profile!.breed = breed);
    }
  }

  Future<void> _editCoat() async {
    final result = await _showTextSheet(
      context,
      title: 'Окрас',
      initialValue: _profile!.coat,
      hint: 'Например: рыжий с белым',
    );
    if (result != null) setState(() => _profile!.coat = result.trim());
  }

  Future<void> _editBio() async {
    final result = await _showTextSheet(
      context,
      title: 'Биография',
      initialValue: _profile!.notes,
      multiline: true,
      hint: 'Расскажите о питомце...',
    );
    if (result != null) setState(() => _profile!.notes = result.trim());
  }

  Future<void> _editBirthDate() async {
    final result = await _showDateSheet(context, initial: _profile!.birthDate);
    if (result != null) setState(() => _profile!.birthDate = result);
  }

  Future<void> _editGender() async {
    await _showGenderSheet(
      context,
      current: _profile!.gender,
      onGenderChanged: (g) => setState(() => _profile!.gender = g),
    );
  }

  Future<void> _editCastration() async {
    final result = await _showCastrationSheet(
      context,
      castrated: _profile!.castrated,
      date: _profile!.castratedDate,
    );
    if (result != null) {
      setState(() {
        _profile!.castrated = result.$1;
        _profile!.castratedDate = result.$2;
      });
    }
  }

  Future<void> _editAllergies() async {
    final result = await _showTextSheet(
      context,
      title: 'Аллергии',
      initialValue: _profile!.allergies,
      hint: 'Например: курица, злаки',
    );
    if (result != null) setState(() => _profile!.allergies = result.trim());
  }

  Future<void> _editChronicConditions() async {
    final result = await _showTextSheet(
      context,
      title: 'Хронические заболевания',
      initialValue: _profile!.chronicConditions,
      multiline: true,
      hint: 'Например: дисплазия, МКБ',
    );
    if (result != null) {
      setState(() => _profile!.chronicConditions = result.trim());
    }
  }

  Future<void> _editVetClinic() async {
    final result = await _showTextSheet(
      context,
      title: 'Ветеринар / клиника',
      initialValue: _profile!.vetClinic,
      hint: 'Например: Клиника «Барсик»',
    );
    if (result != null) setState(() => _profile!.vetClinic = result.trim());
  }

  Future<void> _editChipNumber() async {
    final result = await _showTextSheet(
      context,
      title: 'Чип / клеймо',
      initialValue: _profile!.chipNumber,
      keyboardType: TextInputType.number,
      hint: '15 цифр',
      limit: 15,
    );
    if (result != null) setState(() => _profile!.chipNumber = result.trim());
  }

  Future<void> _editAvatar() async {
    final source = await _pickImageSource();
    if (source == null || !mounted) return;

    final path = await PetProfileService().pickProfileImage(
      _profile!.id,
      source: source,
    );
    if (path != null && mounted) {
      setState(() {
        _profile!.profileImage = File(path);
        _avatarVersion++;
      });
    }
  }

  /// Нижний лист с выбором источника фото: камера или галерея.
  Future<ImageSource?> _pickImageSource() => showPetImageSourceSheet(context);

  Future<void> _deleteProfile() async {
    final confirmed = await confirmDelete(
      context,
      title: 'Удалить профиль питомца?',
      message:
          'Все данные питомца будут удалены без возможности восстановления.',
    );
    if (!confirmed || !mounted) return;
    // Ставим флаг до удаления, чтобы авто-save при закрытии страницы
    // (PopScope) не воскресил профиль.
    _deleted = true;
    await PetProfileService().deleteProfile(_profile!.id);
    final hasProfiles = await PetProfileService().hasProfiles();
    if (mounted) {
      if (hasProfiles) {
        Navigator.of(context, rootNavigator: true).pop();
      } else {
        Navigator.of(context).pushReplacementNamed('/registration');
      }
    }
  }

  // ── Formatting helpers ────────────────────────────────────────────────────

  String _formatDate(DateTime? d) {
    if (d == null) return 'Не указана';
    return DateFormat('d MMMM yyyy', 'ru_RU').format(d);
  }

  String _castrationLabel() {
    if (!_profile!.castrated) return 'Нет';
    if (_profile!.castratedDate != null) {
      return DateFormat(
        'd MMMM yyyy',
        'ru_RU',
      ).format(_profile!.castratedDate!);
    }
    return 'Да';
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final ac = context.watch<AppearanceController>();
    final theme = Theme.of(context);

    return PopScope(
      canPop: true,
      // Fires right after the page is popped (back gesture, system back, or
      // an in-app Navigator.pop). Persist any pending edits without blocking
      // the navigation.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _saveProfile();
      },
      child: Scaffold(
        appBar: AppBar(
          centerTitle: true,
          title: Text('Профиль питомца', style: theme.textTheme.titleMedium),
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildBody(ac, theme),
      ),
    );
  }

  Widget _buildBody(AppearanceController ac, ThemeData theme) {
    final p = _profile!;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 48),
      children: [
        // ── Avatar ──────────────────────────────────────────────────────────
        _AvatarSection(
          profile: p,
          onTap: _editAvatar,
          primaryColor: ac.primaryColor,
          avatarVersion: _avatarVersion,
        ),

        const SizedBox(height: 20),

        // ── Palette ─────────────────────────────────────────────────────────
        _PaletteSection(
          current: p.palette,
          onChanged: (palette) async {
            setState(() {
              p.palette = palette;
              _paletteChanged = true;
            });
            await _savePalette();
          },
          primaryColor: ac.primaryColor,
          paletteChanged: _paletteChanged,
        ),

        const SizedBox(height: 28),

        // ── Основное ────────────────────────────────────────────────────────
        _SectionHeader(title: 'Основное'),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            _InfoRow(
              icon: FontAwesome.tag,
              label: 'Кличка',
              value: p.name.isEmpty ? 'Не указана' : p.name,
              onTap: _editName,
            ),
            _InfoRow(
              icon: FontAwesome.paw,
              label: 'Вид',
              value: p.species.name.isEmpty ? 'Не указана' : p.species.name,
              onTap: _editSpecies,
            ),
            _InfoRow(
              icon: FontAwesome.dna,
              label: 'Порода',
              value: p.breed.name.isEmpty ? 'Не указана' : p.breed.name,
              onTap: _editBreed,
            ),
            _InfoRow(
              icon: FontAwesome.palette,
              label: 'Окрас',
              value: p.coat.isEmpty ? 'Не указан' : p.coat,
              onTap: _editCoat,
            ),
            _InfoRow(
              icon: FontAwesome.scroll,
              label: 'Биография',
              value: p.notes.isEmpty ? 'Не указана' : p.notes,
              multiline: true,
              onTap: _editBio,
            ),
            _InfoRow(
              icon: FontAwesome.birthday_cake,
              label: 'Дата рождения',
              value: _formatDate(p.birthDate),
              onTap: _editBirthDate,
            ),
            _InfoRow(
              icon: FontAwesome.venus_mars,
              label: 'Пол',
              value: p.gender.label,
              onTap: _editGender,
            ),
            _InfoRow(
              icon: FontAwesome.cut,
              label: 'Стерилизация',
              value: _castrationLabel(),
              onTap: _editCastration,
              last: true,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Здоровье ────────────────────────────────────────────────────────
        _SectionHeader(title: 'Здоровье'),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            _InfoRow(
              icon: FontAwesome.allergies,
              label: 'Аллергии',
              value: p.allergies.isEmpty ? 'Не указаны' : p.allergies,
              onTap: _editAllergies,
            ),
            _InfoRow(
              icon: FontAwesome.notes_medical,
              label: 'Хронические заболевания',
              value: p.chronicConditions.isEmpty
                  ? 'Не указаны'
                  : p.chronicConditions,
              multiline: true,
              onTap: _editChronicConditions,
            ),
            _InfoRow(
              icon: FontAwesome.stethoscope,
              label: 'Ветеринар',
              value: p.vetClinic.isEmpty ? 'Не указан' : p.vetClinic,
              onTap: _editVetClinic,
              last: true,
            ),
          ],
        ),

        const SizedBox(height: 20),

        // ── Документы ───────────────────────────────────────────────────────
        _SectionHeader(title: 'Документы'),
        const SizedBox(height: 8),
        _SectionCard(
          children: [
            _InfoRow(
              icon: FontAwesome.microchip,
              label: 'Чип / клеймо',
              value: p.chipNumber.isEmpty ? 'Не указан' : p.chipNumber,
              onTap: _editChipNumber,
            ),
            // Entry point — vet passport upload (not yet implemented)
            _InfoRow(
              icon: FontAwesome.book_medical,
              label: 'Ветпаспорт',
              value: 'Скоро',
              onTap: null,
              last: true,
            ),
          ],
        ),

        const SizedBox(height: 36),

        // ── Delete ───────────────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _deleteProfile,
            icon: const Icon(Icons.delete_outline),
            label: Text('Удалить профиль питомца'),
            style: OutlinedButton.styleFrom(
              foregroundColor: ThemeColors.dangerZone,
              side: const BorderSide(color: ThemeColors.dangerZone, width: 1.5),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),
      ],
    );
  }
}

// ─── Section widgets ──────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: context.watch<AppearanceController>().secondaryColor,
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final List<Widget> children;
  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return GlassPlate(
      padding: 0,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData? icon;
  final String label;
  final String value;
  final bool multiline;
  final bool last;
  final VoidCallback? onTap;

  const _InfoRow({
    this.icon,
    required this.label,
    required this.value,
    this.multiline = false,
    this.last = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        InkWell(
          onTap: onTap == null
              ? null
              : () {
                  triggerHaptic(HapticStrength.light);
                  onTap!();
                },
          borderRadius: last
              ? const BorderRadius.vertical(bottom: Radius.circular(20))
              : BorderRadius.zero,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              spacing: 14,
              children: [
                if (icon != null)
                  Icon(icon, size: 14, color: ac.primaryColor.withAlpha(128)),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: ac.secondaryColor.withAlpha(160),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        style: theme.textTheme.bodyMedium,
                        maxLines: multiline ? 3 : 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (onTap != null)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: ac.primaryColor.withAlpha(140),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (!last)
          Divider(
            height: 1,
            thickness: 0.5,
            indent: 16,
            endIndent: 0,
            color: theme.dividerColor.withAlpha(60),
          ),
      ],
    );
  }
}

// ─── Avatar section ───────────────────────────────────────────────────────────

class _AvatarSection extends StatelessWidget {
  final Pet profile;
  final VoidCallback onTap;
  final Color primaryColor;
  final int avatarVersion;

  const _AvatarSection({
    required this.profile,
    required this.onTap,
    required this.primaryColor,
    required this.avatarVersion,
  });

  @override
  Widget build(BuildContext context) {
    final actualColor = profile.palette.mainColor != primaryColor
        ? profile.palette.mainColor
        : primaryColor;

    return Center(
      child: Pressable(
        onTap: onTap,
        haptic: HapticStrength.selection,
        scale: 0.94,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: actualColor, width: 3),
                color: actualColor.withAlpha(30),
              ),
              child: ClipOval(
                child: profile.profileImage != null
                    ? Image.file(
                        profile.profileImage!,
                        key: ValueKey(avatarVersion),
                        fit: BoxFit.cover,
                      )
                    : Icon(Icons.pets, size: 42, color: actualColor),
              ),
            ),
            Positioned(
              bottom: 0,
              right: 0,
              child: Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: actualColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 2),
                ),
                child: const Icon(
                  Icons.camera_alt,
                  size: 14,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Palette section ──────────────────────────────────────────────────────────

class _PaletteSection extends StatelessWidget {
  final ColorPalette current;
  final ValueChanged<ColorPalette> onChanged;
  final Color primaryColor;
  final bool paletteChanged;

  const _PaletteSection({
    required this.current,
    required this.onChanged,
    required this.primaryColor,
    required this.paletteChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 12,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Цвет профиля',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
              color: context.watch<AppearanceController>().secondaryColor,
            ),
          ),
        ),
        SizedBox(
          height: 48,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            itemCount: ThemeColors.profilePalettes.length,
            separatorBuilder: (_, _) => const SizedBox(width: 12),
            itemBuilder: (context, index) {
              final palette = ThemeColors.profilePalettes[index];
              final isSelected =
                  current.mainColor == palette.mainColor &&
                  current.darkShade == palette.darkShade;
              return GestureDetector(
                onTap: () => onChanged(palette),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: palette.mainColor,
                    border: Border.all(
                      color: isSelected ? Colors.black54 : Colors.transparent,
                      width: 3,
                    ),
                    boxShadow: [
                      if (isSelected)
                        BoxShadow(
                          color: palette.mainColor.withAlpha(120),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                    ],
                  ),
                  child: isSelected
                      ? Icon(
                          Icons.check_outlined,
                          color: current.darkShade,
                          size: 30,
                        )
                      : null,
                ),
              );
            },
          ),
        ),
        if (paletteChanged &&
            !context.watch<AppearanceController>().usePetColor)
          SoftGlassPlate(
            color: context.watch<AppearanceController>().primaryColor.withAlpha(
              30,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: context.watch<AppearanceController>().primaryColor,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Применить цвет профиля активного питомца как основной цвет приложения можно в настройках',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

// ─── Sheet helpers ────────────────────────────────────────────────────────────

/// Generic single- or multi-line text edit sheet.
/// Returns the entered string, or null if dismissed.
Future<String?> _showTextSheet(
  BuildContext context, {
  required String title,
  required String initialValue,
  bool multiline = false,
  String? hint,
  TextInputType? keyboardType,
  int? limit,
}) async {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _TextSheet(
      title: title,
      initialValue: initialValue,
      multiline: multiline,
      hint: hint,
      keyboardType: keyboardType,
      limit: limit,
    ),
  );
}

/// Date picker sheet using CupertinoDatePicker (date-only mode).
/// Returns the picked date, or null if dismissed.
Future<DateTime?> _showDateSheet(
  BuildContext context, {
  DateTime? initial,
}) async {
  return showModalBottomSheet<DateTime>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) => _DateSheet(initial: initial),
  );
}

/// Gender selection sheet. Taps inside the sheet update the parent live via
/// [onGenderChanged]; the sheet is dismissed by dragging it down.
Future<void> _showGenderSheet(
  BuildContext context, {
  required Gender current,
  required ValueChanged<Gender> onGenderChanged,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    builder: (ctx) =>
        _GenderSheet(initial: current, onChanged: onGenderChanged),
  );
}

/// Castration toggle + optional date sheet.
/// Returns a record (castrated, date), or null if dismissed.
Future<(bool, DateTime?)?> _showCastrationSheet(
  BuildContext context, {
  required bool castrated,
  DateTime? date,
}) async {
  return showModalBottomSheet<(bool, DateTime?)>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black54,
    isScrollControlled: true,
    builder: (ctx) => _CastrationSheet(castrated: castrated, date: date),
  );
}

// ─── Sheet widgets ────────────────────────────────────────────────────────────

class _TextSheet extends StatefulWidget {
  final String title;
  final String initialValue;
  final bool multiline;
  final String? hint;
  final TextInputType? keyboardType;
  final int? limit;

  const _TextSheet({
    required this.title,
    required this.initialValue,
    this.multiline = false,
    this.hint,
    this.keyboardType,
    this.limit,
  });

  @override
  State<_TextSheet> createState() => _TextSheetState();
}

class _TextSheetState extends State<_TextSheet> {
  late final TextEditingController _controller;
  late final FocusNode _focus;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.initialValue);
    _focus = FocusNode();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(widget.title, style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          TextField(
            controller: _controller,
            focusNode: _focus,
            maxLines: widget.multiline ? 5 : 1,
            keyboardType:
                widget.keyboardType ??
                (widget.multiline
                    ? TextInputType.multiline
                    : TextInputType.text),
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: widget.hint,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            maxLength: widget.limit,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, _controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: ac.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _DateSheet extends StatefulWidget {
  final DateTime? initial;
  const _DateSheet({this.initial});

  @override
  State<_DateSheet> createState() => _DateSheetState();
}

class _DateSheetState extends State<_DateSheet> {
  late DateTime _selected;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _selected = widget.initial ?? DateTime(now.year - 1, now.month, now.day);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();

    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.fromLTRB(0, 12, 0, 0),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          // Header row
          Row(
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'Отмена',
                  style: TextStyle(color: theme.dividerColor),
                ),
              ),
              Expanded(
                child: Text(
                  'Дата рождения',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, _selected),
                child: Text(
                  'Готово',
                  style: TextStyle(
                    color: ac.primaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          Expanded(
            child: CupertinoDatePicker(
              mode: CupertinoDatePickerMode.date,
              initialDateTime: _selected,
              maximumDate: DateTime.now(),
              minimumDate: DateTime(1900),
              onDateTimeChanged: (dt) => _selected = dt,
            ),
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _GenderSheet extends StatefulWidget {
  final Gender initial;
  final ValueChanged<Gender> onChanged;

  const _GenderSheet({required this.initial, required this.onChanged});

  @override
  State<_GenderSheet> createState() => _GenderSheetState();
}

class _GenderSheetState extends State<_GenderSheet> {
  late Gender _gender = widget.initial;

  void _set(Gender g) {
    setState(() => _gender = g);
    widget.onChanged(g);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Пол', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          GlassGenderSelector(gender: _gender, onChanged: _set),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────

class _CastrationSheet extends StatefulWidget {
  final bool castrated;
  final DateTime? date;
  const _CastrationSheet({required this.castrated, this.date});

  @override
  State<_CastrationSheet> createState() => _CastrationSheetState();
}

class _CastrationSheetState extends State<_CastrationSheet> {
  late bool _castrated;
  DateTime? _date;

  @override
  void initState() {
    super.initState();
    _castrated = widget.castrated;
    _date = widget.date;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date ?? now,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
      locale: const Locale('ru'),
    );
    if (picked != null) setState(() => _date = picked);
  }

  String get _dateLabel {
    if (_date == null) return 'Указать дату';
    return DateFormat('d MMMM yyyy', 'ru_RU').format(_date!);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final ac = context.watch<AppearanceController>();
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 12, 16, 24 + bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: Colors.grey.shade400,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text('Стерилизация', style: theme.textTheme.titleMedium),
          const SizedBox(height: 20),
          // Toggle row
          GlassPlate(
            padding: 16,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Стерилизован(а)', style: theme.textTheme.bodyMedium),
                OutlinedSwitch(
                  value: _castrated,
                  onChanged: (v) => setState(() {
                    _castrated = v;
                    if (!v) {
                      _date = null;
                    }
                  }),
                ),
              ],
            ),
          ),
          if (_castrated) ...[
            const SizedBox(height: 12),
            GlassPlate(
              padding: 16,
              child: Pressable(
                onTap: _pickDate,
                child: Row(
                  children: [
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: ac.primaryColor,
                    ),
                    const SizedBox(width: 12),
                    Text(_dateLabel, style: theme.textTheme.bodyMedium),
                    const Spacer(),
                    Icon(
                      Icons.chevron_right,
                      size: 18,
                      color: ac.primaryColor.withAlpha(140),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.pop(context, (_castrated, _date)),
              style: FilledButton.styleFrom(
                backgroundColor: ac.primaryColor,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Готово'),
            ),
          ),
        ],
      ),
    );
  }
}
