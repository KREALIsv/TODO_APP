import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';
import 'task_day_query.dart';
import 'task_dates.dart';

/// Filters [all] to entries whose [DayEntry.day] matches [day] (dateOnly).
///
/// When several rows exist for the same note on one day, keeps the latest event
/// (for Diario — one row per task per day).
List<DayEntry> entriesForDay(List<DayEntry> all, DateTime day) {
  final key = dateOnly(day);
  final byNote = <String, DayEntry>{};

  for (final entry in all) {
    if (dateOnly(entry.day) != key) continue;
    final existing = byNote[entry.noteId];
    if (existing == null || _isNewerDayEvent(entry, existing)) {
      byNote[entry.noteId] = entry;
    }
  }

  return byNote.values.toList(growable: false);
}

bool _isNewerDayEvent(DayEntry candidate, DayEntry incumbent) {
  if (candidate.outcome == DayOutcome.open &&
      incumbent.outcome != DayOutcome.open) {
    return true;
  }
  if (incumbent.outcome == DayOutcome.open &&
      candidate.outcome != DayOutcome.open) {
    return false;
  }
  final candidateAt = candidate.outcomeAt ?? candidate.createdAt;
  final incumbentAt = incumbent.outcomeAt ?? incumbent.createdAt;
  return candidateAt.isAfter(incumbentAt);
}

/// All day log rows for a task, newest event first (may include several per day).
List<DayEntry> entriesForNote(List<DayEntry> all, String noteId) {
  final rows = all.where((e) => e.noteId == noteId).toList();
  rows.sort((a, b) {
    final aTime = a.outcomeAt ?? a.createdAt;
    final bTime = b.outcomeAt ?? b.createdAt;
    final timeCmp = bTime.compareTo(aTime);
    if (timeCmp != 0) return timeCmp;
    return b.day.compareTo(a.day);
  });
  return rows;
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
    } else if (TaskDayQuery.isInboxCaptureOn(note, day)) {
      outcome = note.completed ? DayOutcome.completed : DayOutcome.open;
      outcomeAt = note.completed ? (note.completedAt ?? created) : null;
      via = DayVia.manual;
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

/// Calendar day a completion should be attributed to.
///
/// Prefers an explicit [onDay] (e.g. Home day selector), then the task's
/// commitment ([todayAt] even when stale, then [dueAt]), else [now].
DateTime commitmentDayFor(
  NoteItem note,
  DateTime now, {
  DateTime? onDay,
}) {
  if (onDay != null) return dateOnly(onDay);
  if (note.todayAt != null) return dateOnly(note.todayAt!);
  if (note.dueAt != null) return dateOnly(note.dueAt!);
  return dateOnly(now);
}

/// Timestamp stored on [NoteItem.completedAt] / [DayEntry.outcomeAt].
///
/// Past days anchor to end-of-day so audit views stay on the intended calendar
/// day; today keeps the real clock time.
DateTime completionOutcomeAt(DateTime day, DateTime now) {
  final key = dateOnly(day);
  if (key == dateOnly(now)) return now;
  return DateTime(day.year, day.month, day.day, 23, 59, 59);
}

/// Tasks planned for a future (or any) calendar [day] via dueAt / todayAt.
List<NoteItem> planNotesForDay(List<NoteItem> notes, DateTime day) {
  final out = <NoteItem>[];
  for (final note in notes) {
    if (note.type != NoteType.task || note.isArchived) continue;
    if (TaskDayQuery.isScheduledOn(note, day)) out.add(note);
  }
  out.sort((a, b) {
    if (a.pinned != b.pinned) return a.pinned ? -1 : 1;
    return b.updatedAt.compareTo(a.updatedAt);
  });
  return out;
}
