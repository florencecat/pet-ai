import 'dart:developer';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pet_ai/models/note.dart';
import 'package:pet_ai/models/species.dart';
import 'package:pet_ai/theme/app_colors.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

import 'package:pet_ai/models/weight.dart';
import 'package:pet_ai/models/mood.dart';
import 'package:pet_ai/models/treatment.dart';
import 'package:pet_ai/models/food.dart';

class PetContextBuilder {
  static String build(PetProfile pet) {
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
}

class PetProfile {
  final String id;
  String name;
  PetSpecies species;
  String breed;
  DateTime? birthDate;
  Gender gender;
  String notes;
  File? profileImage;
  WeightHistory weightHistory;
  MoodHistory moodHistory;
  NoteHistory noteHistory;
  TreatmentHistory treatmentHistory;
  FoodHistory foodHistory;
  Color color;

  PetProfile({
    this.name = '',
    this.species = BuiltInSpecies.other,
    this.breed = '',
    this.birthDate,
    this.gender = Gender.none,
    this.notes = '',
    this.profileImage,
  }) : id = UniqueKey().toString(),
        weightHistory = WeightHistory.empty(),
        moodHistory = MoodHistory.empty(),
        noteHistory = NoteHistory.empty(),
        treatmentHistory = TreatmentHistory.empty(),
        foodHistory = FoodHistory.empty(),
        color = ThemeColors.defaultProfileColor;

  PetProfile.deserialize({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.notes,
    required this.profileImage,
    required this.weightHistory,
    required this.moodHistory,
    required this.noteHistory,
    required this.treatmentHistory,
    required this.foodHistory,
    required this.color,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species.toJson(),
    'breed': breed,
    'birthDate': birthDate?.toIso8601String(),
    'gender': gender.caption,
    'notes': notes,
    'profileImage': profileImage?.path,
    'weightHistory': WeightHistory.weightSerializer.toJsonList(weightHistory),
    'moodHistory': MoodHistory.moodSerializer.toJsonList(moodHistory),
    'noteHistory': NoteHistory.noteSerializer.toJsonList(noteHistory),
    'treatmentHistory':
        TreatmentHistory.treatmentSerializer.toJsonList(treatmentHistory),
    'foodHistory': FoodHistory.foodSerializer.toJsonList(foodHistory),
    'color': color.toARGB32(),
  };

  factory PetProfile.fromJson(Map<String, dynamic> json) {
    return PetProfile.deserialize(
      id: json['id'],
      name: json['name'] ?? '',
      species: json['species'] != null
          ? PetSpecies.fromJson(json['species'] as Map<String, dynamic>)
          : BuiltInSpecies.other,
      breed: json['breed'] ?? '',
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'])
          : null,
      gender: json['gender'] != null
          ? Gender.values.firstWhere(
            (g) => g.caption == json['gender'],
      )
          : Gender.none,
      notes: json['notes'] ?? '',
      profileImage: json['profileImage'] != null
          ? File(json['profileImage'])
          : null,
      weightHistory: json['weightHistory'] != null
          ? WeightHistory(
        entries: WeightHistory.weightSerializer
            .fromJsonList(json['weightHistory'])
            .entries,
      )
          : WeightHistory.empty(),
      moodHistory: json['moodHistory'] != null
          ? MoodHistory(
        entries: MoodHistory.moodSerializer
            .fromJsonList(json['moodHistory'])
            .entries,
      )
          : MoodHistory.empty(),
      noteHistory: json['noteHistory'] != null
          ? NoteHistory(
        entries: NoteHistory.noteSerializer
            .fromJsonList(json['noteHistory'])
            .entries,
      )
          : NoteHistory.empty(),
      treatmentHistory: json['treatmentHistory'] != null
          ? TreatmentHistory(
              entries: TreatmentHistory.treatmentSerializer
                  .fromJsonList(json['treatmentHistory'])
                  .entries,
            )
          : TreatmentHistory.empty(),
      foodHistory: json['foodHistory'] != null
          ? FoodHistory(
              entries: FoodHistory.foodSerializer
                  .fromJsonList(json['foodHistory'])
                  .entries,
            )
          : FoodHistory.empty(),
      color: json['color'] != null
          ? Color(json['color'] as int)
          : ThemeColors.defaultProfileColor,
    );
  }
}

class ProfileService {
  static const _profilesKey = 'pet_profiles';
  static const _activeIdKey = 'active_pet_id';

