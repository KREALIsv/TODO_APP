import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';
import 'task_day_query.dart';
import 'task_dates.dart';

/// Per-day rules for Home «Del día» (PRD-day-review §8.2).
///
/// - **Today / future** → execution or plan: only live commitments
///   ([TaskDayQuery] + open day-log rows that still belong).
/// - **Past** → diary replay: closed [DayEntry] outcomes stay visible so
///   migradas / agendadas are not lost.
abstract final class DayViewQuery {
  /// Whether a task row should stay visible on [day] thanks to day-log history.
  static bool hasAuditableEntry(DayEntry entry) {
    switch (entry.outcome) {
      case DayOutcome.open:
      case DayOutcome.completed:
      case DayOutcome.migrated:
      case DayOutcome.scheduled:
      case DayOutcome.cancelled:
      case DayOutcome.backlogged:
        return true;
    }
  }

  /// Past calendar days use full day-log replay; today and future do not.
  static bool isReplayDay(DateTime day, {DateTime? now}) {
    return dateOnly(day).isBefore(dateOnly(now ?? DateTime.now()));
  }

  /// Open day-log row that still counts as a live commitment on [day].
  static bool _openEntryBelongsToDay(
    NoteItem item,
    DateTime day,
    DayEntry entry, {
    required DateTime reference,
  }) {
    if (entry.outcome != DayOutcome.open) return false;
    if (TaskDayQuery.isScheduledOn(item, day)) return true;
    if (entry.via == DayVia.migratedIn || entry.via == DayVia.scheduledIn) {
      return true;
    }
    if (TaskDayQuery.isInboxCaptureOn(item, day) &&
        dateOnly(day) == dateOnly(reference)) {
      return true;
    }
    return false;
  }

  /// Task membership for «Del día» when [entry] is the resolved row for [day].
  static bool taskBelongsToDay(
    NoteItem item,
    DateTime day, {
    DateTime? now,
    DayEntry? entry,
  }) {
    if (item.type != NoteType.task) return false;
    final reference = now ?? DateTime.now();

    // Today / future: execution & plan — never keep closed audit-only rows
    // (e.g. "Agendada → mañana" must leave today's work list).
    if (!isReplayDay(day, now: reference)) {
      if (entry != null) {
        if (entry.outcome == DayOutcome.open) {
          return _openEntryBelongsToDay(
            item,
            day,
            entry,
            reference: reference,
          );
        }
        // Completions still surface via live schedule / completedAt.
        // Other closed outcomes (migrated, scheduled, cancelled, backlogged)
        // are diary-only and must not re-enter via inbox-capture rules.
        if (entry.outcome != DayOutcome.completed) return false;
      }
      return TaskDayQuery.belongsToDay(item, day, now: reference);
    }

    // Past: full diary replay from the day log.
    if (entry != null && hasAuditableEntry(entry)) {
      if (entry.outcome == DayOutcome.open) {
        return _openEntryBelongsToDay(
          item,
          day,
          entry,
          reference: reference,
        );
      }
      return true;
    }
    return TaskDayQuery.belongsToDay(item, day, now: reference);
  }

  /// Normal list row (checkbox, black title) vs dimmed audit replay row.
  ///
  /// Past days are always diary replay: an unfinished (`open`) commitment
  /// stays muted so it reads as “was planned here, but wasn’t done”.
  static bool isLiveDayRow(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
    DateTime? now,
  }) {
    if (item.type != NoteType.task) return true;
    final reference = now ?? DateTime.now();
    if (dateOnly(day).isBefore(dateOnly(reference))) {
      return false;
    }
    if (entry?.outcome == DayOutcome.open) return true;
    if (entry == null) return true;
    return TaskDayQuery.isScheduledOn(item, day);
  }

  static bool showOutcomeMetaForDayRow(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
    DateTime? now,
  }) {
    if (entry == null) return false;
    if (isLiveDayRow(item, day, entry: entry, now: now)) return false;
    return entry.outcome != DayOutcome.completed;
  }

  /// Checkbox / strikethrough for a task when browsing [day].
  ///
  /// Day-log rows follow that day's [DayEntry.outcome]. List views without an
  /// entry (Hoy / Backlog / Todas) follow [NoteItem.completed] so a finished
  /// task never looks like an open checkbox.
  static bool isDisplayedCompleted(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
  }) {
    if (item.type != NoteType.task) return false;
    if (entry != null) {
      return entry.outcome == DayOutcome.completed;
    }
    return item.completed;
  }

  /// Whether «Quitar del día» applies while browsing [day].
  static bool canRemoveFromDay(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
    DateTime? now,
  }) {
    if (item.isArchived || item.type != NoteType.task) return false;
    if (entry?.outcome == DayOutcome.open) return true;
    if (TaskDayQuery.isScheduledOn(item, day)) return true;
    if (TaskDayQuery.isInboxCaptureOn(item, day)) return true;
    return TaskDayQuery.belongsToDay(item, day, now: now ?? DateTime.now()) &&
        entry == null;
  }

  /// Calendar days the user can detach this task from (open log + commitments).
  static List<DateTime> removeFromDayCandidates({
    required NoteItem item,
    required List<DayEntry> entries,
    DateTime? now,
  }) {
    if (item.type != NoteType.task) return const [];
    final reference = now ?? DateTime.now();
    final keys = <DateTime>{};

    for (final entry in entries) {
      if (entry.outcome != DayOutcome.open) continue;
      if (canRemoveFromDay(item, entry.day, entry: entry, now: reference)) {
        keys.add(dateOnly(entry.day));
      }
    }

    if (item.todayAt != null) {
      final day = dateOnly(item.todayAt!);
      if (canRemoveFromDay(item, day, now: reference)) keys.add(day);
    }
    if (item.dueAt != null) {
      final day = dateOnly(item.dueAt!);
      if (canRemoveFromDay(item, day, now: reference)) keys.add(day);
    }

    final list = keys.toList()..sort((a, b) => b.compareTo(a));
    return list;
  }

  /// Whether completion can be toggled from the list while viewing [day].
  static bool canToggleCompletionOnDay({
    required NoteItem item,
    required DateTime day,
    DayEntry? entry,
    required DateTime now,
  }) {
    if (item.isArchived || item.type != NoteType.task) return false;
    if (entry == null) {
      return isDisplayedCompleted(item, day) ||
          TaskDayQuery.belongsToDay(item, day, now: now);
    }
    return entry.outcome == DayOutcome.open ||
        entry.outcome == DayOutcome.completed;
  }
}
