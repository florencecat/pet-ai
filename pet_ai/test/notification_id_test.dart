import 'package:flutter_test/flutter_test.dart';
import 'package:pet_satellite/services/notification_service.dart';

/// Регрессия B6: id локальных уведомлений должны быть детерминированы (иначе
/// уведомление, запланированное в одном запуске, нельзя отменить в другом),
/// помещаться в положительный Java int и не пересекаться блоками между разными
/// событиями (слоты custom-дней id..id+7 одного события — приватны для него).
void main() {
  int idFor(String e, [int slot = 0]) =>
      NotificationService.notificationIdFor(e, slot);

  group('notification id', () {
    test('детерминирован для одного eventId', () {
      expect(idFor('event-abc'), idFor('event-abc'));
    });

    test('в пределах положительного 32-битного int', () {
      for (final e in ['a', 'event-abc', 'x' * 40, 'события-кириллица']) {
        final id = idFor(e);
        expect(id, greaterThanOrEqualTo(0));
        expect(id, lessThanOrEqualTo(0x7fffffff));
      }
    });

    test('базовый id выровнен по 8 (младшие 3 бита свободны под слоты)', () {
      expect(idFor('event-abc') % 8, 0);
    });

    test('слоты 0..7 лежат внутри блока события', () {
      final base = idFor('event-abc');
      for (var slot = 0; slot < 8; slot++) {
        expect(idFor('event-abc', slot), base + slot);
      }
    });

    test('блоки разных событий не пересекаются', () {
      final ids = <String>[
        for (var i = 0; i < 2000; i++) 'evt_${i}_${i * 7 + 3}',
      ];
      final usedSlots = <int>{};
      for (final e in ids) {
        final base = idFor(e);
        // Резервируем все 8 id блока; пересечение = коллизия между событиями.
        for (var slot = 0; slot < 8; slot++) {
          expect(
            usedSlots.add(base + slot),
            isTrue,
            reason: 'коллизия id между событиями на "$e"',
          );
        }
      }
    });
  });
}
