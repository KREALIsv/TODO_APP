import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';
import 'task_dates.dart';

/// Preview when «¿Cuándo?» changes in the editor (applied on save).
String? taskWhenSaveHint({
  required NoteItem previous,
  required bool nextTodayOn,
  required DateTime? nextDueAt,
  DateTime? now,
}) {
  return taskWhenChangeHint(
    previous: previous,
    nextTodayOn: nextTodayOn,
    nextDueAt: nextDueAt,
    now: now,
    onSave: true,
  );
}

/// Plain-language preview for a «¿Cuándo?» change (context menu = instant).
String? taskWhenChangeHint({
  required NoteItem previous,
  required bool nextTodayOn,
  required DateTime? nextDueAt,
  DateTime? now,
  bool onSave = false,
}) {
  if (previous.type != NoteType.task) return null;
  final reference = now ?? DateTime.now();
  if (!_whenFieldsDiffer(previous, nextTodayOn, nextDueAt, reference)) {
    return null;
  }

  final prefix = onSave ? 'Al guardar: ' : '';
  final prevToday = previous.isTodayCommitment(reference);
  final prevDue =
      previous.dueAt != null ? dateOnly(previous.dueAt!) : null;
  final nextDue = nextDueAt != null ? dateOnly(nextDueAt) : null;
  final prevTodayDay =
      previous.todayAt != null ? dateOnly(previous.todayAt!) : null;

  if (nextTodayOn) {
    return '${prefix}Quedará en Hoy.';
  }

  final origin = prevTodayDay ?? prevDue;
  if (origin != null && nextDue != null && origin != nextDue) {
    return '${prefix}Del ${formatDayMonth(origin)} al ${formatDayMonth(nextDue)}.';
  }

  if ((prevToday || prevDue != null) && nextDue == null && !nextTodayOn) {
    if (origin != null) {
      return '${prefix}Se quita del día (${formatDayMonth(origin)}).';
    }
    return '${prefix}Sin día asignado.';
  }

  if (nextDue != null) {
    return '${prefix}Planificada para el ${formatDayMonth(nextDue)}.';
  }

  return null;
}

bool _whenFieldsDiffer(
  NoteItem previous,
  bool nextTodayOn,
  DateTime? nextDueAt,
  DateTime now,
) {
  if (previous.isTodayCommitment(now) != nextTodayOn) return true;
  final prevDue = previous.dueAt != null ? dateOnly(previous.dueAt!) : null;
  final nextDue = nextDueAt != null ? dateOnly(nextDueAt) : null;
  return prevDue != nextDue;
}

/// Short label for a [DayOutcome] when listing BuJo states (no icon).
String dayOutcomeShortLabel(DayEntry entry) {
  switch (entry.outcome) {
    case DayOutcome.open:
      return 'Pendiente';
    case DayOutcome.completed:
      return 'Completada';
    case DayOutcome.migrated:
      final target = entry.targetDay;
      return target == null
          ? 'Migrada'
          : 'Migrada → ${formatDayMonth(target)}';
    case DayOutcome.scheduled:
      final target = entry.targetDay;
      return target == null
          ? 'Agendada'
          : 'Agendada → ${formatDayMonth(target)}';
    case DayOutcome.cancelled:
      return 'Descartada';
    case DayOutcome.backlogged:
      return '→ Backlog';
  }
}
