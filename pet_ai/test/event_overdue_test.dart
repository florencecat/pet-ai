import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/models/event.dart';

/// Просрочка считается по конкретному вхождению, а не по событию целиком:
/// события курсов препаратов всегда повторяющиеся, и пропущен у них отдельный
/// приём. Проверка «событие просрочено» их не ловила — в календаре они не
/// помечались пропущенными никогда.
void main() {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final yesterday = today.subtract(const Duration(days: 1));
  final tomorrow = today.add(const Duration(days: 1));

  Event dailyPillEvent() => Event(
    name: 'Габапентин',
    category: EventCategories.health,
    dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 9),
    repeat: RepeatInterval.daily,
    origin: const PillOrigin('pill_1'),
  );

  group('Event.isOverdueOn', () {
    test('вчерашний приём повторяющегося курса просрочен', () {
      expect(dailyPillEvent().isOverdueOn(yesterday), isTrue);
    });

    test('отмеченный вчерашний приём не просрочен', () {
      final event = dailyPillEvent()..toggleCompletedOn(yesterday);
      expect(event.isOverdueOn(yesterday), isFalse);
    });

    test('сегодняшний и будущий приёмы не просрочены', () {
      final event = dailyPillEvent();
      expect(event.isOverdueOn(today), isFalse);
      expect(event.isOverdueOn(tomorrow), isFalse);
    });

    test('заметка не просрочивается — её нельзя отметить выполненной', () {
      final note = Event.fromNote(
        noteId: 'note_1',
        name: 'Отказ от еды',
        dateTime: yesterday,
      );
      expect(note.isOverdueOn(yesterday), isFalse);
    });
  });

  group('Event.isOverdue', () {
    test('повторяющееся событие целиком не просрочено', () {
      expect(dailyPillEvent().isOverdue, isFalse);
    });

    test('разовое прошедшее событие просрочено', () {
      final treatment = Event(
        name: 'Прививка',
        category: EventCategories.vaccination,
        dateTime: DateTime(yesterday.year, yesterday.month, yesterday.day, 10),
        origin: const TreatmentOrigin('tr_1'),
      );
      expect(treatment.isOverdue, isTrue);
    });
  });
}
