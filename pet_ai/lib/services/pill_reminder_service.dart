import 'package:pet_ai/models/pill_reminder.dart';
import 'package:pet_ai/services/event_service.dart';
import 'package:pet_ai/services/profile_service.dart';

class PillReminderService {
  Future<PillReminder> add({
    required String petId,
    required PillReminder reminder,
  }) async {
    final profile = await ProfileService().loadProfile(petId);
    if (profile == null) return reminder;

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

    final event = PetEvent(
      name: reminder.name,
      category: EventCategories.health,
      dateTime: eventDateTime,
      repeat: repeat,
      customDays: reminder.frequencyType == PillFrequencyType.weekdays
          ? reminder.weekdays
          : [],
      remindBeforeMinutes: 0,
      petIds: [petId],
    );

    await EventService().createEvent(event);

    final saved = reminder.copyWith(eventId: event.id);
    profile.pillReminders.add(saved);
    await ProfileService().saveProfile(profile);

    return saved;
  }

  Future<void> delete({
    required String petId,
    required PillReminder reminder,
  }) async {
    final profile = await ProfileService().loadProfile(petId);
    if (profile == null) return;

    profile.pillReminders.removeWhere((r) => r.id == reminder.id);
    await ProfileService().saveProfile(profile);

    if (reminder.eventId != null) {
      final all = await EventService().loadEvents(petId);
      for (final e in all.where((e) => e.id == reminder.eventId)) {
        await EventService().deleteEvent(e);
      }
    }
  }

  Future<void> markTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
  }) async {
    await _toggleTaken(petId: petId, reminderId: reminderId, date: date, add: true);
  }

  Future<void> markUntaken({
    required String petId,
    required String reminderId,
    required DateTime date,
  }) async {
    await _toggleTaken(petId: petId, reminderId: reminderId, date: date, add: false);
  }

  Future<void> _toggleTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required bool add,
  }) async {
    final profile = await ProfileService().loadProfile(petId);
    if (profile == null) return;

    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final old = profile.pillReminders[idx];
    final key = PillReminder.dateKey(date);
    final newDates = List<String>.from(old.takenDates);
    if (add && !newDates.contains(key)) {
      newDates.add(key);
    } else if (!add) {
      newDates.remove(key);
    } else {
      return;
    }
    profile.pillReminders[idx] = old.copyWith(takenDates: newDates);
    await ProfileService().saveProfile(profile);
  }
}
