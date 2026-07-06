import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/models/event.dart';

class PillReminderService {
  Future<Pill> add({required String petId, required Pill reminder}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return reminder;

    // Препараты «по требованию» не имеют фиксированного расписания, поэтому
    // календарное событие для них не создаём.
    Pill saved = reminder;
    if (reminder.frequencyType != PillFrequencyType.onDemand) {
      final eventDateTime = DateTime(
        reminder.startDate.year,
        reminder.startDate.month,
        reminder.startDate.day,
        reminder.hour,
        reminder.minute,
      );

      final repeat = reminder.frequencyType == PillFrequencyType.daily
          ? RepeatInterval.daily
          : RepeatInterval.custom;

      final event = Event(
        name: reminder.name,
        category: EventCategories.health,
        dateTime: eventDateTime,
        repeat: repeat,
        customDays: reminder.frequencyType == PillFrequencyType.weekdays
            ? reminder.weekdays
            : [],
        // Курс препарата заканчивается — событие перестаёт повторяться.
        repeatEndDate: reminder.endDate,
        remindBeforeValue: 0,
        petIds: [petId],
        // Связываем событие с напоминанием для двусторонней синхронизации статуса
        source: EventSource.pill,
        sourceId: reminder.id,
        // Иконка/цвет события = выбранные пользователем вид и цвет препарата.
        styleKindId: reminder.kind?.id,
        color: reminder.color,
      );

      await EventService().createEvent(event);
      saved = reminder.copyWith(eventId: event.id);
    }

    profile.pillReminders.add(saved);
    await PetProfileService().saveProfile(profile);

    // Fire-and-forget cloud push.
    CloudSyncService.instance.pushAsync('pills', saved, petId);

    return saved;
  }

  /// Replaces an existing reminder in-place and persists the profile.
  /// Синхронизирует дату окончания курса со связанным PetEvent, чтобы
  /// законченные курсы переставали отображаться в календаре.
  /// (Изменения имени / времени пока остаются локальными в профиле.)
  Future<void> update({required String petId, required Pill updated}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;
    profile.pillReminders[idx] = updated;
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', updated, petId);

    // Синхронизируем дату окончания повтора и стиль (вид/цвет) события.
    if (updated.eventId != null) {
      final all = await EventService().loadEvents(petId);
      for (final e in all.where((e) => e.id == updated.eventId)) {
        e.repeatEndDate = updated.endDate;
        e.styleKindId = updated.kind?.id;
        e.color = updated.color;
        await EventService().saveEvent(e);
      }
    }
  }

  Future<void> delete({required String petId, required Pill reminder}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    profile.pillReminders.removeWhere((r) => r.id == reminder.id);
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.deleteAsync('pills', reminder.id);

    if (reminder.eventId != null) {
      final all = await EventService().loadEvents(petId);
      for (final e in all.where((e) => e.id == reminder.eventId)) {
        await EventService().deleteEvent(e);
      }
    }
  }

