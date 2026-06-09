import 'dart:io';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pill_reminder.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/services/pb_service.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/theme/app_colors.dart';

class Pet implements PbEntity {
  static const codec = _PetCodec();

  final String id;
  String name;
  PetSpecies species;
  PetBreed breed;
  DateTime? birthDate;
  Gender gender;
  bool castrated;
  DateTime? castratedDate;
  String coat;
  String notes;
  String allergies;
  String chronicConditions;
  String vetClinic;
  String chipNumber;
  File? profileImage;
  WeightHistory weightHistory;
  MoodHistory moodHistory;
  NoteHistory noteHistory;
  TreatmentHistory treatmentHistory;
  MealHistory foodHistory;
  List<PillReminder> pillReminders;
  ColorPalette palette;

  Pet({
    this.name = '',
    this.species = BuiltInSpecies.other,
    this.breed = const PetBreed.empty(),
    this.birthDate,
    this.gender = Gender.none,
    this.castrated = false,
    this.castratedDate,
    this.coat = '',
    this.notes = '',
    this.allergies = '',
    this.chronicConditions = '',
    this.vetClinic = '',
    this.chipNumber = '',
    this.profileImage,
  }) : id = generateId(),
        weightHistory = WeightHistory.empty(),
        moodHistory = MoodHistory.empty(),
        noteHistory = NoteHistory.empty(),
        treatmentHistory = TreatmentHistory.empty(),
        foodHistory = MealHistory.empty(),
        pillReminders = [],
        palette = ThemeColors.defaultProfilePalette;

  Pet.deserialize({
    required this.id,
    required this.name,
    required this.species,
    required this.breed,
    required this.birthDate,
    required this.gender,
    this.castrated = false,
    this.castratedDate,
    this.coat = '',
    required this.notes,
    this.allergies = '',
    this.chronicConditions = '',
    this.vetClinic = '',
    this.chipNumber = '',
    required this.profileImage,
    required this.weightHistory,
    required this.moodHistory,
    required this.noteHistory,
    required this.treatmentHistory,
    required this.foodHistory,
    required this.pillReminders,
    required this.palette,
  });

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'species': species.toJson(),
    'breed': breed.toJson(),
    'birthDate': birthDate?.toIso8601String(),
    'gender': gender.caption,
    'castrated': castrated,
    'castratedDate': castratedDate?.toIso8601String(),
    'coat': coat,
    'notes': notes,
    'allergies': allergies,
    'chronicConditions': chronicConditions,
    'vetClinic': vetClinic,
    'chipNumber': chipNumber,
    'profileImage': profileImage?.path,
    'weightHistory': WeightHistory.weightSerializer.toJsonList(weightHistory),
    'moodHistory': MoodHistory.moodSerializer.toJsonList(moodHistory),
    'noteHistory': NoteHistory.noteSerializer.toJsonList(noteHistory),
    'treatmentHistory': TreatmentHistory.treatmentSerializer.toJsonList(
      treatmentHistory,
    ),
    'foodHistory': MealHistory.foodSerializer.toJsonList(foodHistory),
    'pillReminders': pillReminders.map((r) => r.toJson()).toList(),
    'palette': palette.toJson(),
  };

  /// Identity-only JSON — все поля кроме истории (весов, настроений и т.д.).
  /// Используется для синхронизации профиля питомца с облаком.
  Map<String, dynamic> toIdentityJson() => {
    'id': id,
    'name': name,
    'species': species.toJson(),
    'breed': breed.toJson(),
    'birthDate': birthDate?.toIso8601String(),
    'gender': gender.caption,
    'castrated': castrated,
    'castratedDate': castratedDate?.toIso8601String(),
    'coat': coat,
    'notes': notes,
    'allergies': allergies,
    'chronicConditions': chronicConditions,
    'vetClinic': vetClinic,
    'chipNumber': chipNumber,
    'palette': palette.toJson(),
  };

  factory Pet.fromJson(Map<String, dynamic> json) {
    return Pet.deserialize(
      id: json['id'],
      name: json['name'] ?? '',
      species: json['species'] != null
          ? PetSpecies.fromJson(json['species'] as Map<String, dynamic>)
          : BuiltInSpecies.other,
      breed: json['breed'] != null
          ? PetBreed.fromJson(json['breed'] as Map<String, dynamic>)
          : PetBreed.empty(),
      birthDate: json['birthDate'] != null
          ? DateTime.parse(json['birthDate'])
          : null,
      gender: json['gender'] != null
          ? Gender.values.firstWhere((g) => g.caption == json['gender'])
          : Gender.none,
      castrated: json['castrated'] as bool? ?? false,
      castratedDate: json['castratedDate'] != null
          ? DateTime.parse(json['castratedDate'])
          : null,
      coat: json['coat'] as String? ?? '',
      notes: json['notes'] ?? '',
      allergies: json['allergies'] as String? ?? '',
      chronicConditions: json['chronicConditions'] as String? ?? '',
      vetClinic: json['vetClinic'] as String? ?? '',
      chipNumber: json['chipNumber'] as String? ?? '',
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
          ? MealHistory(
        entries: MealHistory.foodSerializer
            .fromJsonList(json['foodHistory'])
            .entries,
      )
          : MealHistory.empty(),
      pillReminders:
      (json['pillReminders'] as List<dynamic>?)
          ?.map((e) => PillReminder.fromJson(e as Map<String, dynamic>))
          .toList() ??
          [],
      palette: json['palette'] != null
          ? ColorPalette.fromJson(json['palette'])
          : ThemeColors.defaultProfilePalette,
    );
  }

  @override
  Map<String, dynamic> toPocketBase(String ownerId) => {
    'id': id,
    'name': name,
    'user': ownerId,
    'species': species.id,
    'breed': breed.id,
    'gender': gender.name,
    'castrated': castrated,
    'castration_date': castratedDate,
    'coat': coat,
    'notes': notes,
    'allergies': allergies,
    'chronic_conditions': chronicConditions,
    'vet_clinic': vetClinic,
    'chip_number': chipNumber,
  };
}

