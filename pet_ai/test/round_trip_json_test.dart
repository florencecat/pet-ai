import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/models/event.dart';
import 'package:pet_satellite/models/meal.dart';
import 'package:pet_satellite/models/mood.dart';
import 'package:pet_satellite/models/note.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/models/suggested_event.dart';
import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/models/user_profile.dart';
import 'package:pet_satellite/models/walk.dart';
import 'package:pet_satellite/models/weight.dart';
import 'test_entities.dart';

/// Round-trip сериализации всех доменных сущностей.
///
/// Для каждой модели проверяем оба независимых канала:
///  - локальный JSON (toJson → SharedPreferences/Hive → fromJson);
///  - облачный (toPocketBase → PocketBase → fromPocketBase).
/// Оба прогоняются через jsonRoundTrip (реальный jsonEncode/Decode), чтобы
/// ловить не-JSON-значения и смену типов при декодировании.
void main() {
  group('Pet round-trip', () {
    test('json', () {
      final pet = goodPetEntity();
      validatePets(pet, Pet.fromJson(jsonRoundTrip(pet.toJson())));
    });

    test('pocketbase', () {
      final pet = goodPetEntity();
      validatePets(
        pet,
        Pet.codec.fromPocketBase(jsonRoundTrip(pet.toPocketBase(''))),
      );
    });
  });

  group('Event round-trip', () {
    test('json', () {
      final e = goodEventEntity();
      validateEvent(e, Event.fromJson(jsonRoundTrip(e.toJson())));
    });

    test('pocketbase', () {
      final e = goodEventEntity();
      validateEvent(
        e,
        Event.codec.fromPocketBase(jsonRoundTrip(e.toPocketBase(''))),
      );
    });

    // Событие, записанное до появления EventOrigin: тип источника в хранилище
    // есть, id родителя — нет. Родителя по такому не найти, но выглядеть и
    // вести себя как созданное вручную (редактируемое, с иконкой категории)
    // оно не должно.
    test('json без sourceId остаётся событием заметки', () {
      final restored = Event.fromJson({
        'id': 'ev_legacy',
        'name': 'Отказ от еды',
        'category': EventCategories.empty.id,
        'dateTime': '2025-01-04T10:00:00.000',
        'source': 'note',
        'symptomTag': SymptomTags.refusedFood.id,
      });

      expect(restored.origin, isA<NoteOrigin>());
      expect(restored.manual, isFalse);
      // Пустой id обратно в хранилище не уезжает — формат не меняется.
      expect(restored.toJson().containsKey('sourceId'), isFalse);
    });
  });

  group('Pill round-trip', () {
    test('json', () {
      final p = goodPillEntity();
      final restored = Pill.fromJson(jsonRoundTrip(p.toJson()));
      validatePill(p, restored);
    });

    test('pocketbase', () {
      final p = goodPillEntity();
      validatePill(
        p,
        Pill.codec.fromPocketBase(jsonRoundTrip(p.toPocketBase(''))),
      );
    });

    test('on-demand json', () {
      final p = goodOnDemandPillEntity();
      validatePill(p, Pill.fromJson(jsonRoundTrip(p.toJson())));
    });

    test('on-demand pocketbase', () {
      final p = goodOnDemandPillEntity();
      validatePill(
        p,
        Pill.codec.fromPocketBase(jsonRoundTrip(p.toPocketBase(''))),
      );
    });
  });

  group('TreatmentEntry round-trip', () {
    test('json', () {
      final t = goodTreatmentEntity();
      final restored = TreatmentEntry.fromJson(jsonRoundTrip(t.toJson()));
      validateTreatment(t, restored);
      // Локальная схема симметрична — remindBefore и eventId обязаны сохраниться.
      expect(restored.remindBeforeValue, t.remindBeforeValue);
      expect(restored.remindBeforeVariant, t.remindBeforeVariant);
      expect(restored.eventId, t.eventId);
    });

    test('pocketbase', () {
      final t = goodTreatmentEntity();
      validateTreatment(
        t,
        TreatmentEntry.codec.fromPocketBase(jsonRoundTrip(t.toPocketBase(''))),
      );
    });
  });

  group('MealEntry round-trip', () {
    test('json', () {
      final m = goodMealEntity();
      validateMeal(m, MealEntry.fromJson(jsonRoundTrip(m.toJson())));
    });

    test('pocketbase', () {
      final m = goodMealEntity();
      validateMeal(
        m,
        MealEntry.codec.fromPocketBase(jsonRoundTrip(m.toPocketBase(''))),
      );
    });
  });

  group('WalkEntry round-trip', () {
    test('json', () {
      final w = goodWalkEntity();
      validateWalk(w, WalkEntry.fromJson(jsonRoundTrip(w.toJson())));
    });

    test('pocketbase', () {
      final w = goodWalkEntity();
      validateWalk(
        w,
        WalkEntry.codec.fromPocketBase(jsonRoundTrip(w.toPocketBase(''))),
      );
    });
  });

  group('MoodEntry round-trip', () {
    test('json', () {
      final m = goodMoodEntity();
      validateMood(m, MoodEntry.fromJson(jsonRoundTrip(m.toJson())));
    });

    test('pocketbase', () {
      final m = goodMoodEntity();
      validateMood(
        m,
        MoodEntry.codec.fromPocketBase(jsonRoundTrip(m.toPocketBase(''))),
      );
    });
  });

  group('NoteEntry round-trip', () {
    test('json', () {
      final n = goodNoteEntity();
      validateNote(n, NoteEntry.fromJson(jsonRoundTrip(n.toJson())));
    });

    test('pocketbase', () {
      final n = goodNoteEntity();
      validateNote(
        n,
        NoteEntry.codec.fromPocketBase(jsonRoundTrip(n.toPocketBase(''))),
      );
    });
  });

  group('WeightEntry round-trip', () {
    test('json', () {
      final w = goodWeightEntity();
      validateWeight(w, WeightEntry.fromJson(jsonRoundTrip(w.toJson())));
    });

    test('pocketbase', () {
      final w = goodWeightEntity();
      validateWeight(
        w,
        WeightEntry.codec.fromPocketBase(jsonRoundTrip(w.toPocketBase(''))),
      );
    });
  });

  group('SuggestedEvent round-trip', () {
    test('json', () {
      final s = goodSuggestedEvent();
      validateSuggested(s, SuggestedEvent.fromJson(jsonRoundTrip(s.toJson())));
    });
  });

  group('UserProfile round-trip', () {
    test('json', () {
      final u = goodUserProfile();
      validateUserProfile(u, UserProfile.fromJson(jsonRoundTrip(u.toJson())));
    });
  });
}
