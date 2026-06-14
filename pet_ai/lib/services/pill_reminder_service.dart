import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/models/event.dart';

class PillReminderService {
  Future<Pill> add({
    required String petId,
    required Pill reminder,
  }) async {
    final profile = await PetService().loadProfile(petId);
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
        remindBeforeValue: 0,
        petIds: [petId],
        // Связываем событие с напоминанием для двусторонней синхронизации статуса
        source: EventSource.pill,
        sourceId: reminder.id,
      );

      await EventService().createEvent(event);
      saved = reminder.copyWith(eventId: event.id);
    }

    profile.pillReminders.add(saved);
    await PetService().saveProfile(profile);

    // Fire-and-forget cloud push.
    CloudSyncService.instance.pushAsync('pills', saved, petId);

    return saved;
  }

  /// Replaces an existing reminder in-place and persists the profile.
  /// Does NOT touch the linked PetEvent (name / time changes are kept
  /// local to the profile; a full sync can be added later).
  Future<void> update({
    required String petId,
    required Pill updated,
  }) async {
    final profile = await PetService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;
    profile.pillReminders[idx] = updated;
    await PetService().saveProfile(profile);
  }

  Future<void> delete({
    required String petId,
    required Pill reminder,
  }) async {
    final profile = await PetService().loadProfile(petId);
    if (profile == null) return;

    profile.pillReminders.removeWhere((r) => r.id == reminder.id);
    await PetService().saveProfile(profile);

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
    await _toggleAllTaken(petId: petId, reminderId: reminderId, date: date, add: true);
  }

  /// Clears all schedules for [date] (reverses markTaken).
  Future<void> markUntaken({
    required String petId,
    required String reminderId,
    required DateTime date,
  }) async {
    await _toggleAllTaken(petId: petId, reminderId: reminderId, date: date, add: false);
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
  }) async {
    final profile = await PetService().loadProfile(petId);
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
      newTakenSchedules[key] =
          List.generate(old.schedules.length, (i) => i);
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
    await PetService().saveProfile(profile);

    // Синхронизируем связанное событие в календаре
    if (old.eventId != null) {
      await EventService().setCompletedOn(old.eventId!, date, add);
    }
  }

  Future<void> _toggleSchedule({
    required String petId,
    required String reminderId,
    required DateTime date,
    required int scheduleIndex,
    required bool add,
  }) async {
    final profile = await PetService().loadProfile(petId);
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
    await PetService().saveProfile(profile);

    // Sync linked calendar event: complete when all schedules are taken.
    if (old.eventId != null) {
      await EventService().setCompletedOn(old.eventId!, date, allTaken);
    }
  }
}
