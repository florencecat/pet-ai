class PetSpecies {
  final String id;
  final String name;
  final String emoji;

  const PetSpecies({required this.id, required this.name, required this.emoji});

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji};

  factory PetSpecies.fromJson(Map<String, dynamic> json) =>
      PetSpecies(id: json['id'], name: json['name'], emoji: json['emoji']);
}

/// Встроенный список — показывается когда нет интернета
class BuiltInSpecies {
  static const dog = PetSpecies(
    id: 'pqmhnzkblhx1xuw',
    name: 'Собака',
    emoji: '🐶',
  );
  static const cat = PetSpecies(
    id: 'au3t9kfooqc6zb5',
    name: 'Кошка',
    emoji: '🐱',
  );
  static const rabbit = PetSpecies(
    id: 'nr4uj8azpruxo9y',
    name: 'Кролик',
    emoji: '🐰',
  );
  static const parrot = PetSpecies(
    id: 'sikwqh7gdech5wy',
    name: 'Попугай',
    emoji: '🦜',
  );
  static const hamster = PetSpecies(
    id: '0io86a4t8otidjj',
    name: 'Хомяк',
    emoji: '🐹',
  );
  static const turtle = PetSpecies(
    id: 'n8qq4i2okgq9lcc',
    name: 'Черепаха',
    emoji: '🐢',
  );
  static const fish = PetSpecies(
    id: '1bcqkmqyghrjigr',
    name: 'Рыбка',
    emoji: '🐟',
  );
  static const snake = PetSpecies(
    id: 'kudj3k1aaa1ucc0',
    name: 'Змея',
    emoji: '🐍',
  );
  static const other = PetSpecies(
    id: '7usq9rejcoxq9mx',
    name: 'Другое',
    emoji: '🐾',
  );

  static const all = [
    dog,
    cat,
    rabbit,
    parrot,
    hamster,
    turtle,
    fish,
    snake,
    other,
  ];

  static PetSpecies? byId(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}