class _PetCodec extends PbCodec<Pet> {
  const _PetCodec();

  @override
  Pet fromPocketBase(Map<String, dynamic> data) {
    final speciesId = data['species'] as String? ?? '';
    final species = BuiltInSpecies.byId(speciesId) ?? BuiltInSpecies.other;

    final breedId = data['breed'] as String? ?? '';
    final breed = breedId.isNotEmpty
        ? PetBreed(id: breedId, name: '', speciesId: species.id)
        : PetBreed.empty();

    final gender = data['gender'] != null
        ? Gender.values.firstWhere(
            (g) => g.name == data['gender'],
            orElse: () => Gender.none,
          )
        : Gender.none;

    final castratedDate = data['castration_date'] != null
        ? DateTime.tryParse(data['castration_date'].toString())
        : null;

    return Pet.deserialize(
      id: data['id'] as String,
      name: data['name'] as String? ?? '',
      species: species,
      breed: breed,
      birthDate: null, // не хранится в toPocketBase
      gender: gender,
      castrated: data['castrated'] as bool? ?? false,
      castratedDate: castratedDate,
      coat: data['coat'] as String? ?? '',
      notes: data['notes'] as String? ?? '',
      allergies: data['allergies'] as String? ?? '',
      chronicConditions: data['chronic_conditions'] as String? ?? '',
      vetClinic: data['vet_clinic'] as String? ?? '',
      chipNumber: data['chip_number'] as String? ?? '',
      profileImage: null,
      weightHistory: WeightHistory.empty(),
      moodHistory: MoodHistory.empty(),
      noteHistory: NoteHistory.empty(),
      treatmentHistory: TreatmentHistory.empty(),
      foodHistory: MealHistory.empty(),
      pillReminders: [],
      palette: ThemeColors.defaultProfilePalette,
    );
  }
}