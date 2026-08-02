import 'date_only.dart';
import 'note_item.dart';
import 'task_dates.dart';

/// Shared rules for which calendar day a **task** belongs to.
///
/// Keeps Home «Del día», chip Tareas «Hoy», plan views and BuJo backfill aligned.
abstract final class TaskDayQuery {
  /// Explicit commitment: [todayAt] or [dueAt] on [day].
  static bool isScheduledOn(NoteItem item, DateTime day) {
    if (item.type != NoteType.task) return false;
    final key = dateOnly(day);
    if (item.todayAt != null && dateOnly(item.todayAt!) == key) return true;
    if (item.dueAt != null && dateOnly(item.dueAt!) == key) return true;
    return false;
  }

  /// Created on [day] without a date commitment to another calendar day.
  static bool isInboxCaptureOn(NoteItem item, DateTime day) {
    if (item.type != NoteType.task) return false;
    final key = dateOnly(day);
    if (dateOnly(item.createdAt) != key) return false;
    if (item.dueAt != null && dateOnly(item.dueAt!) != key) return false;
    if (item.todayAt != null && dateOnly(item.todayAt!) != key) return false;
    return true;
  }

  /// Whether a task appears in Home «Del día» for [day].
  static bool belongsToDay(NoteItem item, DateTime day, {DateTime? now}) {
    if (item.type != NoteType.task) return false;
    final key = dateOnly(day);
    final reference = now ?? DateTime.now();

    if (isInboxCaptureOn(item, day)) return true;
    if (isScheduledOn(item, day)) return true;
    if (item.completedAt != null && dateOnly(item.completedAt!) == key) {
      return true;
    }
    if (key == dateOnly(reference) && item.isOverdue(reference)) return true;
    return false;
  }

  /// Whether a task belongs in chip Tareas → «Hoy» (PRD §6.2 + inbox captures).
  static bool belongsToHoy(NoteItem item, {DateTime? now}) {
    if (item.type != NoteType.task || item.isArchived) return false;
    final reference = now ?? DateTime.now();
    final todayDay = dateOnly(reference);

    if (item.completed) {
      if (item.dueAt != null && dateOnly(item.dueAt!).isAfter(todayDay)) {
        return false;
      }
      if (item.isCompletedToday(reference)) return true;
      return item.isTodayCommitment(reference) || item.isDueToday(reference);
    }

    if (item.isTodayCommitment(reference)) return true;
    if (item.isDueToday(reference)) return true;
    if (item.isOverdue(reference)) return true;
    if (isInboxCaptureOn(item, todayDay)) return true;
    return false;
  }
}
