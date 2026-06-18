import 'dart:convert';

import 'package:pet_satellite/models/event.dart';

/// Статус предложенного ИИ события.
/// [pending] — ждёт решения пользователя (показываем «Создать / Отмена»),
/// [created] — событие добавлено (показываем «Создано» + просмотр),
/// [cancelled] — пользователь отказался от создания.
enum SuggestedEventStatus { pending, created, cancelled }

/// Событие, предложенное ИИ-ассистентом в ответе. Хранится вместе с сообщением
/// (сериализуется в JSON в `ChatMessage.eventsJson`) и отображается карточкой
/// под сообщением. В зависимости от настройки автосоздания карточка либо сразу
/// в статусе [SuggestedEventStatus.created], либо предлагает «Создать / Отмена».
class SuggestedEvent {
  final String name;
  final String categoryId;
  final DateTime dateTime;
  final RepeatInterval repeat;

  /// Исходные данные из ответа ИИ — используются для фактического создания
  /// события через [Event.codec.fromAIResponse].
  final Map<String, dynamic> raw;

  SuggestedEventStatus status;

  /// id созданного [Event] — для перехода к нему по нажатии «Просмотр».
  String? createdEventId;

  SuggestedEvent({
    required this.name,
    required this.categoryId,
    required this.dateTime,
    required this.repeat,
    required this.raw,
    this.status = SuggestedEventStatus.pending,
    this.createdEventId,
  });

  EventCategory get category => EventCategories.byId(categoryId);

  /// Разбирает один элемент массива `events` из ответа ИИ.
  factory SuggestedEvent.fromAi(Map<String, dynamic> m) {
    final name = (m['name'] as String?)?.trim();
    return SuggestedEvent(
      name: (name == null || name.isEmpty) ? 'Напоминание' : name,
      categoryId: EventCategories.fromAiId(m['category'] as String?).id,
      dateTime:
          DateTime.tryParse(m['datetime'] as String? ?? '') ?? DateTime.now(),
      repeat: RepeatIntervalX.fromAi(m['repeat'] as String?),
      raw: m,
    );
  }

  SuggestedEvent copyWith({
    SuggestedEventStatus? status,
    String? createdEventId,
  }) => SuggestedEvent(
    name: name,
    categoryId: categoryId,
    dateTime: dateTime,
    repeat: repeat,
    raw: raw,
    status: status ?? this.status,
    createdEventId: createdEventId ?? this.createdEventId,
  );

  Map<String, dynamic> toJson() => {
    'name': name,
    'categoryId': categoryId,
    'datetime': dateTime.toIso8601String(),
    'repeat': repeat.name,
    'raw': raw,
    'status': status.name,
    'createdEventId': createdEventId,
  };

  factory SuggestedEvent.fromJson(Map<String, dynamic> j) => SuggestedEvent(
    name: j['name'] as String? ?? 'Напоминание',
    categoryId: j['categoryId'] as String? ?? EventCategories.other.id,
    dateTime:
        DateTime.tryParse(j['datetime'] as String? ?? '') ?? DateTime.now(),
    repeat: RepeatInterval.values.firstWhere(
      (r) => r.name == j['repeat'],
      orElse: () => RepeatInterval.none,
    ),
    raw: (j['raw'] as Map?)?.cast<String, dynamic>() ?? const {},
    status: SuggestedEventStatus.values.firstWhere(
      (s) => s.name == j['status'],
      orElse: () => SuggestedEventStatus.pending,
    ),
    createdEventId: j['createdEventId'] as String?,
  );

  static String encodeList(List<SuggestedEvent> list) =>
      jsonEncode(list.map((e) => e.toJson()).toList());

  static List<SuggestedEvent> decodeList(String source) {
    final decoded = jsonDecode(source);
    if (decoded is! List) return const [];
    return decoded
        .whereType<Map>()
        .map((m) => SuggestedEvent.fromJson(m.cast<String, dynamic>()))
        .toList();
  }
}
