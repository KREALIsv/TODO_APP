import 'note_item.dart';

/// Presets de recordatorio (minutos antes del vencimiento).
///
/// `null` en [NoteItem.reminderMinutesBefore] = Ninguno.
/// `0` = en el momento del vencimiento.
class ReminderOffset {
  const ReminderOffset._(this.minutesBefore, this.label);

  final int minutesBefore;
  final String label;

  static const atDue = ReminderOffset._(0, 'En fecha de vencimiento');
  static const minutes5 = ReminderOffset._(5, '5 minutos antes');
  static const minutes10 = ReminderOffset._(10, '10 minutos antes');
  static const minutes30 = ReminderOffset._(30, '30 minutos antes');
  static const hour1 = ReminderOffset._(60, '1 hora antes');
  static const day1 = ReminderOffset._(1440, '1 día antes');
  static const day2 = ReminderOffset._(2880, '2 días antes');
  static const week1 = ReminderOffset._(10080, '1 semana antes');

  /// Catálogo UI (sin "Ninguno"; ese es `null`).
  static const List<ReminderOffset> presets = [
    atDue,
    minutes5,
    minutes10,
    minutes30,
    hour1,
    day1,
    day2,
    week1,
  ];

  static ReminderOffset? fromMinutes(int? minutes) {
    if (minutes == null) return null;
    for (final preset in presets) {
      if (preset.minutesBefore == minutes) return preset;
    }
    return ReminderOffset._(minutes, '$minutes min antes');
  }

  static String labelFor(int? minutes) {
    if (minutes == null) return 'Ninguno';
    return fromMinutes(minutes)!.label;
  }

  /// Hora local a la que debe disparar la notificación, o `null` si no aplica.
  ///
  /// Tareas sin hora (`dueHasTime == false`) se tratan como 09:00 del día de
  /// vencimiento (mismo patrón que muchas apps de tareas personales).
  static DateTime? fireAt(NoteItem item, {DateTime? now}) {
    final minutes = item.reminderMinutesBefore;
    final due = item.dueAt;
    if (minutes == null || due == null) return null;
    if (item.type != NoteType.task || item.completed || item.archivedAt != null) {
      return null;
    }

    final dueMoment = item.dueHasTime
        ? due
        : DateTime(due.year, due.month, due.day, 9, 0);

    final fire = dueMoment.subtract(Duration(minutes: minutes));
    final reference = now ?? DateTime.now();
    if (!fire.isAfter(reference)) return null;
    return fire;
  }

  /// Default razonable al activar recordatorio por primera vez.
  static int defaultMinutes({required bool dueHasTime}) {
    return dueHasTime ? hour1.minutesBefore : day1.minutesBefore;
  }
}

extension ReminderHelpers on NoteItem {
  bool get hasReminder =>
      reminderMinutesBefore != null &&
      dueAt != null &&
      !completed &&
      archivedAt == null;

  NoteItem clearReminder() => copyWith(reminderMinutesBefore: null);
}
