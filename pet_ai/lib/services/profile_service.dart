import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';

class PetProfile {
  String name;
  String breed;
  DateTime? birthDate;
  double? weightKg;
  String gender;
  String notes;

  PetProfile({
    this.name = '',
    this.breed = '',
    this.birthDate,
    this.weightKg,
    this.gender = 'Не указан',
    this.notes = '',
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'breed': breed,
    'birthDate': birthDate?.toIso8601String(),
    'weightKg': weightKg,
    'gender': gender,
    'notes': notes,
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
  );
}

enum FormattingType{
  year,
  month
}
class ProfileService {
  static const _key = 'pet_profile';

  Future<PetProfile> loadProfile() async {
    final jsonStr = await SharedPreferencesAsync().getString(_key);
    if (jsonStr != null) {
      try {
        final map = jsonDecode(jsonStr) as Map<String, dynamic>;
        return PetProfile.fromJson(map);
      } catch (e) {}
    }
    return PetProfile();
  }

  Future<void> clearProfile() async => await SharedPreferencesAsync().remove(_key);

  Future<bool> hasProfile() async => await SharedPreferencesAsync().containsKey(_key);

  Future<void> saveProfile(PetProfile profile) async {
    await SharedPreferencesAsync().setString(
      _key,
      jsonEncode(profile.toJson()),
    );
  }


  String localizeDuration(int amount, FormattingType type) {
    if ((amount >= 5 && amount <= 20) || amount % 10 == 0) {
      return type == FormattingType.year ? 'лет' : 'месяцев';
    }
    if ((amount % 10) >= 2 && (amount % 10) <= 4) {
      return type == FormattingType.year ? 'года' : 'месяца';
    }
    return type == FormattingType.year ? 'год' : 'месяц';
  }

  String formatAge(Duration duration) {
    String description = '';
    final inYears = duration.inDays.abs();
    final fullYears = (inYears / 365).toInt();
    if (fullYears > 0) {
      description += '$fullYears ${localizeDuration(fullYears, FormattingType.year)}';
      // if ((fullYears >= 5 && fullYears <= 20) || fullYears % 10 == 0) {
      //   description += '$fullYears лет';
      // } else if ((fullYears % 10) >= 2 && (fullYears % 10) <= 4) {
      //   description += '$fullYears года';
      // } else {
      //   description += '$fullYears год';
      // }
    }
    final fullMonths = ((inYears % 365) / 30).toInt();
    if (fullYears > 0 && fullMonths > 0) {
      description += ' и ';
    }
    if (fullMonths > 0) {
      description += '$fullMonths ${localizeDuration(fullMonths, FormattingType.month)}';
    }
    else {
      description += 'совсем маленький';
    }
    // description += ' - ${ }';

    return description;
  }
}