  // ─── Чтение/запись всей коллекции ────────────────────────────────────────

  Future<List<PetProfile>> loadAllProfiles() async {
    final prefs = SharedPreferencesAsync();
    final jsonStr = await prefs.getString(_profilesKey);
    if (jsonStr == null) return [];
    try {
      final list = jsonDecode(jsonStr) as List<dynamic>;
      return list
          .map((e) => PetProfile.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (e) {
      log('ProfileService.loadAllProfiles: $e');
      return [];
    }
  }

  Future<void> _saveAllProfiles(List<PetProfile> profiles) async {
    final jsonStr = jsonEncode(profiles.map((p) => p.toJson()).toList());
    await SharedPreferencesAsync().setString(_profilesKey, jsonStr);
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
  Future<PetProfile?> loadActiveProfile() async {
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

  Future<PetProfile?> loadProfile(String petId) async {
    final profiles = await loadAllProfiles();
    try {
      return profiles.firstWhere((p) => p.id == petId);
    } catch (_) {
      return null;
    }
  }

  /// Добавляет новый профиль. Если это первый профиль — делает его активным.
  Future<void> addProfile(PetProfile profile) async {
    final profiles = await loadAllProfiles();
    profiles.add(profile);
    await _saveAllProfiles(profiles);

    if (profiles.length == 1) {
      await SharedPreferencesAsync().setString(_activeIdKey, profile.id);
    }
  }

  /// Сохраняет (обновляет) существующий профиль по [profile.id].
  Future<void> saveProfile(PetProfile profile) async {
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
      profile.weightHistory.addWeight(weight);
      await saveProfile(profile);
    }
  }

  Future<void> updateMoodHistory(String petId, MoodEntry entry) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.moodHistory.add(entry);
      await saveProfile(profile);
    }
  }

  Future<void> updateFoodHistory(String petId, FoodEntry entry) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.foodHistory.add(entry);
      await saveProfile(profile);
    }
  }

  Future<void> deleteFoodEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.foodHistory.deleteEntry(date);
      await saveProfile(profile);
    }
  }

  Future<void> deleteWeightEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.weightHistory.deleteEntry(date);
      await saveProfile(profile);
    }
  }

  Future<void> deleteMoodEntry(String petId, DateTime date) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.moodHistory.deleteEntry(date);
      await saveProfile(profile);
    }
  }

  Future<void> addNote(String petId, String note) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.noteHistory.addNote(note);
      await saveProfile(profile);
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
    return avatarFile.path;
  }

  Future<String?> pickProfileImage(String petId) async {
    final picker = ImagePicker();

    final pickedFile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 90,
    );

    if (pickedFile == null) return null;

    final cropped = await ImageCropper().cropImage(
      sourcePath: pickedFile.path,
      compressQuality: 90,
      compressFormat: ImageCompressFormat.jpg,
      maxWidth: 256,
      maxHeight: 256,
      aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
    );

    if (cropped == null) return null;

    return await _saveAvatarToAppDir(petId, cropped.path);
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
    description += '$fullYears ${_localizeDuration(fullYears, _DurationUnit.year)}';
  }
  final fullMonths = (inDays % 365) ~/ 30;
  if (fullYears > 0 && fullMonths > 0) {
    description += ' и ';
  }
  if (fullMonths > 0) {
    description += '$fullMonths ${_localizeDuration(fullMonths, _DurationUnit.month)}';
  }
  if (description.isEmpty) {
    description += 'совсем маленький';
  }
  return description;
}