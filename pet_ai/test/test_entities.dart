import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/models/suggested_event.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/models/weight.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';

/// Прогоняет map через полный цикл JSON-кодирования — так, как это реально
/// происходит при сохранении в SharedPreferences и при отправке в PocketBase
/// (клиент вызывает jsonEncode тела запроса, а .data ответа уже декодирован).
///
/// Сравнение Map «в памяти» этот шаг пропускает и не замечает поля, которые не
/// сериализуются в JSON (сырой DateTime, Set) или меняют тип при декодировании.
Map<String, dynamic> jsonRoundTrip(Map<String, dynamic> map) =>
    jsonDecode(jsonEncode(map)) as Map<String, dynamic>;

// ─── Pet ──────────────────────────────────────────────────────────────────────

Pet goodPetEntity() {
  return Pet(
    name: 'Барни',
    species: BuiltInSpecies.dog,
    breed: PetBreedService.dogBreeds().first,
    birthDate: DateTime(2025, 4, 1),
    gender: Gender.male,
    castrated: true,
    castratedDate: DateTime(2024, 6, 15),
    coat: 'Это окрас. У Барни трехцветный окрас.',
    notes: 'Биография Барни',
    allergies: 'Аллергия на рыбку',
    chronicConditions: 'Хронический бронхит',
    vetClinic: 'Народная медицина',
    chipNumber: '12345678910111',
    profileImage: null,
  );
}

void validatePets(Pet a, Pet b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  validateSpecies(a.species, b.species);
  validateBreed(a.breed, b.breed);
  expect(a.birthDate, b.birthDate);
  expect(a.gender, b.gender);
  expect(a.castrated, b.castrated);
  expect(a.castratedDate, b.castratedDate);
  expect(a.coat, b.coat);
  expect(a.notes, b.notes);
  expect(a.allergies, b.allergies);
  expect(a.chronicConditions, b.chronicConditions);
  expect(a.vetClinic, b.vetClinic);
  expect(a.chipNumber, b.chipNumber);
  expect(a.profileImage, b.profileImage);
}

void validateSpecies(PetSpecies a, PetSpecies b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.emoji, b.emoji);
}

void validateBreed(PetBreed a, PetBreed b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.speciesId, b.speciesId);
}

// ─── Event ──────────────────────────────────────────────────────────────────────

Event goodEventEntity() {
  final e = Event(
    name: 'Приём габапентина',
    category: EventCategories.health,
    dateTime: DateTime(2025, 2, 10, 14, 30),
    repeat: RepeatInterval.custom,
    customDays: const [1, 3, 5],
    repeatEndDate: DateTime(2025, 6, 1),
    allDay: false,
    remindBeforeVariant: RemindBeforeVariant.hours,
    remindBeforeValue: 2,
    remind: true,
    petIds: ['pet_a', 'pet_b'],
    source: EventSource.pill,
    sourceId: 'pill_1',
    styleKindId: PillKind.capsule.id,
    color: 0xFF112233,
  );
  e.completedDates.addAll({'2025-02-10', '2025-02-12'});
  return e;
}

void validateEvent(Event a, Event b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.category.id, b.category.id);
  expect(a.dateTime, b.dateTime);
  // completedDates — Set: сравниваем отсортированные списки (порядок не важен).
  expect(a.completedDates.toList()..sort(), b.completedDates.toList()..sort());
  expect(a.petIds, b.petIds);
  expect(a.repeat, b.repeat);
  expect(a.customDays, b.customDays);
  expect(a.repeatEndDate, b.repeatEndDate);
  expect(a.allDay, b.allDay);
  expect(a.remindBeforeVariant, b.remindBeforeVariant);
  expect(a.remindBeforeValue, b.remindBeforeValue);
  expect(a.remind, b.remind);
  expect(a.source, b.source);
  expect(a.sourceId, b.sourceId);
  expect(a.styleKindId, b.styleKindId);
  expect(a.color, b.color);
  expect(a.symptomTag, b.symptomTag);
}

// ─── Pill ──────────────────────────────────────────────────────────────────────

