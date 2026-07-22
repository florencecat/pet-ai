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
import 'package:pet_satellite/services/file_storage_service.dart';
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
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/walk.dart';
import 'package:pet_satellite/models/pet_profile.dart';

class PetContextBuilder {
  /// Собирает полный актуальный контекст питомца для ИИ-ассистента:
  /// профиль, факты здоровья, последние обработки/прививки, активные
  /// препараты и тревожные симптомы из заметок. Пустые поля опускаются,
  /// чтобы не слать ассистенту «null» и не путать его.
  static String build(Pet pet) {
    final lines = <String>[];

    // ── Базовый профиль ──────────────────────────────────────────────────
    lines.add(
      'Имя: ${pet.name.trim().isEmpty ? "не указано" : pet.name.trim()}',
    );
    lines.add(
      'Вид: ${pet.species.name}'
      '${pet.breed.isEmpty ? "" : ", порода ${pet.breed.name}"}',
    );
    if (pet.birthDate != null) {
      final age = formatPetAge(pet.birthDate!.difference(DateTime.now()));
      lines.add('Возраст: $age (род. ${_fmtDate(pet.birthDate!)})');
    }
    final genderBits = <String>[];
    if (pet.gender != Gender.none) genderBits.add(pet.gender.caption);
    if (pet.castrated) genderBits.add('кастрирован/стерилизован');
    if (genderBits.isNotEmpty) lines.add('Пол: ${genderBits.join(", ")}');
    if (pet.coat.trim().isNotEmpty) lines.add('Окрас: ${pet.coat.trim()}');
    lines.add('Вес: ${pet.weightHistory.lastWeightString()}');

    final mood = pet.moodHistory.lastEntry;
    if (mood != null) {
      lines.add('Настроение: ${mood.mood.label} (${_fmtDate(mood.date)})');
    }
    final meal = pet.foodHistory.lastEntry;
    if (meal != null && meal.foodName.trim().isNotEmpty) {
      lines.add(
        'Последнее кормление: ${meal.foodName.trim()} (${_fmtDate(meal.date)})',
      );
    }

    // ── Факты здоровья из профиля ────────────────────────────────────────
    if (pet.allergies.trim().isNotEmpty) {
      lines.add('Аллергии: ${pet.allergies.trim()}');
    }
    if (pet.chronicConditions.trim().isNotEmpty) {
      lines.add('Хронические болезни: ${pet.chronicConditions.trim()}');
    }
    if (pet.notes.trim().isNotEmpty) {
      lines.add('Заметки о питомце: ${pet.notes.trim()}');
    }
    if (pet.vetClinic.trim().isNotEmpty) {
      lines.add('Ветклиника: ${pet.vetClinic.trim()}');
    }
    if (pet.chipNumber.trim().isNotEmpty) {
      lines.add('Чип: ${pet.chipNumber.trim()}');
    }

    // ── Обработки и прививки (последняя запись по каждому виду) ───────────
    final latestTreatment = <String, TreatmentEntry>{};
    for (final t in pet.treatmentHistory.entries) {
      // «Прочие прививки» разделяем по названию, остальные — по виду.
      final key = t.kind == TreatmentKind.vaccine
          ? 'vaccine:${t.name}'
          : t.kind.name;
      final existing = latestTreatment[key];
      if (existing == null || t.date.isAfter(existing.date)) {
        latestTreatment[key] = t;
      }
    }
    if (latestTreatment.isNotEmpty) {
      lines.add('Обработки и прививки:');
      final sorted = latestTreatment.values.toList()
        ..sort((a, b) => a.nextDate.compareTo(b.nextDate));
      for (final t in sorted) {
        lines.add(
          '- ${t.displayName}: последняя ${_fmtDate(t.date)}, '
          'следующая ${_fmtDate(t.nextDate)}',
        );
      }
    }

    // ── Активные курсы препаратов ────────────────────────────────────────
    final activePills = pet.pillReminders.where((p) => p.isActive).toList();
    if (activePills.isNotEmpty) {
      lines.add('Препараты (активные курсы):');
      for (final p in activePills) {
        final bits = <String>[];
        if (p.kind != null) bits.add(p.kind!.name);
        if (p.doseLabel.isNotEmpty) bits.add(p.doseLabel);
        bits.add(p.frequencyLabel);
        if (p.timeLabel.isNotEmpty) bits.add(p.timeLabel);
        lines.add('- ${p.name} (${bits.join(", ")})');
      }
    }

    // ── Тревожные симптомы из заметок (записи с негативными тэгами) ───────
    final symptomNotes =
        pet.noteHistory.entries.where((n) => n.symptomId != null).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    if (symptomNotes.isNotEmpty) {
      lines.add('Тревожные симптомы из заметок (последние):');
      for (final n in symptomNotes.take(5)) {
        final tag = n.symptomTag?.label ?? 'Симптом';
        final txt = n.note.trim();
        final detail = txt.isNotEmpty && txt != tag ? ': $txt' : '';
        lines.add('- ${_fmtDate(n.date)} — $tag$detail');
      }
    }

    return lines.join('\n');
  }

