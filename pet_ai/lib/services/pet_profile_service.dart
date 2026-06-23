import 'dart:developer';

import 'dart:io';
import 'dart:math' hide log;
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:pet_satellite/models/history.dart';
import 'package:pet_satellite/services/appearance_controller.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class PetContextBuilder {
  static String build(Pet pet) {
    return """
      Имя: ${pet.name}
      Вид: ${pet.breed}
      Дата рождения: ${pet.birthDate}
      Вес: ${pet.weightHistory.lastWeight} кг
    """;
  }
}

enum Gender { none, male, female }

extension GenderX on Gender {
  String get label {
    switch (this) {
      case Gender.none:
        return "Не указан";
      case Gender.male:
        return "Мальчик";
      case Gender.female:
        return "Девочка";
    }
  }

  String get caption {
    switch (this) {
      case Gender.none:
        return "";
      case Gender.male:
        return "мальчик";
      case Gender.female:
        return "девочка";
    }
  }

  int get value {
    switch (this) {
      case Gender.none:
        return 0;
      case Gender.male:
        return 1;
      case Gender.female:
        return 2;
    }
  }

  IconData? get icon {
    switch (this) {
      case Gender.none:
        return null;
      case Gender.male:
        return Icons.male;
      case Gender.female:
        return Icons.female;
    }
  }

  Color get color {
    switch (this) {
      case Gender.none:
        return Colors.transparent;
      case Gender.male:
        return ThemeColors.maleGender;
      case Gender.female:
        return ThemeColors.femaleGender;
    }
  }
}

class PetService {
  static const _profilesKey = 'pet_profiles';
  static const _activeIdKey = 'active_pet_id';

  // ─── Чтение/запись всей коллекции ────────────────────────────────────────

