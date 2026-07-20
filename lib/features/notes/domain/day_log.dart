import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';
import 'task_dates.dart';

/// Filters [all] to entries whose [DayEntry.day] matches [day] (dateOnly).
List<DayEntry> entriesForDay(List<DayEntry> all, DateTime day) {
  final key = dateOnly(day);
  return all.where((e) => dateOnly(e.day) == key).toList(growable: false);
}

/// Resolved row for Diario UI: note + its entry for a day.
class DayLogRow {
  const DayLogRow({required this.note, required this.entry});

  final NoteItem note;
  final DayEntry entry;
}

/// Pinned notes first, then by createdAt ascending (stable diary order).
List<DayLogRow> resolveDayLogRows({
  required List<DayEntry> entries,
  required Map<String, NoteItem> notesById,
}) {
  final rows = <DayLogRow>[];
  for (final entry in entries) {
    final note = notesById[entry.noteId];
    if (note == null) continue;
    rows.add(DayLogRow(note: note, entry: entry));
  }

  rows.sort((a, b) {
    if (a.note.pinned != b.note.pinned) {
      return a.note.pinned ? -1 : 1;
    }
    return a.entry.createdAt.compareTo(b.entry.createdAt);
  });
  return rows;
}

/// Lazy backfill for legacy data: synthesize planned/completed entries from
/// [NoteItem] dates when a past day has no stored [DayEntry]s yet.
///
/// Pre-slice replay may still be incomplete (e.g. cleared todayAt).
List<DayEntry> synthesizeEntriesFromNotes({
  required List<NoteItem> notes,
  required DateTime day,
  required String Function() newId,
  DateTime? now,
}) {
  final key = dateOnly(day);
  final created = now ?? DateTime.now();
  final out = <DayEntry>[];

  for (final note in notes) {
    if (note.type != NoteType.task) continue;

    DayOutcome? outcome;
    DayVia via = DayVia.manual;
    DateTime? outcomeAt;

    if (note.completedAt != null && dateOnly(note.completedAt!) == key) {
      outcome = DayOutcome.completed;
      outcomeAt = note.completedAt;
      via = DayVia.manual;
    } else if (note.todayAt != null && dateOnly(note.todayAt!) == key) {
      outcome = note.completed ? DayOutcome.completed : DayOutcome.open;
      outcomeAt = note.completed ? (note.completedAt ?? created) : null;
      via = DayVia.todaySwitch;
    } else if (note.dueAt != null && dateOnly(note.dueAt!) == key) {
      outcome = note.completed ? DayOutcome.completed : DayOutcome.open;
      outcomeAt = note.completed ? (note.completedAt ?? created) : null;
      via = DayVia.due;
    }

    if (outcome == null) continue;

    out.add(
      DayEntry(
        id: newId(),
        noteId: note.id,
        day: key,
        via: via,
        outcome: outcome,
        outcomeAt: outcomeAt,
        createdAt: created,
      ),
    );
  }

  return out;
}

/// Active commitment day for completing a task (todayAt / dueAt / today).
DateTime commitmentDayFor(NoteItem note, DateTime now) {
  if (note.isTodayCommitment(now)) {
    return dateOnly(note.todayAt!);
  }
  if (note.dueAt != null) {
    return dateOnly(note.dueAt!);
  }
  return dateOnly(now);
}

/// Tasks planned for a future (or any) calendar [day] via dueAt / todayAt.
List<NoteItem> planNotesForDay(List<NoteItem> notes, DateTime day) {
  final key = dateOnly(day);
  final out = <NoteItem>[];
  for (final note in notes) {
    if (note.type != NoteType.task || note.isArchived) continue;
    final dueMatch = note.dueAt != null && dateOnly(note.dueAt!) == key;
    final todayMatch = note.todayAt != null && dateOnly(note.todayAt!) == key;
    if (dueMatch || todayMatch) out.add(note);
  }
  out.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return out;
}
