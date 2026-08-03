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
    if (entry != null && hasAuditableEntry(entry)) return true;
    return TaskDayQuery.belongsToDay(item, day, now: now);
  }

  /// Checkbox / strikethrough for a task when browsing [day].
  static bool isDisplayedCompleted(
    NoteItem item,
    DateTime day, {
    DayEntry? entry,
  }) {
    if (item.type != NoteType.task) return false;
    if (entry != null) {
      return entry.outcome == DayOutcome.completed;
    }

    final key = dateOnly(day);
    if (TaskDayQuery.isScheduledOn(item, day) ||
        TaskDayQuery.isInboxCaptureOn(item, day)) {
      return item.completed;
    }
    if (item.completedAt != null && dateOnly(item.completedAt!) == key) {
      return true;
    }
    return false;
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
      return TaskDayQuery.belongsToDay(item, day, now: now);
    }
    return entry.outcome == DayOutcome.open ||
        entry.outcome == DayOutcome.completed;
  }
}
