import 'package:pet_satellite/theme/app_colors.dart';

/// Единица измерения «напомнить за N …» для предварительных напоминаний.
enum RemindBeforeVariant { days, hours, minutes }

extension RemindBeforeVariantX on RemindBeforeVariant {
  String get label {
    switch (this) {
      case RemindBeforeVariant.days:
        return 'дней';
      case RemindBeforeVariant.hours:
        return 'часов';
      case RemindBeforeVariant.minutes:
        return 'минут';
    }
  }

  String declension(int count) {
    switch (this) {
      case RemindBeforeVariant.days:
        return dayDeclension(count);
      case RemindBeforeVariant.hours:
        return hourDeclension(count);
      case RemindBeforeVariant.minutes:
        return minuteDeclension(count);
    }
  }

  Duration duration(int count) {
    switch (this) {
      case RemindBeforeVariant.days:
        return Duration(days: count);
      case RemindBeforeVariant.hours:
        return Duration(hours: count);
      case RemindBeforeVariant.minutes:
        return Duration(minutes: count);
    }
  }
}

/// Общее поведение сущностей с предварительным напоминанием: событий, курсов
/// препаратов ([Pill]) и мед. мероприятий ([TreatmentEntry]).
///
/// Реализующий класс предоставляет [remindBeforeValue] и [remindBeforeVariant]
/// (обычно как `final`-поля — миксин не хранит состояние, чтобы не ломать
/// иммутабельные/`const` модели). Миксин добавляет вычисление смещения и сдвиг
/// времени уведомления: логика повторов конкретной модели для каждого
/// запланированного момента вызывает [reminderTimeFor], чтобы получить момент
/// показа напоминания «за N единиц до».
mixin Remindable {
  /// Насколько раньше срабатывает напоминание (в единицах [remindBeforeVariant]).
  int get remindBeforeValue;

  /// Единица измерения [remindBeforeValue].
  RemindBeforeVariant get remindBeforeVariant;

  /// Смещение напоминания «до» относительно запланированного момента.
  Duration get remindOffset =>
      remindBeforeVariant.duration(remindBeforeValue);

  /// Момент показа напоминания для запланированного [scheduledTime].
  /// Именно этот метод логика повторов Pill/Treatment использует, чтобы
  /// сместить начало уведомления на [remindOffset].
  DateTime reminderTimeFor(DateTime scheduledTime) =>
      scheduledTime.subtract(remindOffset);

  /// Задано ли предварительное напоминание (значение > 0).
  bool get hasRemindBefore => remindBeforeValue > 0;

  /// Человекочитаемая подпись «за N ед.» (пусто при нулевом значении).
  String get remindBeforeLabel => remindBeforeValue > 0
      ? 'за $remindBeforeValue ${remindBeforeVariant.declension(remindBeforeValue)}'
      : '';
}
