import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';

/// The change to persist for the entry on the day being reviewed.
class DayOriginPatch {
  const DayOriginPatch({
    required this.day,
    required this.outcome,
    required this.outcomeAt,
    this.targetDay,
  });

  final DateTime day;
  final DayOutcome outcome;
  final DateTime? targetDay;
  final DateTime outcomeAt;
}

/// An open entry that must exist on a destination day.
class DayDestinationEnsure {
  const DayDestinationEnsure({required this.day, required this.via});

  final DateTime day;
  final DayVia via;
}

/// Pure, coordinated changes for a day-review action.
///
/// The repository uses the entry patches to preserve existing entry IDs, while
/// callers persist [noteUpdate] through their normal note storage path.
class DayMigrationPatches {
  const DayMigrationPatches({
    required this.originUpdate,
    required this.noteUpdate,
    this.destinationEnsure,
  });

  final DayOriginPatch originUpdate;
  final DayDestinationEnsure? destinationEnsure;
  final NoteItem noteUpdate;
}

void _requireDifferentDays(DateTime fromDay, DateTime toDay) {
  if (dateOnly(fromDay) == dateOnly(toDay)) {
    throw ArgumentError.value(
      toDay,
      'toDay',
      'The destination day must differ from the origin day.',
    );
  }
}

/// Move a task from [fromDay] to [toDay].
///
/// A move to today's calendar day becomes a Hoy commitment; a move to another
/// day becomes an all-day due date.
DayMigrationPatches migrateTo(
  NoteItem note,
  DateTime fromDay,
  DateTime toDay,
  DateTime now,
) {
  _requireDifferentDays(fromDay, toDay);
  final destination = dateOnly(toDay);
  final today = dateOnly(now);
  final movesToToday = destination == today;

  return DayMigrationPatches(
    originUpdate: DayOriginPatch(
      day: dateOnly(fromDay),
      outcome: DayOutcome.migrated,
      targetDay: destination,
      outcomeAt: now,
    ),
    destinationEnsure: DayDestinationEnsure(
      day: destination,
      via: DayVia.migratedIn,
    ),
    noteUpdate: note.copyWith(
      updatedAt: now,
      todayAt: movesToToday ? now : null,
      dueAt: movesToToday ? null : destination,
      dueHasTime: false,
    ),
  );
}

/// Schedule a task from [fromDay] to [toDay] as an all-day due date.
DayMigrationPatches scheduleTo(
  NoteItem note,
  DateTime fromDay,
  DateTime toDay,
  DateTime now,
) {
  _requireDifferentDays(fromDay, toDay);
  final destination = dateOnly(toDay);

  return DayMigrationPatches(
    originUpdate: DayOriginPatch(
      day: dateOnly(fromDay),
      outcome: DayOutcome.scheduled,
      targetDay: destination,
      outcomeAt: now,
    ),
    destinationEnsure: DayDestinationEnsure(
      day: destination,
      via: DayVia.scheduledIn,
    ),
    noteUpdate: note.copyWith(
      updatedAt: now,
      todayAt: null,
      dueAt: destination,
      dueHasTime: false,
    ),
  );
}

/// Return a task to the backlog without deleting it.
DayMigrationPatches sendToBacklog(
  NoteItem note,
  DateTime fromDay,
  DateTime now,
) {
  return DayMigrationPatches(
    originUpdate: DayOriginPatch(
      day: dateOnly(fromDay),
      outcome: DayOutcome.backlogged,
      outcomeAt: now,
    ),
    noteUpdate: note.copyWith(
      updatedAt: now,
      todayAt: null,
      dueAt: null,
      dueHasTime: false,
      reminderMinutesBefore: null,
    ),
  );
}

/// Close a task as discarded on [fromDay], retaining the task itself.
DayMigrationPatches cancelOnDay(
  NoteItem note,
  DateTime fromDay,
  DateTime now,
) {
  final day = dateOnly(fromDay);
  final clearToday = note.todayAt != null && dateOnly(note.todayAt!) == day;
  final clearDue = note.dueAt != null && dateOnly(note.dueAt!) == day;

  return DayMigrationPatches(
    originUpdate: DayOriginPatch(
      day: day,
      outcome: DayOutcome.cancelled,
      outcomeAt: now,
    ),
    noteUpdate: note.copyWith(
      updatedAt: now,
      todayAt: clearToday ? null : note.todayAt,
      dueAt: clearDue ? null : note.dueAt,
      dueHasTime: clearDue ? false : note.dueHasTime,
    ),
  );
}
