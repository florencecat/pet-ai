import 'package:pet_satellite/models/pill.dart';
import 'package:pet_satellite/services/cloud_sync_service.dart';
import 'package:pet_satellite/services/event_service.dart';
import 'package:pet_satellite/services/pet_profile_service.dart';
import 'package:pet_satellite/models/event.dart';

/// Курсы препаратов и отметки об их приёме.
///
/// Каждому времени приёма ([PillSchedule]) соответствует своё событие календаря
/// — через него идут уведомления и отметки выполнения. Связь хранится в
/// [PillSchedule.eventId], отметки — в [Pill.takenSchedules] по
/// [PillSchedule.id].
///
/// Отметка живёт в двух местах (у курса и у события), поэтому синхронизируется
/// в обе стороны:
///  * курс → событие: [setScheduleTaken] / [setDayTaken] зовут
///    [EventService.setCompletedOn];
///  * событие → курс: [EventService.toggleCompleted] зовёт
///    [applyEventCompletion].
///
/// Обратная запись всегда отключается флагом `syncEvent: false` на входящем
/// направлении — иначе стороны зациклились бы.
class PillReminderService {
  // ── CRUD ───────────────────────────────────────────────────────────────────

  Future<Pill> add({required String petId, required Pill reminder}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return reminder;

    await _syncEvents(petId: petId, pill: reminder);

    profile.pillReminders.add(reminder);
    await PetProfileService().saveProfile(profile);

    // Fire-and-forget cloud push.
    CloudSyncService.instance.pushAsync('pills', reminder, petId);

    return reminder;
  }

  /// Заменяет курс и приводит его события в соответствие: заводит их новым
  /// временам приёма, обновляет существующие и удаляет осиротевшие.
  Future<void> update({required String petId, required Pill updated}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == updated.id);
    if (idx < 0) return;

    await _syncEvents(
      petId: petId,
      pill: updated,
      previous: profile.pillReminders[idx],
    );