  Future<List<Pet>> loadAllProfiles() async {
    final prefs = SharedPreferencesAsync();
    final jsonStr = await prefs.getString(_profilesKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list.map((e) => Pet.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      log('ProfileService.loadAllProfiles: $e');
      return [];
    }
  }

  Future<void> _saveAllProfiles(List<Pet> profiles) async {
    final jsonStr = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await SharedPreferencesAsync().setString(_profilesKey, jsonStr);
  }

  Future<void> exportAllProfiles() async {
    final profiles = await loadAllProfiles();
    final events = await EventService().loadAllEvents(
      profiles.map((p) => p.id).toList(),
    );

    final path = await FilePicker.platform.getDirectoryPath(
      initialDirectory: 'Экспорт всех профилей',
    );
    final profilesFile = File('$path/profiles.json');
    final eventsFile = File('$path/events.json');
    await profilesFile.writeAsString(
      jsonEncode(profiles.map((p) => p.toJson()).toList()),
    );
    await eventsFile.writeAsString(
      jsonEncode(
        events.values.map((l) => l.map((e) => e.toJson()).toList()).toList(),
      ),
    );
  }

  // ─── Активный профиль ─────────────────────────────────────────────────────

  /// Возвращает id активного профиля или null, если не выбран.
  Future<String?> getActiveProfileId() async =>
      SharedPreferencesAsync().getString(_activeIdKey);

  /// Устанавливает активный профиль. Бросает [ArgumentError], если [petId]
  /// не существует в коллекции.
  Future<void> setActiveProfile(String petId) async {
    final profiles = await loadAllProfiles();
    if (!profiles.any((p) => p.id == petId)) {
      throw ArgumentError('Профиль с id=$petId не найден');
    }
    await SharedPreferencesAsync().setString(_activeIdKey, petId);
  }

  /// Возвращает активный профиль. Если активный id не задан или устарел —
  /// возвращает первый из списка (и обновляет сохранённый id).
  Future<Pet?> loadActiveProfile() async {
    final profiles = await loadAllProfiles();
    if (profiles.isEmpty) return null;

    final activeId = await getActiveProfileId();
    final found = profiles.firstWhere(
      (p) => p.id == activeId,
      orElse: () => profiles.first,
    );

    // Синхронизируем сохранённый id на случай устаревания
    if (found.id != activeId) {
      await SharedPreferencesAsync().setString(_activeIdKey, found.id);
    }
    return found;
  }

  // ─── CRUD ─────────────────────────────────────────────────────────────────

  Future<Pet?> loadProfile(String petId) async {
    final profiles = await loadAllProfiles();
    try {
      return profiles.firstWhere((p) => p.id == petId);
    } catch (_) {
      return null;
    }
  }

  /// Добавляет новый профиль. Если это первый профиль — делает его активным.
  Future<void> addProfile(Pet profile) async {
    final profiles = await loadAllProfiles();
    profiles.add(profile);
    await _saveAllProfiles(profiles);

    if (profiles.length == 1) {
      await SharedPreferencesAsync().setString(_activeIdKey, profile.id);
    }
  }

  /// Сохраняет (обновляет) существующий профиль по [profile.id].
  Future<void> saveProfile(Pet profile) async {
    final profiles = await loadAllProfiles();
    final idx = profiles.indexWhere((p) => p.id == profile.id);
    if (idx == -1) {
      // Профиля нет — добавляем как новый
      await addProfile(profile);
      return;
    }
    profiles[idx] = profile;
    await _saveAllProfiles(profiles);
  }

  /// Удаляет профиль. Если удалён активный — переключается на следующий
  /// доступный (или сбрасывает активный id).
  Future<void> deleteProfile(String petId) async {
    final profiles = await loadAllProfiles();
    final activeId = await getActiveProfileId();

    profiles.removeWhere((p) => p.id == petId);
    await _saveAllProfiles(profiles);

    if (activeId == petId) {
      final newActiveId = profiles.isNotEmpty ? profiles.first.id : null;
      if (newActiveId != null) {
        await SharedPreferencesAsync().setString(_activeIdKey, newActiveId);
      } else {
        await SharedPreferencesAsync().remove(_activeIdKey);
      }
    }
  }

  Future<bool> hasProfiles() async {
    final profiles = await loadAllProfiles();
    return profiles.isNotEmpty;
  }

  Future<bool> hasMultipleProfiles() async {
    final profiles = await loadAllProfiles();
    return profiles.length > 1;
  }

  /// Удаляет все профили и сбрасывает активный id.
  Future<void> clearAll() async {
    final prefs = SharedPreferencesAsync();
    await prefs.remove(_profilesKey);
    await prefs.remove(_activeIdKey);
  }

  // ─── Мутации данных профиля ───────────────────────────────────────────────

  Future<void> updateWeightHistory(String petId, double weight) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final entry = profile.weightHistory.addWeight(weight);
      await saveProfile(profile);
      // Fire-and-forget cloud push (upsert by id — правка перезапишет запись).
      CloudSyncService.instance.pushAsync('weights', entry, petId);
    }
  }

  Future<void> updateMoodHistory(String petId, MoodEntry entry) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final saved = profile.moodHistory.addOrReplace(entry);
      await saveProfile(profile);
      // Fire-and-forget cloud push (saved хранит стабильный id для апсерта).
      CloudSyncService.instance.pushAsync('moods', saved, petId);
    }
  }

  Future<void> updateFoodHistory(String petId, MealEntry entry) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final saved = profile.foodHistory.addOrReplace(entry);
      await saveProfile(profile);
      // Fire-and-forget cloud push.
      CloudSyncService.instance.pushAsync('meals', saved, petId);
    }
  }

  Future<void> deleteFoodEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final ids = profile.foodHistory.entries
          .where((e) => e.date == date)
          .map((e) => e.id)
          .toList();
      profile.foodHistory.deleteEntry(date);
      await saveProfile(profile);
      for (final id in ids) {
        CloudSyncService.instance.deleteAsync('meals', id);
      }
    }
  }

  Future<void> deleteWeightEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final ids = profile.weightHistory.entries
          .where((e) => e.date == date)
          .map((e) => e.id)
          .toList();
      profile.weightHistory.deleteEntry(date);
      await saveProfile(profile);
      for (final id in ids) {
        CloudSyncService.instance.deleteAsync('weights', id);
      }
    }
  }

  Future<void> deleteMoodEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final ids = profile.moodHistory.entries
          .where((e) => e.date == date)
          .map((e) => e.id)
          .toList();
      profile.moodHistory.deleteEntry(date);
      await saveProfile(profile);
      for (final id in ids) {
        CloudSyncService.instance.deleteAsync('moods', id);
      }
    }
  }

  Future<void> addNote(String petId, String note, {String? symptomId}) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      await profile.noteHistory.addNote(note, symptomId: symptomId);
      await saveProfile(profile);
      // Fire-and-forget cloud push for the latest note entry.
      final last = profile.noteHistory.entries.isNotEmpty
          ? profile.noteHistory.entries.last
          : null;
      if (last != null) {
        CloudSyncService.instance.pushAsync('notes', last, petId);
      }
    }
  }

  Future<void> deleteNoteEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final ids = profile.noteHistory.entries
          .where((e) => e.date == date)
          .map((e) => e.id)
          .toList();
      profile.noteHistory.deleteEntry(date);
      await saveProfile(profile);
      for (final id in ids) {
        CloudSyncService.instance.deleteAsync('notes', id);
      }
    }
  }

  Future<void> clearWeightHistory(String petId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.weightHistory.clear();
      await saveProfile(profile);
    }
  }

  Future<void> clearMoodHistory(String petId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.moodHistory.clear();
      await saveProfile(profile);
    }
  }

  Future<void> clearTreatmentHistory(String petId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.treatmentHistory.clear();
      await saveProfile(profile);
    }
  }

  // ─── Работа с изображением ──────────────────────────────────────────────

  Future<String> _saveAvatarToAppDir(String petId, String tempPath) async {
    final directory = await getApplicationDocumentsDirectory();
    // Уникальное имя файла на профиль, чтобы не затирать аватары других питомцев
    final sanitizedId = petId.replaceAll(RegExp(r'[^\w]'), '_');
    final avatarPath = '${directory.path}/avatar_$sanitizedId.png';
    final avatarFile = await File(tempPath).copy(avatarPath);
    // Evict stale cached decode so the next render picks up the new file.
    PaintingBinding.instance.imageCache.evict(FileImage(avatarFile));
    return avatarFile.path;
  }

  /// Единый механизм выбора фото питомца: выбор из [source] + квадратное
  /// кадрирование. Возвращает кадрированный файл (во временной папке) либо null,
  /// если пользователь отменил выбор/кадрирование.
  ///
  /// Используется и в онбординге (до создания питомца), и в редактировании
  /// профиля — чтобы кадрирование предлагалось единообразно.
  Future<File?> pickAndCropImage({
    required ImageSource source,
  }) async {
    if (kIsWeb) {
      throw UnimplementedError("pickAndCropImage() is not supported on web");
    }

    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source, imageQuality: 90);
    if (pickedFile == null) return null;

    // ImageCropper не поддерживается на Windows — возвращаем как есть.
    if (Platform.isWindows) return File(pickedFile.path);

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 90,
      compressFormat: ImageCompressFormat.jpg,
      maxWidth: 256,
      maxHeight: 256,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    );
    if (cropped == null) return null;
    return File(cropped.path);
  }

  /// Сохраняет [sourcePath] как постоянный аватар питомца [petId]
  /// в каталоге приложения и возвращает итоговый путь.
  Future<String> saveAvatar(String petId, String sourcePath) =>
      _saveAvatarToAppDir(petId, sourcePath);

  Future<String?> pickProfileImage(
    String petId, {
    ImageSource source = ImageSource.gallery,
  }) async {
    final file = await pickAndCropImage(source: source);
    if (file == null) return null;
    return await _saveAvatarToAppDir(petId, file.path);
  }

  Future<String> lastMoodString() async {
    final profile = await loadActiveProfile();
    if (profile != null && profile.moodHistory.lastEntry != null) {
      return profile.moodHistory.lastEntry!.mood.label;
    } else {
      return "Нет данных";
    }
  }

  Future<String> lastFoodString() async {
    final profile = await loadActiveProfile();
    final result = profile?.foodHistory
        .filterByPeriod(HistoryPeriod.day)
        .length
        .toString();
    if (result != null) {
      return "$result x сегодня";
    } else {
      return "Нет данных";
    }
  }

  void fillWeightHistory() async {
    if (!kDebugMode) return;

    final profile = await loadActiveProfile();
    if (profile != null) {
      final initialWeight = 12;
      final entries = <WeightEntry>[];
      for (int i = 12; i >= 0; --i) {
        final fault = Random().nextInt(10) / 10.0;
        final sign = Random().nextBool() ? -1 : 1;
        entries.add(
          WeightEntry(
            date: DateTime.now().subtract(Duration(days: 30 * i)),
            weight: initialWeight + i * fault * sign,
          ),
        );
      }
      profile.weightHistory = WeightHistory(entries: entries);
      await saveProfile(profile);
    }
  }

  Widget buildProfileAvatar(
    BuildContext context,
    Pet? pet, {
    bool? withSwitcher,
    bool? multipleProfiles,
    double size = 38,
  }) {
    final petColor =
        pet?.palette.mainColor ??
        context.watch<AppearanceController>().primaryColor;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          padding: EdgeInsets.all(size * 0.01),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: petColor, width: 2.5),
            boxShadow: [
              BoxShadow(
                color: petColor.withAlpha(80),
                blurRadius: 10,
                spreadRadius: 1,
              ),
            ],
          ),
          child: CircleAvatar(
            radius: size * 0.9,
            backgroundColor: Colors.white.withValues(alpha: 0.3),
            child: pet?.profileImage == null
                ? Icon(Icons.pets, size: size, color: petColor)
                : CircleAvatar(
                    radius: size,
                    backgroundImage: FileImage(pet!.profileImage!),
                  ),
          ),
        ),
        if (withSwitcher == true)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                color: context.watch<AppearanceController>().petColor,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.white, width: 2),
              ),
              child: Icon(
                multipleProfiles == true
                    ? Icons.expand_more_rounded
                    : Icons.add,
                size: 14,
                color: Colors.white,
              ),
            ),
          ),
      ],
    );
  }

  Widget buildProfileDescription(
    BuildContext context,
    Pet? pet, {
    Widget? leading,
    Widget? trailing,
    TextStyle? titleTheme,
    TextStyle? subTitleTheme,
  }) {
    String description = pet?.breed.name ?? '';
    if (description.isEmpty) {
      description = pet?.species.name ?? 'Спутник';
    }
    if (pet?.birthDate != null) {
      final duration = pet!.birthDate!.difference(DateTime.now());
      description = '$description · ${formatPetAge(duration)}';
    }

    return ListTile(
      leading: leading,
      trailing: trailing,
      title: Row(
        spacing: 6,
        children: [
          Text(
            pet == null || pet.name.isEmpty ? 'Без имени' : pet.name,
            style: titleTheme ?? Theme.of(context).textTheme.titleLarge,
            overflow: TextOverflow.ellipsis,
          ),
          if (pet != null && pet.gender.icon != null)
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: pet.gender.color,
              ),
              child: Padding(
                padding: EdgeInsetsGeometry.all(2),
                child: Icon(
                  pet.gender.icon,
                  size: 18,
                  color: context.watch<AppearanceController>().secondaryColor,
                ),
              ),
            ),
        ],
      ),
      subtitle: Text(
        description.isEmpty ? 'Порода и возраст' : description,
        style: subTitleTheme ?? Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

enum _DurationUnit { year, month }

String _localizeDuration(int amount, _DurationUnit type) {
  if ((amount >= 5 && amount <= 20) || amount % 10 == 0) {
    return type == _DurationUnit.year ? 'лет' : 'мес.';
  }
  if ((amount % 10) >= 2 && (amount % 10) <= 4) {
    return type == _DurationUnit.year ? 'года' : 'мес.';
  }
  return type == _DurationUnit.year ? 'год' : 'мес.';
}

String formatPetAge(Duration duration) {
  String description = '';
  final inDays = duration.inDays.abs();
  final fullYears = inDays ~/ 365;
  if (fullYears > 0) {
    description +=
        '$fullYears ${_localizeDuration(fullYears, _DurationUnit.year)}';
  }
  final fullMonths = (inDays % 365) ~/ 30;
  if (fullYears > 0 && fullMonths > 0) {
    description += ' и ';
  }
  if (fullMonths > 0) {
    description +=
        '$fullMonths ${_localizeDuration(fullMonths, _DurationUnit.month)}';
  }
  if (description.isEmpty) {
    description += 'совсем маленький';
  }
  return description;
}
