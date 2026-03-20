import 'dart:developer';
import 'dart:io';
import 'package:flutter/cupertino.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

enum WeightPeriod { month, year, all }

class WeightEntry {
  final DateTime date;
  final double weight;

  WeightEntry({required this.date, required this.weight});

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    return WeightEntry(
      date: DateTime.parse(json['date']),
      weight: (json['weight'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {'date': date.toIso8601String(), 'weight': weight};
  }
}

class WeightHistory {
  final List<WeightEntry> entries;

  WeightHistory({required this.entries});
  WeightHistory.empty() : entries = [];

  factory WeightHistory.fromJson(List<dynamic> json) {
    return WeightHistory(
      entries: json.map((e) => WeightEntry.fromJson(e)).toList(),
    );
  }

  List<Map<String, dynamic>> toJson() {
    return entries.map((e) => e.toJson()).toList();
  }

  void add(double weight) {
    entries.add(
      WeightEntry(
        date: DateTime.now(),
        weight: double.parse(weight.toStringAsFixed(1)),
      ),
    );
  }

  void deleteEntry(DateTime date) => entries.removeWhere((e) => e.date == date);

  void clear() => entries.clear();

  double? get lastWeight {
    if (entries.isEmpty) return null;
    return entries.last.weight;
  }

  List<WeightEntry> filterByPeriod(WeightPeriod period) {
    final now = DateTime.now();

    switch (period) {
      case WeightPeriod.month:
        final start = now.subtract(const Duration(days: 30));
        return entries.where((e) => e.date.isAfter(start)).toList();

      case WeightPeriod.year:
        final start = DateTime(now.year - 1, now.month, now.day);
        return entries.where((e) => e.date.isAfter(start)).toList();

      case WeightPeriod.all:
        return entries;
    }
  }
}

// Профиль питомца
class PetProfile {
  final String id;
  String name;
  String breed;
  DateTime? birthDate;
  String gender;
  String notes;
  File? profileImage;
  WeightHistory weightHistory;

  PetProfile({
    this.name = '',
    this.breed = '',
    this.birthDate,
    this.gender = 'Не указан',
    this.notes = '',
    this.profileImage,
  }) : id = UniqueKey().toString(), weightHistory = WeightHistory.empty();

  PetProfile.deserialize({
    required this.id,
    required this.name,
    required this.breed,
    required this.birthDate,
    required this.gender,
    required this.notes,
    required this.profileImage,
    required this.weightHistory,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'breed': breed,
    'birthDate': birthDate?.toIso8601String(),
    'gender': gender,
    'notes': notes,
    'profileImage': profileImage?.path,
    'weightHistory': weightHistory.toJson()
  };

  factory PetProfile.fromJson(Map<String, dynamic> json) => PetProfile.deserialize(
    id: json['id'],
    name: json['name'] ?? '',
    breed: json['breed'] ?? '',
    birthDate: json['birthDate'] != null
        ? DateTime.parse(json['birthDate'])
        : null,
    gender: json['gender'] ?? 'Не указан',
    notes: json['notes'] ?? '',
    profileImage: json['profileImage'] != null
        ? File(json['profileImage'])
        : null,
    weightHistory: WeightHistory.fromJson(json['weightHistory'] ?? [])
  );
}

enum FormattingType { year, month }

class ProfileService {
  static const _key = 'pet_profile';

  Future<PetProfile?> loadProfile() async {
    final jsonStr = await SharedPreferencesAsync().getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return PetProfile.fromJson(map);
      } catch (e) {
        log(e.toString());
      }
    }
    return null;
  }

  Future<void> clearProfile() async =>
      await SharedPreferencesAsync().remove(_key);

  Future<bool> hasProfile() async =>
      await SharedPreferencesAsync().containsKey(_key);

  Future<void> saveProfile(PetProfile profile) async {
    await SharedPreferencesAsync().setString(
      _key,
      jsonEncode(profile.toJson()),
    );
  }

  Future<void> clearWeightHistory() async {
    final profile = await loadProfile();
    if (profile != null) {
      profile.weightHistory.clear();
      saveProfile(profile);
    }
  }

  Future<String> _saveAvatarToAppDir(String tempPath) async {
    final directory = await getApplicationDocumentsDirectory();
    final avatarPath = '${directory.path}/avatar.png';
    final avatarFile = await File(tempPath).copy(avatarPath);
    return avatarFile.path;
  }

  Future<String?> pickProfileImage() async {
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
      // uiSettings: [
      //   AndroidUiSettings(
      //     toolbarTitle: 'Обрезка фото',
      //     toolbarColor: mainColor,
      //     toolbarWidgetColor: Colors.white,
      //     activeControlsWidgetColor: mainColor,
      //     lockAspectRatio: true,
      //     hideBottomControls: false,
      //   ),
      //   IOSUiSettings(
      //     title: 'Обрезка фото',
      //     aspectRatioLockEnabled: true,
      //   ),
      // ],
    );

    if (cropped == null) return null;

    return await _saveAvatarToAppDir(cropped.path);
  }

  String localizeDuration(int amount, FormattingType type) {
    if ((amount >= 5 && amount <= 20) || amount % 10 == 0) {
      return type == FormattingType.year ? 'лет' : 'мес.';
    }
    if ((amount % 10) >= 2 && (amount % 10) <= 4) {
      return type == FormattingType.year ? 'года' : 'мес.';
    }
    return type == FormattingType.year ? 'год' : 'мес.';
  }

  String formatAge(Duration duration) {
    String description = '';
    final inYears = duration.inDays.abs();
    final fullYears = (inYears / 365).toInt();
    if (fullYears > 0) {
      description +=
          '$fullYears ${localizeDuration(fullYears, FormattingType.year)}';
    }
    final fullMonths = ((inYears % 365) / 30).toInt();
    if (fullYears > 0 && fullMonths > 0) {
      description += ' и ';
    }
    if (fullMonths > 0) {
      description +=
          '$fullMonths ${localizeDuration(fullMonths, FormattingType.month)}';
    } else {
      description += 'совсем маленький';
    }
    return description;
  }
}