Pill goodPillEntity() {
  return Pill(
    id: 'pill_1',
    name: 'Габапентин',
    kind: PillKind.capsule,
    color: 0xFF3366FF,
    doseValue: 2,
    doseUnit: DoseUnit.capsule,
    frequencyType: PillFrequencyType.weekdays,
    weekdays: const [1, 3, 5],
    schedules: [
      PillSchedule(
        id: 'sch_morning',
        hour: 9,
        minute: 0,
        eventId: 'evt_pill_morning',
      ),
      PillSchedule(
        id: 'sch_evening',
        hour: 21,
        minute: 30,
        eventId: 'evt_pill_evening',
      ),
    ],
    startDate: DateTime(2025, 1, 1),
    endDate: DateTime(2025, 3, 1),
    // Отметки о приёме — по id расписаний, а не по их позиции в списке.
    takenSchedules: const {
      '2025-01-06': ['sch_morning', 'sch_evening'],
    },
    intakes: const [],
    remindBeforeValue: 30,
    remindBeforeVariant: RemindBeforeVariant.minutes,
  );
}

/// Отдельный эталон «по требованию»: у него журнал приёмов (intakes) сериализуется
/// иным путём (в поле taken_dates), поэтому это самостоятельный тест-кейс.
Pill goodOnDemandPillEntity() {
  return Pill(
    id: 'pill_od',
    name: 'Но-шпа',
    kind: PillKind.pill,
    doseValue: 0,
    doseUnit: DoseUnit.none,
    frequencyType: PillFrequencyType.onDemand,
    weekdays: const [],
    schedules: [PillSchedule(id: 'sch_od', hour: 9, minute: 0)],
    startDate: DateTime(2025, 1, 1),
    takenSchedules: const {},
    intakes: [
      PillIntake(
        time: DateTime(2025, 1, 7, 8, 0),
        doseValue: 1,
        doseUnit: DoseUnit.tablet,
      ),
      PillIntake(time: DateTime(2025, 1, 7, 20, 0)),
    ],
    remindBeforeValue: 0,
    remindBeforeVariant: RemindBeforeVariant.minutes,
  );
}

void validatePill(Pill a, Pill b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.kind?.id, b.kind?.id);
  expect(a.color, b.color);
  expect(a.doseValue, b.doseValue);
  expect(a.doseUnit, b.doseUnit);
  expect(a.frequencyType, b.frequencyType);
  expect(a.weekdays, b.weekdays);
  validateSchedules(a.schedules, b.schedules);
  expect(a.startDate, b.startDate);
  expect(a.endDate, b.endDate);
  expect(a.takenSchedules, b.takenSchedules);
  validateIntakes(a.intakes, b.intakes);
  expect(a.remindBeforeValue, b.remindBeforeValue);
  expect(a.remindBeforeVariant, b.remindBeforeVariant);
}

/// Расписания сравниваем поимённо, а не через ==: оно у [PillSchedule] задано
/// по времени суток, поэтому потерю id или eventId не заметило бы. А это ровно
/// то, что ломает отметки о приёме (id) и уведомления (eventId).
void validateSchedules(List<PillSchedule> a, List<PillSchedule> b) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i].id, b[i].id);
    expect(a[i].hour, b[i].hour);
    expect(a[i].minute, b[i].minute);
    expect(a[i].eventId, b[i].eventId);
  }
}

// PillIntake не переопределяет ==, поэтому сравниваем поэлементно по полям.
void validateIntakes(List<PillIntake> a, List<PillIntake> b) {
  expect(a.length, b.length);
  for (var i = 0; i < a.length; i++) {
    expect(a[i].time, b[i].time);
    expect(a[i].doseValue, b[i].doseValue);
    expect(a[i].doseUnit, b[i].doseUnit);
  }
}

// ─── TreatmentEntry ──────────────────────────────────────────────────────────────

TreatmentEntry goodTreatmentEntity() {
  return TreatmentEntry(
    id: 'tr_1',
    date: DateTime(2025, 1, 10),
    kind: TreatmentKind.vaccine,
    name: 'Нобивак',
    nextDate: DateTime(2026, 1, 10),
    remindBeforeValue: 14,
    remindBeforeVariant: RemindBeforeVariant.days,
    eventId: 'evt_tr_1',
    color: 0xFF00AA55,
  );
}

