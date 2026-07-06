import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'cloud_sync_service.dart';
import 'notification_service.dart';
import 'pet_profile_service.dart';
import 'pill_reminder_service.dart';
import 'package:pet_satellite/models/event.dart';

class EventService {
  // Глобальное хранилище всех событий (v2)
  static const _globalKey = 'pet_events_v2';

  // ─── Внутренние ───────────────────────────────────────────────────────────

  Future<List<Event>> _loadAll() async {
    final data = await SharedPreferencesAsync().getStringList(_globalKey) ?? [];
    return data.map((e) => Event.fromJson(jsonDecode(e))).toList();
  }

  Future<void> _persistAll(List<Event> events) async {
    final encoded = events.map((e) => jsonEncode(e.toJson())).toList();
    await SharedPreferencesAsync().setStringList(_globalKey, encoded);
  }

  // ─── Чтение ──────────────────────────────────────────────────────────────

  /// Все события конкретного питомца
  Future<List<Event>> loadEvents(String petId) async {
    final all = await _loadAll();
    return all.where((e) => e.petIds.contains(petId)).toList();
  }

  /// Все события всех питомцев плоским списком (для полной выгрузки в облако).
  Future<List<Event>> loadAllEventsFlat() => _loadAll();

  /// Импортирует события [events] для [petId] из облака **без** обратного пуша.
  /// Существующие события этого питомца замещаются; дедупликация по id события
  /// (одно событие может относиться к нескольким питомцам).
  Future<void> importEvents(String petId, List<Event> events) async {
    final all = await _loadAll();
    final byId = <String, Event>{
      for (final e in all)
        if (!e.petIds.contains(petId)) e.id: e,
    };
    for (final e in events) {
      if (!e.petIds.contains(petId)) e.petIds.add(petId);
      byId[e.id] = e;
    }
    final merged = byId.values.toList();
    await _persistAll(merged);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      for (final e in events) {
        if (!e.remind) continue;
        try {
          await NotificationService().scheduleEventNotification(
            e,
            petLabel: await _resolveLabel(e),
          );
        } catch (_) {}
      }
    }
  }

  /// Все события нескольких питомцев, дедуплицированные по ID события
  Future<List<Event>> loadEventsForPets(List<String> petIds) async {
    final all = await _loadAll();
    final seen = <String>{};
    return all.where((e) {
      if (e.petIds.any((id) => petIds.contains(id))) {
        return seen.add(e.id);
      }
      return false;
    }).toList();
  }

  /// Событие по его ID (среди всех питомцев). null — не найдено.
  Future<Event?> findById(String id) async {
    final all = await _loadAll();
    for (final e in all) {
      if (e.id == id) return e;
    }
    return null;
  }

  /// Возвращает события всех питомцев, сгруппированные по petId
  Future<Map<String, List<Event>>> loadAllEvents(List<String> petIds) async {
    final all = await _loadAll();
    final result = <String, List<Event>>{};
    for (final id in petIds) {
      result[id] = all.where((e) => e.petIds.contains(id)).toList();
    }
    return result;
  }

  // ─── Запись ───────────────────────────────────────────────────────────────

  Future<void> createEvent(Event event) async {
    final all = await _loadAll();
    all.add(event);
    await _persistAll(all);

    if (event.remind && !kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await NotificationService().ensurePermission();
        await NotificationService().scheduleEventNotification(
          event,
          petLabel: await _resolveLabel(event),
        );
      } catch (_) {
        // Silently ignore notification failures (e.g. permission denied).
      }
    }

    // Fire-and-forget cloud push.
    if (event.petIds.isNotEmpty) {
      CloudSyncService.instance.pushAsync('events', event, event.petIds.first);
    }
  }

  Future<void> saveEvent(Event event) async {
    final all = await _loadAll();
    final index = all.indexWhere((e) => e.id == event.id);
    if (index < 0) return;

    all[index] = event;
    await _persistAll(all);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      try {
        await NotificationService().cancelNotification(event.id);
        await NotificationService().scheduleEventNotification(
          event,
          petLabel: await _resolveLabel(event),
        );
      } catch (_) {
        // Сбой планирования уведомления не должен ломать сохранение события.
      }
    }

    // Fire-and-forget cloud upsert (правки/отметки выполнения уезжают в облако).
    if (event.petIds.isNotEmpty) {
      CloudSyncService.instance.pushAsync('events', event, event.petIds.first);
    }
  }

  /// Переключает выполнение события для конкретного дня.
  /// Если событие связано с препаратом ([EventSource.pill]), синхронизирует
  /// статус с [Pill.takenDates] — чтобы отметка в календаре
  /// отражалась и на странице Здоровья, и наоборот.
  Future<void> toggleCompleted(String petId, Event event, DateTime day) async {
    event.toggleCompletedOn(day);
    await saveEvent(event);

    // Направление событие → препарат. Единственная (awaited) точка синхронизации:
    // событие уже сохранено выше, поэтому обратный вызов на событие не нужен.
    if (event.source == EventSource.pill) {
      await PillReminderService().applyEventCompletion(
        event,
        day,
        event.isCompletedOn(day),
      );
    }
  }

  /// Устанавливает статус выполнения события напрямую по ID (без переключения).
  /// Вызывается из [PillReminderService] при отметке препарата принятым,
  /// чтобы синхронизировать событие в календаре.
  Future<void> setCompletedOn(
    String eventId,
    DateTime day,
    bool completed,
  ) async {
    final all = await _loadAll();
    final idx = all.indexWhere((e) => e.id == eventId);
    if (idx < 0) return;
    final key = Event.dateKey(day);
    if (completed) {
      all[idx].completedDates.add(key);
    } else {
      all[idx].completedDates.remove(key);
    }
    await _persistAll(all);
  }

  /// Все события, которые приходятся на конкретный день (включая повторяющиеся)
  Future<List<Event>> eventsForDay(String petId, DateTime day) async {
    final events = await loadEvents(petId);
    return events.where((e) => e.occursOn(day)).toList();
  }

  Future<void> deleteEvent(Event event) async {
    final all = await _loadAll();
    all.removeWhere((e) => e.id == event.id);
    await _persistAll(all);

    if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
      await NotificationService().cancelNotification(event.id);
    }

    // Fire-and-forget remote delete.
    CloudSyncService.instance.deleteAsync('events', event.id);
  }

  // ─── Очистка ──────────────────────────────────────────────────────────────

  /// Удаляет связь питомца со всеми событиями; события без питомцев удаляются
  Future<void> clearEvents(String petId) async {
    final all = await _loadAll();
    final updated = <Event>[];
    for (final e in all) {
      if (e.petIds.contains(petId)) {
        e.petIds.remove(petId);
        if (e.petIds.isEmpty) {
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
            await NotificationService().cancelNotification(e.id);
          }
          // Осиротевшее событие удаляем и из облака.
          CloudSyncService.instance.deleteAsync('events', e.id);
          continue;
        }
      }
      updated.add(e);
    }
    await _persistAll(updated);
  }

  Future<void> clearEventsForAll(List<String> petIds) async {
    for (final id in petIds) {
      await clearEvents(id);
    }
  }

  // ─── Фильтрация ───────────────────────────────────────────────────────────

  /// Ближайшие события питомца, начиная с [from] (по умолчанию — сейчас).
  Future<List<Event>> upcomingEvents(
    String petId, {
    DateTime? from,
    int limit = 10,
  }) async {
    final now = from ?? DateTime.now();
    final events = await loadEvents(petId);
    final sorted = events.where((e) => e.dateTime.isAfter(now)).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
    return sorted.take(limit).toList();
  }

  /// События питомца по категории.
  Future<List<Event>> eventsByCategory(
    String petId,
    EventCategory category,
  ) async {
    final events = await loadEvents(petId);
    return events.where((e) => e.category.id == category.id).toList()
      ..sort((a, b) => a.dateTime.compareTo(b.dateTime));
  }

  // ─── Уведомления ──────────────────────────────────────────────────────────

  /// Полная пересборка расписания локальных уведомлений.
  ///
  /// Снимает все ранее запланированные напоминания (в т.ч. «осиротевшие» от
  /// удалённых событий и устаревшие дубли) и заново планирует актуальные.
  /// Вызывается при запуске/возврате приложения и при изменении настроек —
  /// чтобы пережить перезагрузку телефона и агрессивные оптимизации питания,
  /// обнуляющие системные будильники. Если уведомления выключены в настройках —
  /// расписание просто стирается.
  Future<void> rescheduleAllNotifications() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;

    await NotificationService().cancelAll();

    final settings = await NotificationSettings.load();
    if (!settings.enabled) return; // выключено → всё стёрто

    final all = await _loadAll();
    final profiles = await PetProfileService().loadAllProfiles();
    final names = {for (final p in profiles) p.id: p.name};

    try {
      await NotificationService().ensurePermission();
    } catch (_) {}

    for (final e in all) {
      if (!e.remind) continue;
      try {
        await NotificationService().scheduleEventNotification(
          e,
          petLabel: _petLabel(e.petIds, names),
          settings: settings,
        );
      } catch (_) {
        // Пропускаем сбойное событие, остальные планируем.
      }
    }
  }

  /// Человекочитаемая подпись питомца(ев) события для заголовка уведомления.
  String? _petLabel(List<String> petIds, Map<String, String> names) {
    final resolved = petIds.map((id) => names[id]).whereType<String>().toList();
    if (resolved.isEmpty) return null;
    return resolved.join(', ');
  }

  /// Разрешает подпись питомца для одиночного планирования (create/save).
  Future<String?> _resolveLabel(Event e) async {
    if (e.petIds.isEmpty) return null;
    final profiles = await PetProfileService().loadAllProfiles();
    final names = {for (final p in profiles) p.id: p.name};
    return _petLabel(e.petIds, names);
  }
}
