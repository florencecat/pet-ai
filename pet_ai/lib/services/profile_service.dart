import 'dart:developer';
import 'dart:io';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

import 'package:path_provider/path_provider.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

class PetProfile {
  String name;
  String breed;
  DateTime? birthDate;
  double? weightKg;
  String gender;
  String notes;
  File? profileImage;

  PetProfile({
    this.name = '',
    this.breed = '',
    this.birthDate,
    this.weightKg,
    this.gender = 'Не указан',
    this.notes = '',
    this.profileImage,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'breed': breed,
    'birthDate': birthDate?.toIso8601String(),
    'weightKg': weightKg,
    'gender': gender,
    'notes': notes,
    'profileImage': profileImage?.path,
  };

  factory PetProfile.fromJson(Map<String, dynamic> json) => PetProfile(
    name: json['name'] ?? '',
    breed: json['breed'] ?? '',
    birthDate: json['birthDate'] != null
        ? DateTime.parse(json['birthDate'])
        : null,
    weightKg: json['weightKg'] != null
        ? (json['weightKg'] as num).toDouble()
        : null,
    gender: json['gender'] ?? 'Не указан',
    notes: json['notes'] ?? '',
    profileImage: json['profileImage'] != null
        ? File(json['profileImage'])
        : null,
  );
}

enum FormattingType { year, month }

class ProfileService {
  static const _key = 'pet_profile';

  Future<PetProfile> loadProfile() async {
    final jsonStr = await SharedPreferencesAsync().getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return PetProfile.fromJson(map);
      } catch (e) {
        log(e.toString());
      }
    }
    return PetProfile();
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