/// remindBefore и eventId здесь НЕ проверяются:
///  - eventId — локальная связь, в облако не уходит;
///  - remindBefore у обработок в PocketBase-схеме хранится иначе, чем читается
///    (пишется remind_before_value/variant, читается remind_before_days) —
///    через облако значение/вариант не восстанавливаются.
/// Оба поля проверяются отдельно в JSON-тесте, где схема симметрична.
void validateTreatment(TreatmentEntry a, TreatmentEntry b) {
  expect(a.id, b.id);
  expect(a.date, b.date);
  expect(a.kind, b.kind);
  expect(a.name, b.name);
  expect(a.nextDate, b.nextDate);
  expect(a.color, b.color);
}

// ─── MealEntry ──────────────────────────────────────────────────────────────────

MealEntry goodMealEntity() {
  return MealEntry(
    id: 'meal_1',
    date: DateTime(2025, 1, 3, 8, 0),
    mealTime: MealTime.evening,
    appetiteScore: 4,
    grams: 150,
    foodName: 'Курица',
    kind: FoodKind.dry,
  );
}

void validateMeal(MealEntry a, MealEntry b) {
  expect(a.id, b.id);
  expect(a.date, b.date);
  expect(a.mealTime, b.mealTime);
  expect(a.appetiteScore, b.appetiteScore);
  expect(a.grams, b.grams);
  expect(a.foodName, b.foodName);
  expect(a.kind, b.kind);
}

// ─── MoodEntry ──────────────────────────────────────────────────────────────────

MoodEntry goodMoodEntity() {
  return MoodEntry(
    id: 'mood_1',
    date: DateTime(2025, 1, 2, 20, 30),
    mood: PetMood.happy,
    dayPart: DayPart.evening,
  );
}

void validateMood(MoodEntry a, MoodEntry b) {
  expect(a.id, b.id);
  expect(a.date, b.date);
  expect(a.mood, b.mood);
  expect(a.dayPart, b.dayPart);
}

// ─── NoteEntry ──────────────────────────────────────────────────────────────────

NoteEntry goodNoteEntity() {
  return NoteEntry(
    id: 'note_1',
    date: DateTime(2025, 1, 4, 10, 0),
    note: 'Кот отказался от еды утром',
    symptomId: SymptomTags.refusedFood.id,
  );
}

void validateNote(NoteEntry a, NoteEntry b) {
  expect(a.id, b.id);
  expect(a.date, b.date);
  expect(a.note, b.note);
  expect(a.symptomId, b.symptomId);
}

// ─── WeightEntry ──────────────────────────────────────────────────────────────

WeightEntry goodWeightEntity() {
  return WeightEntry(id: 'w_1', date: DateTime(2025, 1, 5), weight: 12.3);
}

void validateWeight(WeightEntry a, WeightEntry b) {
  expect(a.id, b.id);
  expect(a.date, b.date);
  expect(a.weight, b.weight);
}

// ─── SuggestedEvent (только локальный JSON, внутри ChatMessage.eventsJson) ───────

SuggestedEvent goodSuggestedEvent() {
  return SuggestedEvent(
    name: 'Дать таблетку',
    categoryId: EventCategories.health.id,
    dateTime: DateTime(2025, 1, 6, 9, 0),
    repeat: RepeatInterval.weekly,
    raw: const {
      'name': 'Дать таблетку',
      'category': 'health',
      'datetime': '2025-01-06T09:00:00.000',
      'repeat': 'weekly',
    },
    status: SuggestedEventStatus.created,
    createdEventId: 'ev_1',
  );
}

void validateSuggested(SuggestedEvent a, SuggestedEvent b) {
  expect(a.name, b.name);
  expect(a.categoryId, b.categoryId);
  expect(a.dateTime, b.dateTime);
  expect(a.repeat, b.repeat);
  expect(a.status, b.status);
  expect(a.createdEventId, b.createdEventId);
  expect(a.raw, b.raw);
}

// ─── UserProfile (только локальный JSON) ─────────────────────────────────────────

UserProfile goodUserProfile() {
  return const UserProfile(
    id: 'u_1',
    name: 'Иван',
    email: 'ivan@example.com',
    city: 'Москва',
    emailVerified: true,
  );
}

void validateUserProfile(UserProfile a, UserProfile b) {
  expect(a.id, b.id);
  expect(a.name, b.name);
  expect(a.email, b.email);
  expect(a.city, b.city);
  expect(a.emailVerified, b.emailVerified);
}