    profile.pillReminders[idx] = updated;
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', updated, petId);
  }

  Future<void> delete({required String petId, required Pill reminder}) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;

    profile.pillReminders.removeWhere((r) => r.id == reminder.id);
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.deleteAsync('pills', reminder.id);

    // PillOrigin покрывает события всех времён приёма разом.
    await EventService().deleteBySource(petId, reminder.id);
  }

  /// Убирает из курса время приёма, событие которого удалили из календаря
  /// (направление событие → курс).
  ///
  /// Удаляется только этот приём: у курса событий столько же, сколько времён
  /// приёма, и снос всего курса из-за одного из них пользователь не заказывал.
  /// Последнее время приёма — курса больше нет.
  Future<void> deleteSchedule({
    required String petId,
    required String pillId,
    required String eventId,
  }) async {
    final pill = await _find(petId, pillId);
    if (pill == null) return; // курс уже удалён

    final remaining = pill.schedules
        .where((s) => s.eventId != eventId)
        .toList();
    // Связь потерялась: правя курс, событие можно снести не то. Пусть его
    // заново заведёт _syncEvents при следующей правке.
    if (remaining.length == pill.schedules.length) return;

    if (remaining.isEmpty) {
      await delete(petId: petId, reminder: pill);
    } else {
      await update(petId: petId, updated: pill.copyWith(schedules: remaining));
    }
  }

  // ── События курса ──────────────────────────────────────────────────────────

  /// Приводит события календаря в соответствие с [pill]: у каждого времени
  /// приёма — своё событие. [previous] (версия курса до правки) нужна, чтобы
  /// найти события убранных времён.
  ///
  /// Мутирует [pill]: проставляет [PillSchedule.eventId] новым расписаниям.
  Future<void> _syncEvents({
    required String petId,
    required Pill pill,
    Pill? previous,
  }) async {
    // «По требованию» не имеет расписания: приёмы отмечаются вручную, событий
    // в календаре у такого курса нет.
    final schedules = pill.frequencyType == PillFrequencyType.onDemand
        ? const <PillSchedule>[]
        : pill.schedules;

    final liveEventIds = schedules
        .map((s) => s.eventId)
        .whereType<String>()
        .toSet();

    // Событие осталось от времени приёма, которого в курсе больше нет (его
    // убрали или курс перевели в «по требованию») — иначе оно продолжало бы
    // висеть в календаре и слать уведомления.
    final staleEventIds = (previous?.schedules ?? const <PillSchedule>[])
        .map((s) => s.eventId)
        .whereType<String>()
        .where((id) => !liveEventIds.contains(id))
        .toSet();

    final all = await EventService().loadEvents(petId);

    // deleteOrigin: false — курс уже приведён к нужному виду вызывающим, и
    // удалять его из-за собственной же правки нельзя.
    for (final e in all.where((e) => staleEventIds.contains(e.id))) {
      await EventService().deleteEvent(e, deleteOrigin: false);
    }

    // Курс перевели в «по требованию»: события удалены выше, обнуляем и ссылки
    // на них, чтобы в расписаниях не остались id несуществующих событий.
    if (schedules.isEmpty) {
      for (final schedule in pill.schedules) {
        schedule.eventId = null;
      }
      return;
    }

    final byId = {for (final e in all) e.id: e};
    for (final schedule in schedules) {
      final linked = byId[schedule.eventId];
      if (linked == null) {
        // Времени приёма ещё нет события — заводим и запоминаем связь.
        final event = _newEvent(petId: petId, pill: pill, schedule: schedule);
        await EventService().createEvent(event);
        schedule.eventId = event.id;
      } else {
        _applyPill(linked, pill: pill, schedule: schedule);
        await EventService().saveEvent(linked);
      }
    }
  }

  Event _newEvent({
    required String petId,
    required Pill pill,
    required PillSchedule schedule,
  }) {
    final event = Event(
      name: pill.name,
      category: EventCategories.health,
      dateTime: _firstOccurrence(pill, schedule),
      petIds: [petId],
      // Связь с курсом для двусторонней синхронизации отметок.
      origin: PillOrigin(pill.id),
    );
    _applyPill(event, pill: pill, schedule: schedule);
    return event;
  }

  /// Переносит поля курса на событие. [Event.origin] не трогаем — он final и
  /// уже указывает на этот курс.
  void _applyPill(
    Event event, {
    required Pill pill,
    required PillSchedule schedule,
  }) {
    event.name = pill.name;
    event.dateTime = _firstOccurrence(pill, schedule);
    event.repeat = pill.frequencyType == PillFrequencyType.daily
        ? RepeatInterval.daily
        : RepeatInterval.custom;
    event.customDays = pill.frequencyType == PillFrequencyType.weekdays
        ? pill.weekdays
        : const [];
    // Курс препарата заканчивается — событие перестаёт повторяться.
    event.repeatEndDate = pill.endDate;
    // «Напомнить за» до каждого приёма — переносится с курса на событие.
    event.remindBeforeValue = pill.remindBeforeValue;
    event.remindBeforeVariant = pill.remindBeforeVariant;
    // Иконка/цвет события = выбранные пользователем вид и цвет препарата.
    event.styleKindId = pill.kind?.id;
    event.color = pill.color;
  }

  /// Первый приём по этому расписанию — старт курса в час/минуту расписания.
  /// По остальным дням его разносит повтор события.
  DateTime _firstOccurrence(Pill pill, PillSchedule schedule) => DateTime(
    pill.startDate.year,
    pill.startDate.month,
    pill.startDate.day,
    schedule.hour,
    schedule.minute,
  );

  // ── Отметки о приёме ───────────────────────────────────────────────────────

  /// Отмечает принятым (или снимает отметку) весь день [date] сразу — плитка на
  /// странице здоровья и кнопка «Принято» у пропущенных дней.
  Future<void> setDayTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required bool taken,
    bool syncEvent = true,
  }) async {
    await _update(petId, reminderId, (pill) {
      final ids = taken ? pill.schedules.map((s) => s.id).toList() : <String>[];
      return _withTaken(pill, date, ids);
    }, syncEvent: syncEvent, date: date, taken: taken);
  }

  /// Отмечает принятым (или снимает отметку) один приём за [date].
  Future<void> setScheduleTaken({
    required String petId,
    required String reminderId,
    required DateTime date,
    required String scheduleId,
    required bool taken,
    bool syncEvent = true,
  }) async {
    await _update(petId, reminderId, (pill) {
      final ids = List<String>.from(pill.takenScheduleIdsOn(date));
      if (taken) {
        if (!ids.contains(scheduleId)) ids.add(scheduleId);
      } else {
        ids.remove(scheduleId);
      }
      return _withTaken(pill, date, ids);
    }, syncEvent: syncEvent, date: date, taken: taken, scheduleId: scheduleId);
  }

  /// Синхронизирует курс при переключении связанного события из календаря
  /// (направление событие → курс) за конкретный [day].
  ///
  /// Вызывается из [EventService.toggleCompleted] уже после сохранения события,
  /// поэтому обратная запись выключена (`syncEvent: false`) — иначе стороны
  /// зациклились бы.
  ///
  /// Crash-safe: пустой [Event.petIds] и удалённый курс обрабатываются без
  /// исключений.
  Future<void> applyEventCompletion(
    Event event,
    DateTime day,
    bool completed,
  ) async {
    final origin = event.origin;
    if (origin is! PillOrigin || origin.pillId.isEmpty || event.petIds.isEmpty) {
      return;
    }
    final pillId = origin.pillId;

    final petId = event.petIds.first;
    final pill = await _find(petId, pillId);
    if (pill == null) return; // курс удалён — синхронизировать нечего

    // Событие принадлежит конкретному времени приёма — отмечаем только его.
    // Если связь потерялась, трактуем отметку как «весь день».
    final schedule = _scheduleOf(pill, event.id);
    if (schedule == null) {
      await setDayTaken(
        petId: petId,
        reminderId: pillId,
        date: day,
        taken: completed,
        syncEvent: false,
      );
    } else {
      await setScheduleTaken(
        petId: petId,
        reminderId: pillId,
        date: day,
        scheduleId: schedule.id,
        taken: completed,
        syncEvent: false,
      );
    }
  }

  /// Курс с обновлённым набором отметок за [date]. Пустой список убирает день
  /// из карты, чтобы та не копила пустые записи.
  Pill _withTaken(Pill pill, DateTime date, List<String> scheduleIds) {
    final taken = Map<String, List<String>>.from(pill.takenSchedules);
    final key = Pill.dateKey(date);
    if (scheduleIds.isEmpty) {
      taken.remove(key);
    } else {
      taken[key] = scheduleIds;
    }
    return pill.copyWith(takenSchedules: taken);
  }

  /// Применяет [change] к курсу, сохраняет профиль и подтягивает события.
  ///
  /// [scheduleId] задан — событие только этого приёма; иначе события всех
  /// времён приёма за день.
  Future<void> _update(
    String petId,
    String reminderId,
    Pill Function(Pill pill) change, {
    required bool syncEvent,
    required DateTime date,
    required bool taken,
    String? scheduleId,
  }) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final updated = change(profile.pillReminders[idx]);
    profile.pillReminders[idx] = updated;
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', updated, petId);

    if (!syncEvent) return;
    final affected = scheduleId == null
        ? updated.schedules
        : updated.schedules.where((s) => s.id == scheduleId);
    for (final schedule in affected) {
      final eventId = schedule.eventId;
      if (eventId == null) continue;
      await EventService().setCompletedOn(eventId, date, taken);
    }
  }

  Future<Pill?> _find(String petId, String reminderId) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return null;
    for (final pill in profile.pillReminders) {
      if (pill.id == reminderId) return pill;
    }
    return null;
  }

  PillSchedule? _scheduleOf(Pill pill, String eventId) {
    for (final schedule in pill.schedules) {
      if (schedule.eventId == eventId) return schedule;
    }
    return null;
  }

  // ── Журнал приёмов «по требованию» ─────────────────────────────────────────

  /// Записывает разовый приём в [time] с необязательной дозой.
  Future<void> addOnDemandIntake({
    required String petId,
    required String reminderId,
    required DateTime time,
    int doseValue = 0,
    DoseUnit doseUnit = DoseUnit.none,
  }) async {
    await _updateIntakes(petId, reminderId, (intakes) {
      intakes
        ..add(PillIntake(time: time, doseValue: doseValue, doseUnit: doseUnit))
        ..sort((a, b) => a.time.compareTo(b.time));
    });
  }

  /// Убирает приём, записанный ровно в [time].
  Future<void> removeOnDemandIntake({
    required String petId,
    required String reminderId,
    required DateTime time,
  }) async {
    await _updateIntakes(petId, reminderId, (intakes) {
      intakes.removeWhere((i) => i.time.isAtSameMomentAs(time));
    });
  }

  Future<void> _updateIntakes(
    String petId,
    String reminderId,
    void Function(List<PillIntake> intakes) change,
  ) async {
    final profile = await PetProfileService().loadProfile(petId);
    if (profile == null) return;
    final idx = profile.pillReminders.indexWhere((r) => r.id == reminderId);
    if (idx < 0) return;

    final intakes = List<PillIntake>.from(profile.pillReminders[idx].intakes);
    change(intakes);

    final updated = profile.pillReminders[idx].copyWith(intakes: intakes);
    profile.pillReminders[idx] = updated;
    await PetProfileService().saveProfile(profile);
    CloudSyncService.instance.pushAsync('pills', updated, petId);
  }
}