  /// Marks ALL schedules for [date] as taken (used by health-page tile checkbox
  /// for single-schedule pills, and by the "missed days" quick-mark button).
  Future<void> markTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
  }) async {
    await _toggleAllTaken(
      petId: petId,
      reminderId: reminderId,
      date: date,
      add: true,
    );
  }

  /// Clears all schedules for [date] (reverses markTaken).
  Future<void> markUntaken({
    required String petId,
    required String reminderId,
    required DateTime date,
  }) async {
    await _toggleAllTaken(
      petId: petId,
      reminderId: reminderId,
      date: date,
      add: false,
    );
  }

  /// Синхронизирует приём препарата при переключении связанного события из
  /// календаря (направление событие → препарат) за конкретный [day].
  ///
  /// Единственная точка синхронизации этого направления — вызывается из
  /// [EventService.toggleCompleted] после того, как событие уже сохранено,
  /// поэтому обратная запись в событие ([setCompletedOn]) НЕ выполняется
  /// (`syncEvent: false`) — иначе возникла бы петля и вторая гонка по событиям.
  ///
  /// Crash-safe: пустой [Event.petIds] и удалённый препарат обрабатываются
  /// без исключений (в отличие от прежнего `firstWhere`/`petIds.first`).
  Future<void> applyEventCompletion(
    Event event,
    DateTime day,
    bool completed,
  ) async {
    if (event.source != EventSource.pill ||
        event.sourceId == null ||
        event.sourceId!.isEmpty ||
        event.petIds.isEmpty) {
      return;
    }

    final petId = event.petIds.first;
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    final idx = profile.pillReminders.indexWhere((p) => p.id == event.sourceId);
    if (idx < 0) return; // препарат удалён — синхронизировать нечего

    // Сопоставляем конкретное расписание по времени события. Если совпадения
    // нет (время события не привязано к расписанию) — отмечаем весь день.
    final scheduleIndex = profile.pillReminders[idx].schedules.indexWhere(
      (s) => s.hour == event.dateTime.hour && s.minute == event.dateTime.minute,
    );

    if (scheduleIndex >= 0) {
      await _toggleSchedule(
        petId: petId,
        reminderId: event.sourceId!,
        date: day,
        scheduleIndex: scheduleIndex,
        add: completed,
        syncEvent: false,
      );
    } else {
      await _toggleAllTaken(
        petId: petId,
        reminderId: event.sourceId!,
        date: day,
        add: completed,
        syncEvent: false,
      );
    }
  }

  /// Marks a single [scheduleIndex] as taken for [date].
  Future<void> markScheduleTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required int scheduleIndex,
  }) async {
    await _toggleSchedule(
      petId: petId,
      reminderId: reminderId,
      date: date,
      scheduleIndex: scheduleIndex,
      add: true,
    );
  }

  /// Removes a single [scheduleIndex] from taken for [date].
  Future<void> markScheduleUntaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required int scheduleIndex,
  }) async {
    await _toggleSchedule(
      petId: petId,
      reminderId: reminderId,
      date: date,
      scheduleIndex: scheduleIndex,
      add: false,
    );
  }

  Future<void> _toggleAllTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required bool add,
    // false — не синхронизировать обратно связанное событие (когда вызов
    // пришёл из направления событие → препарат; событие уже обновлено).
    bool syncEvent = true,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final old = profile.pillReminders[idx];
    final key = Pill.dateKey(date);

    // Update takenSchedules: add all indices, or remove the whole day entry.
    final newTakenSchedules = Map<String, List<int>>.from(
      old.takenSchedules.map((k, v) => MapEntry(k, List<int>.from(v))),
    );
    if (add) {
      newTakenSchedules[key] = List.generate(old.schedules.length, (i) => i);
    } else {
      newTakenSchedules.remove(key);
    }

    // Keep legacy takenDates in sync.
    final newDates = List<String>.from(old.takenDates);
    if (add && !newDates.contains(key)) {
      newDates.add(key);
    } else if (!add) {
      newDates.remove(key);
    }

    profile.pillReminders[idx] = old.copyWith(
      takenDates: newDates,
      takenSchedules: newTakenSchedules,
    );
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync(
      'pills',
      profile.pillReminders[idx],
      petId,
    );

    // Синхронизируем связанное событие в календаре
    if (syncEvent && old.eventId != null) {
      await EventService().setCompletedOn(old.eventId!, date, add);
    }
  }

  // ── On-demand intake log («по требованию») ─────────────────────────────────

  /// Logs a single on-demand intake at [time] with an optional [dose].
  Future<void> addOnDemandIntake({
    required String petId,
    required String reminderId,
    required DateTime time,
    int doseValue = 0,
    DoseUnit doseUnit = DoseUnit.none,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final old = profile.pillReminders[idx];
    final newIntakes = List<PillIntake>.from(old.intakes)
      ..add(PillIntake(time: time, doseValue: doseValue, doseUnit: doseUnit))
      ..sort((a, b) => a.time.compareTo(b.time));

    profile.pillReminders[idx] = old.copyWith(intakes: newIntakes);
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', profile.pillReminders[idx], petId);
  }

  /// Removes the on-demand intake recorded at exactly [time].
  Future<void> removeOnDemandIntake({
    required String petId,
    required String reminderId,
    required DateTime time,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final old = profile.pillReminders[idx];
    final newIntakes = List<PillIntake>.from(old.intakes);
    final removeAt = newIntakes.indexWhere(
      (i) => i.time.isAtSameMomentAs(time),
    );
    if (removeAt < 0) return;
    newIntakes.removeAt(removeAt);

    profile.pillReminders[idx] = old.copyWith(intakes: newIntakes);
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', profile.pillReminders[idx], petId);
  }

  Future<void> _toggleSchedule({
    required String petId,
    required String reminderId,
    required DateTime date,
    required int scheduleIndex,
    required bool add,
    // false — не синхронизировать обратно связанное событие (вызов из
    // направления событие → препарат; событие уже обновлено).
    bool syncEvent = true,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final old = profile.pillReminders[idx];
    final key = Pill.dateKey(date);

    final newTakenSchedules = Map<String, List<int>>.from(
      old.takenSchedules.map((k, v) => MapEntry(k, List<int>.from(v))),
    );
    final dayList = List<int>.from(newTakenSchedules[key] ?? []);

    if (add && !dayList.contains(scheduleIndex)) {
      dayList.add(scheduleIndex);
    } else if (!add) {
      dayList.remove(scheduleIndex);
    } else {
      return; // already in correct state
    }

    if (dayList.isEmpty) {
      newTakenSchedules.remove(key);
    } else {
      newTakenSchedules[key] = dayList;
    }

    // Keep legacy takenDates in sync: set when ALL schedules taken.
    final allTaken = dayList.length >= old.schedules.length;
    final newDates = List<String>.from(old.takenDates);
    if (allTaken && !newDates.contains(key)) {
      newDates.add(key);
    } else if (!allTaken) {
      newDates.remove(key);
    }

    profile.pillReminders[idx] = old.copyWith(
      takenDates: newDates,
      takenSchedules: newTakenSchedules,
    );
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync(
      'pills',
      profile.pillReminders[idx],
      petId,
    );

    // Sync linked calendar event: complete when all schedules are taken.
    if (syncEvent && old.eventId != null) {
      await EventService().setCompletedOn(old.eventId!, date, allTaken);
    }
  }
}
