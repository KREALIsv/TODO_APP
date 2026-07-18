import 'date_only.dart';
import 'note_item.dart';

extension TaskDateHelpers on NoteItem {
  /// "Hoy" commitment is active only if [todayAt] is the same local day.
  bool isTodayCommitment([DateTime? now]) {
    if (todayAt == null) return false;
    return dateOnly(todayAt!) == dateOnly(now ?? DateTime.now());
  }

  /// Past due date and not completed.
  bool isOverdue([DateTime? now]) {
    if (dueAt == null || completed) return false;
    return dateOnly(dueAt!).isBefore(dateOnly(now ?? DateTime.now()));
  }

  /// Due date is today (regardless of completion).
  bool isDueToday([DateTime? now]) {
    if (dueAt == null) return false;
    return dateOnly(dueAt!) == dateOnly(now ?? DateTime.now());
  }

  /// Completed on the current local day.
  bool isCompletedToday([DateTime? now]) {
    if (!completed || completedAt == null) return false;
    return dateOnly(completedAt!) == dateOnly(now ?? DateTime.now());
  }

  bool get isArchived => archivedAt != null;

  /// Clear business dates when converting task → note.
  NoteItem clearTaskDates() {
    return copyWith(
      dueAt: null,
      dueHasTime: false,
      todayAt: null,
      completedAt: null,
      completed: false,
    );
  }
}