  static String _fmtDate(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
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

/// Уведомляет о смене активного питомца. Вынесен в отдельный класс, чтобы
/// [fire] был доступен только сервису: наружу отдаётся [Listenable], у которого
/// есть лишь add/removeListener (у ChangeNotifier notifyListeners защищён).
class _ActiveProfileNotifier extends ChangeNotifier {
  void fire() => notifyListeners();
}

class PetProfileService {
  static const _profilesKey = 'pet_profiles';
  static const _activeIdKey = 'active_pet_id';

  static final _activeProfile = _ActiveProfileNotifier();

  /// Сигнал «активный питомец сменился».
  ///
  /// Активный профиль меняется из нескольких мест: переключатель на главной,
  /// список в настройках, регистрация нового питомца, удаление активного и
  /// восстановление из облака. Обновлять при этом нужно всегда одно и то же —
  /// палитру, статус здоровья, содержимое вкладок и контекст чата. Полагаться на
  /// то, что каждая площадка не забудет это сделать, не выходит (и не выходило:
  /// настройки обновляли только палитру, а удаление — вообще ничего), поэтому
  /// сигнал шлёт сам сервис, а [MainPage] слушает его и обновляет всё разом.
  ///
  /// Слушателям id не нужен: все перечитывают активный профиль сами.
  static Listenable get activeProfileChanged => _activeProfile;

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

    final path = await FilePicker.platform.getDirectoryPath();
    if (path != null) {
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
    _activeProfile.fire();
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
      // Удаление активного переключает профиль в обход [setActiveProfile],
      // поэтому сигналим и отсюда — иначе палитра, статус здоровья и чат
      // остались бы от удалённого питомца.
      _activeProfile.fire();
    }

    // Каскадная очистка данных питомца — диалог удаления обещает, что все
    // данные удаляются безвозвратно.
    await EventService().clearEvents(petId); // события + снятие уведомлений + облако
    await FileStorageService().clearAll(petId); // локальные файлы документов
    // Питомец со всей историей и файлами в облаке (fire-and-forget, уважает тумблер).
    CloudSyncService.instance.deletePetRemote(petId);
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

  /// Удаляет одну запись питания по её [entryId]. В отличие от удаления по дате,
  /// корректно работает, когда за один день/приём пищи записано несколько блюд.
  Future<void> deleteFoodEntryById(String petId, String entryId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final removed = profile.foodHistory.deleteById(entryId);
      if (removed != null) {
        await saveProfile(profile);
        CloudSyncService.instance.deleteAsync('meals', entryId);
      }
    }
  }

  // ── Прогулки ─────────────────────────────────────────────────────────────

  Future<void> updateWalkHistory(String petId, WalkEntry entry) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final saved = profile.walkHistory.addOrReplace(entry);
      await saveProfile(profile);
      // Fire-and-forget cloud push (saved хранит стабильный id для апсерта).
      CloudSyncService.instance.pushAsync('walks', saved, petId);
    }
  }

  /// Удаляет одну прогулку по её [entryId].
  Future<void> deleteWalkEntryById(String petId, String entryId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final removed = profile.walkHistory.deleteById(entryId);
      if (removed != null) {
        await saveProfile(profile);
        CloudSyncService.instance.deleteAsync('walks', entryId);
      }
    }
  }

  Future<void> clearWalkHistory(String petId) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      profile.walkHistory.clear();
      await saveProfile(profile);
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

  Future<void> addNote(
    String petId,
    String note, {
    String? symptomId,
    SymptomSeverity? severity,
  }) async {
    final profile = await loadProfile(petId);
    if (profile != null) {
      final entry = await profile.noteHistory.addNote(
        note,
        symptomId: symptomId,
        severity: severity,
      );
      await saveProfile(profile);
      // Fire-and-forget cloud push for the created note entry.
      CloudSyncService.instance.pushAsync('notes', entry, petId);
    }
  }

  /// Удаляет заметку вместе с её событием в календаре.
  Future<void> deleteNoteEntry(String petId, String noteId) async {
    final profile = await loadProfile(petId);
    if (profile == null) return;

    final removed = profile.noteHistory.deleteById(noteId);
    if (removed == null) return;
    await saveProfile(profile);
    CloudSyncService.instance.deleteAsync('notes', removed.id);
    await EventService().deleteBySource(petId, removed.id);
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
    List<Widget>? additional,
  }) {
    String description = pet?.breed.name ?? '';
    if (description.isEmpty) {
      description = pet?.species.name ?? 'Спутник';
    }
    if (pet?.birthDate != null) {
      final duration = pet!.birthDate!.difference(DateTime.now());
      description = '$description · ${formatPetAge(duration)}';
    }

    final subtitleText = Text(
      description.isEmpty ? 'Порода и возраст' : description,
      style: subTitleTheme ?? Theme.of(context).textTheme.bodySmall,
    );

    return ListTile(
      leading: leading,
      trailing: trailing,
      title: Row(
        spacing: 6,
        children: [
          Flexible(
            child: Text(
              pet == null || pet.name.isEmpty ? 'Без имени' : pet.name,
              style: titleTheme ?? Theme.of(context).textTheme.titleLarge,
              overflow: TextOverflow.ellipsis,
            ),
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
      // [additional] — доп. виджеты под подписью (напр. бейдж кастрации).
      subtitle: additional == null || additional.isEmpty
          ? subtitleText
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                subtitleText,
                const SizedBox(height: 6),
                ...additional,
              ],
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
