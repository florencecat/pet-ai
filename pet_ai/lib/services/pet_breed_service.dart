import 'dart:convert';

import 'package:pet_satellite/models/species.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PetBreed {
  final String id;
  final String speciesId;
  final String name;

  const PetBreed({
    required this.id,
    required this.name,
    required this.speciesId,
  });
  const PetBreed.empty()
    : id = 'lrsfxdks8qr0scw',
      name = '',
      speciesId = '7usq9rejcoxq9mx';
  const PetBreed.dog({required this.id, required this.name})
    : speciesId = 'pqmhnzkblhx1xuw';
  const PetBreed.cat({required this.id, required this.name})
    : speciesId = 'au3t9kfooqc6zb5';
  const PetBreed.rabbit({required this.id, required this.name})
    : speciesId = 'nr4uj8azpruxo9y';
  const PetBreed.carrot({required this.id, required this.name})
    : speciesId = 'sikwqh7gdech5wy';
  const PetBreed.hamster({required this.id, required this.name})
    : speciesId = '0io86a4t8otidjj';
  const PetBreed.turtle({required this.id, required this.name})
    : speciesId = 'n8qq4i2okgq9lcc';
  const PetBreed.fish({required this.id, required this.name})
    : speciesId = '1bcqkmqyghrjigr';
  const PetBreed.snake({required this.id, required this.name})
    : speciesId = 'kudj3k1aaa1ucc0';
  const PetBreed.other({required this.id, required this.name})
    : speciesId = '7usq9rejcoxq9mx';

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'speciesId': speciesId,
  };

  bool get isEmpty => id == PetBreed.empty().id;

  factory PetBreed.fromJson(Map<String, dynamic> json) => PetBreed(
    id: json['id'],
    name: json['name'],
    speciesId: json['speciesId'],
  );
}

class PetBreedService {
  static PetBreed breedById(PetSpecies species, String id) {
    return breedsBySpecies(
      species,
    ).firstWhere((b) => b.id == id, orElse: () => PetBreed.empty());
  }

  /// Looks up a breed across both built-in and user-created lists.
  /// Returns [PetBreed.empty] when nothing matches.
  static Future<PetBreed> breedByIdIncludingCustom(
    PetSpecies species,
    String id,
  ) async {
    final builtIn = breedsBySpecies(species);
    for (final b in builtIn) {
      if (b.id == id) return b;
    }
    final custom = await loadCustomBreeds(species.id);
    for (final b in custom) {
      if (b.id == id) return b;
    }
    return const PetBreed.empty();
  }

  static List<PetBreed> breedsBySpecies(PetSpecies species) {
    switch (species.id) {
      case 'pqmhnzkblhx1xuw':
        return dogBreeds();
      case 'au3t9kfooqc6zb5':
        return catBreeds();
      case 'nr4uj8azpruxo9y':
        return rabbitBreeds();
      case 'sikwqh7gdech5wy':
        return carrotBreeds();
      case '0io86a4t8otidjj':
        return hamsterBreeds();
      case 'n8qq4i2okgq9lcc':
        return turtleBreeds();
      case '1bcqkmqyghrjigr':
        return fishBreeds();
      case 'kudj3k1aaa1ucc0':
        return snakeBreeds();
      case '7usq9rejcoxq9mx':
      default:
        return [];
    }
  }

  static const _customKey = 'custom_breeds_';

