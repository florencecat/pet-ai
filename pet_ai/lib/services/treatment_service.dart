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
  /// [remindBeforeValue]/[remindBeforeVariant] — за сколько (дней/часов/минут)
  /// до [nextDate] напомнить.
  Future<TreatmentEntry?> addTreatment({
    required String petId,
    required TreatmentKind kind,
    required DateTime date,
    required DateTime nextDate,
    String name = '',
    int remindBeforeValue = 7,
    RemindBeforeVariant remindBeforeVariant = RemindBeforeVariant.days,
    int? color,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return null;

    // Создаём связанное событие на nextDate
    final eventName = (kind == TreatmentKind.vaccine && name.isNotEmpty)
        ? 'Прививка: $name'
        : kind.label;

    // Время по умолчанию — 10:00 в день мероприятия
    final eventDateTime = DateTime(
      nextDate.year, nextDate.month, nextDate.day, 10, 0,
    );

    // Запись заводим первой: событию нужен её id, чтобы знать своего родителя.
    final entry = TreatmentEntry(
      date: date,
      kind: kind,
      name: name,
      nextDate: nextDate,
      remindBeforeValue: remindBeforeValue,
      remindBeforeVariant: remindBeforeVariant,
      color: color,
    );

    final event = Event(
      name: eventName,
      category: EventCategories.vaccination,
      dateTime: eventDateTime,
      // Смещение напоминания задаётся напрямую value+variant (раньше здесь была
      // ошибка remindBeforeDays*24*60 при варианте «дни» → 1440× слишком рано).
      remindBeforeValue: remindBeforeValue,
      remindBeforeVariant: remindBeforeVariant,
      petIds: [petId],
      origin: TreatmentOrigin(entry.id),
      // Иконка/цвет события = выбранные пользователем вид и цвет обработки.
      styleKindId: kind.name,
      color: color,
    );

    await EventService().createEvent(event);
    entry.eventId = event.id;

    profile.treatmentHistory.add(entry);
    await PetProfileService().saveProfile(profile);

    // Fire-and-forget cloud push.
    CloudSyncService.instance.pushAsync(
      'treatments',
      entry,
      petId,
    );

    return entry;
  }

  /// Удалить запись о мероприятии вместе с её событием в календаре.
  Future<void> deleteTreatment(String petId, String entryId) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    final removed = profile.treatmentHistory.deleteById(entryId);
    if (removed == null) return;
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.deleteAsync('treatments', removed.id);

    await EventService().deleteBySource(petId, removed.id);

    // Записи, заведённые до появления TreatmentOrigin, не проставляли событию
    // source_id — их событие находится только по обратной ссылке.
    final legacyEventId = removed.eventId;
    if (legacyEventId == null) return;
    final legacyEvent = await EventService().findById(legacyEventId);
    if (legacyEvent != null) {
      await EventService().deleteEvent(legacyEvent, deleteOrigin: false);
    }
  }
}
