import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/models/pet_profile.dart';
import 'package:pet_satellite/models/species.dart';
import 'package:pet_satellite/services/pet_breed_service.dart';

/// Регрессия B3: питомец с кастомной породой должен переживать синхронизацию
/// через облако (toPocketBase → fromPocketBase) без потери породы и без краха.
void main() {
  group('Pet PocketBase round-trip', () {
    test('кастомная порода сохраняет имя через breed_name', () {
      final pet = Pet(
        name: 'Барсик',
        species: BuiltInSpecies.cat,
        breed: const PetBreed(
          id: 'custom_1700000000000',
          name: 'Мейн-кун микс',
          speciesId: 'au3t9kfooqc6zb5',
        ),
      );

      final data = pet.toPocketBase('user1');
      expect(data['breed'], 'custom_1700000000000');
      expect(data['breed_custom_name'], 'Мейн-кун микс');

      final restored = Pet.codec.fromPocketBase(data);
      expect(restored.breed.id, 'custom_1700000000000');
      expect(restored.breed.name, 'Мейн-кун микс');
      expect(restored.species.id, BuiltInSpecies.cat.id);
    });

    test('встроенная порода восстанавливается по id (без breed_name)', () {
      final builtin = PetBreedService.breedsBySpecies(BuiltInSpecies.dog).first;
      final pet = Pet(
        name: 'Рекс',
        species: BuiltInSpecies.dog,
        breed: builtin,
      );

      final data = pet.toPocketBase('user1');
      expect(data.containsKey('breed_custom_name'), isFalse,
          reason: 'для встроенных пород имя не дублируется в облако');

      final restored = Pet.codec.fromPocketBase(data);
      expect(restored.breed.id, builtin.id);
      expect(restored.breed.name, builtin.name);
    });

    test('кастомная порода без breed_name (старые данные) не роняет питомца', () {
      // Имитируем запись, выгруженную старым клиентом: breed = custom-id, но
      // поля breed_name нет.
      final data = <String, dynamic>{
        'id': 'petrecord0001',
        'name': 'Мурзик',
        'species': BuiltInSpecies.cat.id,
        'breed': 'custom_1699999999999',
        'gender': 'none',
        'palette': <String, dynamic>{},
      };

      final restored = Pet.codec.fromPocketBase(data);
      expect(restored.breed.isEmpty, isTrue,
          reason: 'имя восстановить неоткуда — деградируем в пустую породу');
      expect(restored.name, 'Мурзик');
    });
  });
}
