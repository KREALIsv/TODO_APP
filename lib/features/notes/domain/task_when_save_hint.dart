import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';

/// Plain-language preview of the main BuJo day-entry change on editor save.
///
/// One sentence, no chip timeline — prioritizes the outcome the user cares about.
String? taskWhenSaveHint({
  required NoteItem previous,
  required bool nextTodayOn,
  required DateTime? nextDueAt,
  DateTime? now,
}) {
  if (previous.type != NoteType.task) return null;
  final reference = now ?? DateTime.now();
  if (!_whenFieldsDiffer(previous, nextTodayOn, nextDueAt, reference)) {
    return null;
  }

  final prevToday = previous.isTodayCommitment(reference);
  final prevDue =
      previous.dueAt != null ? dateOnly(previous.dueAt!) : null;
  final nextDue = nextDueAt != null ? dateOnly(nextDueAt) : null;
  final prevTodayDay =
      previous.todayAt != null ? dateOnly(previous.todayAt!) : null;

  if (nextTodayOn) {
    return 'Al guardar: quedará en Hoy y en el Diario de hoy.';
  }

  if (prevDue != null && nextDue != null && prevDue != nextDue) {
    return 'Al guardar: ${formatDayMonth(prevDue)} quedará agendado hacia '
        '${formatDayMonth(nextDue)} y ${formatDayMonth(nextDue)} aparecerá pendiente.';
  }

  if (prevTodayDay != null && nextDue != null && prevTodayDay != nextDue) {
    return 'Al guardar: ${formatDayMonth(prevTodayDay)} quedará agendado hacia '
        '${formatDayMonth(nextDue)} y ${formatDayMonth(nextDue)} aparecerá pendiente.';
  }

  if ((prevToday || prevDue != null) && nextDue == null && !nextTodayOn) {
    final origin = prevTodayDay ?? prevDue;
    if (origin != null) {
      return 'Al guardar: ${formatDayMonth(origin)} pasará a Backlog '
          '(→ Backlog en el Diario).';
    }
    return 'Al guardar: volverá al Backlog sin día asignado.';
  }

  if (nextDue != null) {
    return 'Al guardar: quedará planificada para ${formatDayMonth(nextDue)}.';
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
