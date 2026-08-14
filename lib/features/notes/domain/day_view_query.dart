import 'date_only.dart';
import 'day_entry.dart';
import 'note_item.dart';
import 'task_day_query.dart';
import 'task_dates.dart';

/// Per-day audit rules for Home «Del día»: what appeared on a calendar day and
/// how it should look, independent of the task's current schedule.
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

  /// Task membership for «Del día» when [entry] is the resolved row for [day].
  static bool taskBelongsToDay(
    NoteItem item,
    DateTime day, {
    DateTime? now,
    DayEntry? entry,
  }) {
    if (item.type != NoteType.task) return false;
    final reference = now ?? DateTime.now();

    if (entry != null && hasAuditableEntry(entry)) {
      if (entry.outcome == DayOutcome.open) {
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
  /// entry (Hoy / Backlog / Todas) follow the task's global [NoteItem.completed]
  /// so a finished task never looks like an open checkbox.
  static bool isDisplayedCompleted(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
  }) {
    if (item.type != NoteType.task) return false;
    if (entry != null) {
      return entry.outcome == DayOutcome.completed;
    }
    if (item.completed) return true;
    final key = dateOnly(day);
    if (item.completedAt != null && dateOnly(item.completedAt!) == key) {
      return true;
    }
    return false;
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
      if (item.completed) return true;
      return TaskDayQuery.belongsToDay(item, day, now: now);
    }
    return entry.outcome == DayOutcome.open ||
        entry.outcome == DayOutcome.completed;
  }
}
