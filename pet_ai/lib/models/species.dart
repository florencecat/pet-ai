class PetSpecies {
  final String id;
  final String name;
  final String emoji;

  const PetSpecies({
    required this.id,
    required this.name,
    required this.emoji,
  });

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'emoji': emoji};

  factory PetSpecies.fromJson(Map<String, dynamic> json) => PetSpecies(
    id: json['id'],
    name: json['name'],
    emoji: json['emoji'],
  );
}

/// Встроенный список — показывается когда нет интернета
class BuiltInSpecies {
  static const dog    = PetSpecies(id: 'dog',    name: 'Собака',   emoji: '🐶');
  static const cat    = PetSpecies(id: 'cat',    name: 'Кошка',    emoji: '🐱');
  static const rabbit = PetSpecies(id: 'rabbit', name: 'Кролик',   emoji: '🐰');
  static const parrot = PetSpecies(id: 'parrot', name: 'Попугай',  emoji: '🦜');
  static const hamster= PetSpecies(id: 'hamster',name: 'Хомяк',    emoji: '🐹');
  static const turtle = PetSpecies(id: 'turtle', name: 'Черепаха', emoji: '🐢');
  static const fish   = PetSpecies(id: 'fish',   name: 'Рыбка',    emoji: '🐟');
  static const snake  = PetSpecies(id: 'snake',  name: 'Змея',     emoji: '🐍');
  static const other  = PetSpecies(id: 'other',  name: 'Другое',   emoji: '🐾');

  static const all = [dog, cat, rabbit, parrot, hamster, turtle, fish, snake, other];

  static PetSpecies? byId(String id) {
    try {
      return all.firstWhere((s) => s.id == id);
    } catch (_) {
      return null;
    }
  }
}