  static Future<List<PetBreed>> loadCustomBreeds(String speciesId) async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList('$_customKey$speciesId') ?? [];
    return list
        .map((s) => PetBreed.fromJson(jsonDecode(s) as Map<String, dynamic>))
        .toList();
  }

  static Future<PetBreed> saveCustomBreed(String speciesId, String name) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_customKey$speciesId';
    final list = prefs.getStringList(key) ?? [];
    final breed = PetBreed(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      speciesId: speciesId,
    );
    list.add(jsonEncode(breed.toJson()));
    await prefs.setStringList(key, list);
    return breed;
  }

  static List<PetBreed> popularBreedsBySpecies(PetSpecies species) {
    switch (species.id) {
      case 'pqmhnzkblhx1xuw':
        return popularDogBreeds();
      case 'au3t9kfooqc6zb5':
        return popularCatBreeds();
      case 'nr4uj8azpruxo9y':
        return popularRabbitBreeds();
      default:
        return [];
    }
  }

  static List<PetBreed> dogBreeds() => [
    PetBreed.dog(id: '7qx1sd25jnvcm5f', name: 'Абиссинская'),
    PetBreed.dog(id: 'eoj0rkrjhv9lqh8', name: 'Акита-ину'),
    PetBreed.dog(id: '3bgfc0cwibmx4i0', name: 'Алабай'),
    PetBreed.dog(id: 'pic1yn4cg98wo98', name: 'Английский бульдог'),
    PetBreed.dog(id: 'zxtc0wrvqoxl3dn', name: 'Бигль'),
    PetBreed.dog(id: 'wmpa4ht7gqhhpn3', name: 'Бишон фризе'),
    PetBreed.dog(id: 'r28btp5dv51xcln', name: 'Бордоский дог'),
    PetBreed.dog(id: 'rf3xu3mqc8rfzyb', name: 'Вельш-корги пемброк'),
    PetBreed.dog(id: 'vg5haqirn3qvj9r', name: 'Вельш-корги кардиган'),
    PetBreed.dog(id: '20tea1o6r87wbxc', name: 'Доберман'),
    PetBreed.dog(id: 'pjy8mwhitw12fee', name: 'Двортерьер'),
    PetBreed.dog(id: 'gwq17q3rhx9nrss', name: 'Йоркширский терьер'),
    PetBreed.dog(id: 's5km4ai65m87hem', name: 'Кане-корсо'),
    PetBreed.dog(id: 'xtnf1p5fiajay3w', name: 'Лабрадор ретривер'),
    PetBreed.dog(id: '3uz5khjr1yj5by1', name: 'Метис'),
    PetBreed.dog(id: 'uljv1uv7v53cai0', name: 'Мопс'),
    PetBreed.dog(id: 'wmo7k628mqv916d', name: 'Немецкая овчарка'),
    PetBreed.dog(id: '724d9ee9bigg7in', name: 'Першерон'),
    PetBreed.dog(id: 't0jg79ke8pd9401', name: 'Польская низинная овчарка'),
    PetBreed.dog(id: 'nucftegot2xhpyx', name: 'Померанский шпиц'),
    PetBreed.dog(id: '0rkpqfifhzmpej8', name: 'Ретривер (золотистый)'),
    PetBreed.dog(id: '7gj6nrer4z2wpvj', name: 'Русский той'),
    PetBreed.dog(id: 'm1nji62metnq5q4', name: 'Самоед'),
    PetBreed.dog(id: 'itduyzvd0bvkaaf', name: 'Такса'),
    PetBreed.dog(id: 'sp5iwfjvm8tu758', name: 'Французский бульдог'),
    PetBreed.dog(id: '9oh0qwq7ihg7a03', name: 'Хаски'),
    PetBreed.dog(id: '33d1f0aon8x4g9r', name: 'Чихуахуа'),
    PetBreed.dog(id: 'hzwh0ezz8ri9lbu', name: 'Шпиц'),
    PetBreed.dog(id: '39tf70tpixpeva0', name: 'Ши-тцу'),
    PetBreed.dog(id: '6c8d9852aj0ckrx', name: 'Шиба-ину'),
    PetBreed.dog(id: '6cbkuttbknuvq2u', name: 'Шнауцер'),
  ];

  static List<PetBreed> popularDogBreeds() => [
    PetBreed.dog(id: 'xtnf1p5fiajay3w', name: 'Лабрадор ретривер'),
    PetBreed.dog(id: '9oh0qwq7ihg7a03', name: 'Сибирский хаски'),
    PetBreed.dog(id: 'rf3xu3mqc8rfzyb', name: 'Вельш-корги пемброк'),
    PetBreed.dog(id: '6c8d9852aj0ckrx', name: 'Шиба-ину'),
    PetBreed.dog(id: '3uz5khjr1yj5by1', name: 'Метис'),
  ];

  static List<PetBreed> catBreeds() => [
    PetBreed.cat(id: 'dvfhhi1hocqi3f5', name: 'Абиссинская'),
    PetBreed.cat(id: 'gfkgcnrtgw8dali', name: 'Американская короткошерстная'),
    PetBreed.cat(id: 'yms3e0medxlf8av', name: 'Бенгальская'),
    PetBreed.cat(id: '818c3vw4brbrte7', name: 'Бирманская'),
    PetBreed.cat(id: 'aplzahgtevyoel9', name: 'Британская'),
    PetBreed.cat(id: 'a0g2dme6wpxohfg', name: 'Бурманская'),
    PetBreed.cat(id: 'cl3rkpzkzc2lx2x', name: 'Девон-рекс'),
    PetBreed.cat(id: 'oszzdteijxn97l8', name: 'Корниш-рекс'),
    PetBreed.cat(id: 'trarxajcfpe4842', name: 'Мейн-кун'),
    PetBreed.cat(id: 'rhzr9bz6ek9m2ta', name: 'Метис'),
    PetBreed.cat(id: 'jkm0xd1yx59hmqj', name: 'Невская маскарадная'),
    PetBreed.cat(id: 'l7j805m5qnpklyy', name: 'Норвежская лесная'),
    PetBreed.cat(id: '1zdb8tdhztkx16j', name: 'Ориентальная'),
    PetBreed.cat(id: 'it5kr9us91cxi26', name: 'Оцикет'),
    PetBreed.cat(id: 'nmk6g5fsqw68c8p', name: 'Персидская'),
    PetBreed.cat(id: 'dbl7pbr9xhvvf1u', name: 'Рэгдолл'),
    PetBreed.cat(id: 'njvbrpk74olyzi0', name: 'Русская голубая'),
    PetBreed.cat(id: 'p2dau6wirvej3kt', name: 'Сиамская'),
    PetBreed.cat(id: 'x8a8q414zkhnszu', name: 'Сибирская'),
    PetBreed.cat(id: 'd55fe8boj3p9mbp', name: 'Сомалийская'),
    PetBreed.cat(id: 'pnpu8kq9c0kqpo9', name: 'Сфинкс'),
    PetBreed.cat(id: 'romldibu8udq0lg', name: 'Турецкая ангора'),
    PetBreed.cat(id: 'mkqvgi71yrw43va', name: 'Турецкий ван'),
    PetBreed.cat(id: 'v7ami39ma078lad', name: 'Экзотическая короткошерстная'),
    PetBreed.cat(id: 'zpoy97a4jtxfbos', name: 'Шотландская вислоухая'),
    PetBreed.cat(id: 'vam8onm0pep2maa', name: 'Шотландская прямоухая'),
  ];

  static List<PetBreed> popularCatBreeds() => [
    PetBreed.cat(id: 'aplzahgtevyoel9', name: 'Британская'),
    PetBreed.cat(id: 'trarxajcfpe4842', name: 'Мейн-кун'),
    PetBreed.cat(id: 'pnpu8kq9c0kqpo9', name: 'Сфинкс'),
    PetBreed.cat(id: 'yms3e0medxlf8av', name: 'Бенгальская'),
    PetBreed.cat(id: 'rhzr9bz6ek9m2ta', name: 'Метис'),
  ];

  static List<PetBreed> rabbitBreeds() => [
    PetBreed.rabbit(id: 'urcvohxk7418z3m', name: 'Американский соболь'),
    PetBreed.rabbit(id: 'qu66yojiah3223m', name: 'Английский баран'),
    PetBreed.rabbit(id: 'saxh73763u2g61h', name: 'Ангорский'),
    PetBreed.rabbit(id: 'cdstx9zf5keijgl', name: 'Вислоухий'),
    PetBreed.rabbit(id: 'xw91bgo5wnk8x40', name: 'Гаванский'),
    PetBreed.rabbit(id: 'jbfqzwhsjyvqxlm', name: 'Гермелин'),
    PetBreed.rabbit(id: 'dvdgsd9dlraxfx4', name: 'Голландский'),
    PetBreed.rabbit(id: '5z8nnrhrqvq7ene', name: 'Калифорнийский'),
    PetBreed.rabbit(id: '62g408tmiwjyhq8', name: 'Карликовый'),
    PetBreed.rabbit(id: '2cqwbj5p2p2ymy9', name: 'Кашемировый лоп'),
    PetBreed.rabbit(id: 'k0ctoq6cyaezfhc', name: 'Львиноголовый'),
    PetBreed.rabbit(id: 'o0hxu8fjdtgovoq', name: 'Минилоп'),
    PetBreed.rabbit(id: 'gl4ii74o8p47hwz', name: 'Мини-рекс'),
    PetBreed.rabbit(id: 'ybc2csteil5r2vb', name: 'Нидерландский карлик'),
    PetBreed.rabbit(id: 'gdo1lz1xzixma49', name: 'Новозеландский'),
    PetBreed.rabbit(id: 'vz2387wtvfrs4u6', name: 'Рекс'),
    PetBreed.rabbit(id: 'sgmmcoek06609fo', name: 'Сатиновый'),
    PetBreed.rabbit(id: 'b5aluxd3o8cd7vj', name: 'Серебристый'),
    PetBreed.rabbit(id: 'llplbai9gsol816', name: 'Фландр'),
    PetBreed.rabbit(id: 'cnha69kc9jg4rc6', name: 'Французский баран'),
    PetBreed.rabbit(id: 'etpnqqdv29opb6u', name: 'Хотот'),
  ];

  static List<PetBreed> popularRabbitBreeds() => [
    PetBreed.rabbit(id: 'cdstx9zf5keijgl', name: 'Вислоухий'),
    PetBreed.rabbit(id: '62g408tmiwjyhq8', name: 'Карликовый'),
    PetBreed.rabbit(id: 'saxh73763u2g61h', name: 'Ангорский'),
  ];

  static List<PetBreed> carrotBreeds() => [
    PetBreed.carrot(id: 'ks89pfdb55mqeez', name: 'Александрийский'),
    PetBreed.carrot(id: 'pcrho24fhl68mqi', name: 'Амазон'),
    PetBreed.carrot(id: 'oesrqepkc371cs9', name: 'Ара'),
    PetBreed.carrot(id: 'jesv9y690zef166', name: 'Белобрюхий'),
    PetBreed.carrot(id: 'ctch7g7yfmhf8wx', name: 'Благородный'),
    PetBreed.carrot(id: 'fqybzxf0vat6hj5', name: 'Бурохвостый'),
    PetBreed.carrot(id: '7m3iga6onbl5cnc', name: 'Волнистый'),
    PetBreed.carrot(id: 'jhk1wfzrk3903tc', name: 'Жако'),
    PetBreed.carrot(id: 'kruud0z7xvfebmy', name: 'Зелёнощёкий аратинга'),
    PetBreed.carrot(id: 'hil4khs3tyqnvjs', name: 'Какарик'),
    PetBreed.carrot(id: '93uyzbnxqm3v224', name: 'Какаду'),
    PetBreed.carrot(id: 'of093okpr4tzw42', name: 'Корелла'),
    PetBreed.carrot(id: 'rmu5wndlnhrnq8a', name: 'Квакер'),
    PetBreed.carrot(id: 'qcfp2u1u01arxs7', name: 'Лори'),
    PetBreed.carrot(id: 'y8duiquwyl31kxn', name: 'Неразлучник'),
    PetBreed.carrot(id: 'eae2yz21f20xl5p', name: 'Ожереловый'),
    PetBreed.carrot(id: 'sooho0e41hn008y', name: 'Пионус'),
    PetBreed.carrot(id: 'n7idwwcrz0ssi02', name: 'Розелла'),
    PetBreed.carrot(id: 'z0xacz86bogam49', name: 'Сенегальский'),
    PetBreed.carrot(id: 'pzedht271cvngk8', name: 'Солнечная аратинга'),
    PetBreed.carrot(id: 'cfcx6djd4xno6wy', name: 'Эклектус'),
  ];

  static List<PetBreed> hamsterBreeds() => [
    PetBreed.hamster(id: 't125sky7bgzffjn', name: 'Ангорский сирийский'),
    PetBreed.hamster(id: 'g4z6lytg5h07ng2', name: 'Джунгарский'),
    PetBreed.hamster(id: 'mrpkqy09dre3yp6', name: 'Китайский'),
    PetBreed.hamster(id: '3rgkvtbw86p2p98', name: 'Кэмпбелла'),
    PetBreed.hamster(id: 'w6b37lcz8q8ag90', name: 'Роборовского'),
    PetBreed.hamster(id: 'klomoyjpm12t9dc', name: 'Сирийский'),
    PetBreed.hamster(id: 'p0xydzytnohbsjn', name: 'Хомяк альбинос'),
    PetBreed.hamster(id: '9gmtd0628wn1x79', name: 'Хомяк из телеграма'),
    PetBreed.hamster(id: 'aalgf4kpcxw4xfg', name: 'Чёрный медведь'),
  ];

  static List<PetBreed> turtleBreeds() => [
    PetBreed.turtle(id: 'ohgdxwpfen8b3a9', name: 'Балканская'),
    PetBreed.turtle(id: 'p995rodf2cmkurx', name: 'Болотная'),
    PetBreed.turtle(id: 'v7ttv0sw2033xk6', name: 'Дальневосточная'),
    PetBreed.turtle(id: '19ovnf3iuk6yp3n', name: 'Звёздчатая'),
    PetBreed.turtle(id: 'iwf8gc8t16n2vwc', name: 'Каймановая'),
    PetBreed.turtle(id: 'fdmbwg1hlep1dfh', name: 'Красноногая'),
    PetBreed.turtle(id: 'z1t4o28n2xjl6ic', name: 'Красноухая'),
    PetBreed.turtle(id: 'y4ujfk0p9h5jkkh', name: 'Леопардовая'),
    PetBreed.turtle(id: 'wep9k9i5koiycr4', name: 'Мускусная'),
    PetBreed.turtle(id: 'zjtw8ejsjxbdpx9', name: 'Расписная'),
    PetBreed.turtle(id: 'ztnivc634ow0m9j', name: 'Среднеазиатская'),
    PetBreed.turtle(id: '6q9mc0nfeuprxx1', name: 'Супер-ниндзя черепашка'),
    PetBreed.turtle(id: 'nbebg1arpn1aiu3', name: 'Трионикс'),
  ];

  static List<PetBreed> fishBreeds() => [
    PetBreed.fish(id: 'cdmsnaxnbgiy3oe', name: 'Анциструс'),
    PetBreed.fish(id: '8qa0htw1i88upwt', name: 'Апистограмма'),
    PetBreed.fish(id: 'xage8uqcmf8u8sf', name: 'Барбус'),
    PetBreed.fish(id: 'sh3lbjw8nze5ca9', name: 'Боция'),
    PetBreed.fish(id: '25p87fguxa2b0p8', name: 'Гуппи'),
    PetBreed.fish(id: '1vhzvispr16fzve', name: 'Данио-рерио'),
    PetBreed.fish(id: 'euivits7ti1r8t5', name: 'Дискус'),
    PetBreed.fish(id: 'd4qzlzx5gg6wvho', name: 'Золотая рыбка'),
    PetBreed.fish(id: '9lznne1hhvevg62', name: 'Кардинал'),
    PetBreed.fish(id: 'ga8mkjeauce30mh', name: 'Коридорас'),
    PetBreed.fish(id: 'w22ag7ptz2zbdot', name: 'Лялиус'),
    PetBreed.fish(id: 'rjikwqxcy3eejpx', name: 'Меченосец'),
    PetBreed.fish(id: 'nm903eucbk7642y', name: 'Моллинезия'),
    PetBreed.fish(id: 'x4hscigkokhi8e8', name: 'Неон'),
    PetBreed.fish(id: '9b8ygrqfjjxkqll', name: 'Петушок'),
    PetBreed.fish(id: '9z6ko5z8pkfg70i', name: 'Пецилия'),
    PetBreed.fish(id: '2uol5amo4difv4p', name: 'Скалярия'),
    PetBreed.fish(id: 'qny6m8bp9wih24m', name: 'Тернеция'),
    PetBreed.fish(id: '2om6zdvai5ln1gf', name: 'Тетра'),
    PetBreed.fish(id: 'ip6z244swldcsyi', name: 'Фильтратор Амано'),
    PetBreed.fish(id: 'tpvanur9faz231s', name: 'Цихлазома'),
    PetBreed.fish(id: 'd6bpgp9lvhwo2pe', name: 'Язь'),
  ];

  static List<PetBreed> snakeBreeds() => [
    PetBreed.snake(id: 'otq9cviejfb0hl1', name: 'Альбиносный маисовый полоз'),
    PetBreed.snake(id: 'wc6ayn1t7grogdv', name: 'Зелёный древесный питон'),
    PetBreed.snake(id: '72o9o5f9n4zkcyn', name: 'Императорский удав'),
    PetBreed.snake(
      id: 'ix9ye1n6rt4ogl0',
      name: 'Калифорнийская королевская змея',
    ),
    PetBreed.snake(id: 'wfhs6k84ympz389', name: 'Ковровый питон'),
    PetBreed.snake(id: 'dyr0oul1k9bc961', name: 'Маисовый полоз'),
    PetBreed.snake(
      id: 'r0cphh6pvmspap8',
      name: 'Мексиканская чёрная королевская змея',
    ),
    PetBreed.snake(id: 'z1nftr1prgy77pf', name: 'Молочная змея'),
    PetBreed.snake(id: 'dipc4opwwewu2mn', name: 'Обыкновенный удав'),
    PetBreed.snake(id: '8v4uxp3flew2a2z', name: 'Песчаный удав'),
    PetBreed.snake(id: '7fj3x09mmtotozy', name: 'Радужный удав'),
    PetBreed.snake(id: 'ehsfx8vbddeaujd', name: 'Сетчатый питон'),
    PetBreed.snake(id: '8vdgg1pufiexo8c', name: 'Тигровый питон'),
    PetBreed.snake(id: 'mpetf92kprggv6b', name: 'Узорчатый полоз'),
    PetBreed.snake(id: 'ieecpdgokmsjcrl', name: 'Уроборос'),
    PetBreed.snake(id: 'cxlksokkxp6h1h3', name: 'Центральноамериканский удав'),
    PetBreed.snake(id: 'f1gg91altgbxxwr', name: 'Шаровидный питон'),
    PetBreed.snake(id: '851lbj25mmdlxzg', name: 'Эмори-полоз'),
    PetBreed.snake(id: '1zy7c5hmxlptb21', name: 'Японский полоз'),
  ];
}
