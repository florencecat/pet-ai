import 'package:pet_satellite/models/treatment.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/models/event.dart';

/// Сервис мед. мероприятий: ведёт историю в [Pet.treatmentHistory]
/// и автоматически создаёт связанное событие в календаре с напоминанием.
class TreatmentService {
  /// Добавить запись о мероприятии и создать событие-напоминание.
  ///
  /// [date] — дата выполненного мероприятия.
  /// [nextDate] — дата следующего такого мероприятия.
  /// [remindBeforeDays] — за сколько дней напомнить.
  Future<TreatmentEntry?> addTreatment({
    required String petId,
    required TreatmentKind kind,
    required DateTime date,
    required DateTime nextDate,
    String name = '',
    int remindBeforeDays = 7,
  }) async {
    final profile = await PetService().loadProfile(petId);
    if (profile == null) return null;

    // Создаём связанное событие на nextDate
    final eventName = (kind == TreatmentKind.vaccine && name.isNotEmpty)
        ? 'Прививка: $name'
        : kind.label;

    // Время по умолчанию — 10:00 в день мероприятия
    final eventDateTime = DateTime(
      nextDate.year, nextDate.month, nextDate.day, 10, 0,
    );

    final event = Event(
      name: eventName,
      category: EventCategories.vaccination,
      dateTime: eventDateTime,
      remindBeforeMinutes: remindBeforeDays * 24 * 60,
      petIds: [petId],
      source: EventSource.treatment,
    );

    await EventService().createEvent(event);

    final entry = TreatmentEntry(
      date: date,
      kind: kind,
      name: name,
      nextDate: nextDate,
      remindBeforeDays: remindBeforeDays,
      eventId: event.id,
    );

    profile.treatmentHistory.add(entry);
    await PetService().saveProfile(profile);

    // Fire-and-forget cloud push.
    CloudSyncService.instance.pushAsync(
      'treatments',
      entry.toJson(),
      petId: petId,
    );

    return entry;
  }

  /// Удалить запись о мероприятии (и связанное событие, если ещё актуально).
  Future<void> deleteTreatment(String petId, TreatmentEntry entry) async {
    final profile = await PetService().loadProfile(petId);
    if (profile == null) return;

    profile.treatmentHistory.entries.removeWhere(
      (e) => e.date == entry.date && e.kind == entry.kind && e.name == entry.name,
    );
    await PetService().saveProfile(profile);

    if (entry.eventId != null) {
      // Найдём и удалим связанное событие
      final all = await EventService().loadEvents(petId);
      final matching = all.where((e) => e.id == entry.eventId).toList();
      for (final e in matching) {
        await EventService().deleteEvent(e);
      }
    }
  }
}
