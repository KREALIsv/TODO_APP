import 'date_only.dart';
import 'note_item.dart';
import 'task_dates.dart';

class TodayProgress {
  const TodayProgress({required this.done, required this.total});

  final int done;
  final int total;

  bool get hideIfZero => total == 0;

  bool get isComplete => total > 0 && done == total;
}

class TaskGroups {
  const TaskGroups({
    required this.today,
    required this.upcoming,
    required this.undated,
    required this.completedEarlier,
    required this.progress,
  });

  final List<NoteItem> today;
  final List<NoteItem> upcoming;
  final List<NoteItem> undated;
  final List<NoteItem> completedEarlier;
  final TodayProgress progress;

  bool get isEmpty =>
      today.isEmpty &&
      upcoming.isEmpty &&
      undated.isEmpty &&
      completedEarlier.isEmpty;
}

class TaskGroupsQuery {
  const TaskGroupsQuery._();

  static TodayProgress progressFor(List<NoteItem> todayGroup) {
    final total = todayGroup.length;
    final done = todayGroup.where((t) => t.completed).length;
    return TodayProgress(done: done, total: total);
  }

  /// Groups active tasks (caller should pass non-archived tasks only).
  static TaskGroups from(List<NoteItem> tasks, {DateTime? now}) {
    final reference = now ?? DateTime.now();
    final todayDay = dateOnly(reference);

    final today = <NoteItem>[];
    final upcoming = <NoteItem>[];
    final undated = <NoteItem>[];
    final completedEarlier = <NoteItem>[];

    for (final item in tasks) {
      if (item.type != NoteType.task || item.isArchived) continue;

      if (_belongsToToday(item, todayDay, reference)) {
        today.add(item);
        continue;
      }

      if (item.completed) {
        // Completed earlier than today (or without completedAt) → Completadas.
        completedEarlier.add(item);
        continue;
      }

      if (item.dueAt != null && dateOnly(item.dueAt!).isAfter(todayDay)) {
        upcoming.add(item);
      } else if (item.dueAt == null && !item.isTodayCommitment(reference)) {
        undated.add(item);
      }
    }

    today.sort((a, b) => _compareToday(a, b, todayDay, reference));
    upcoming.sort((a, b) => a.dueAt!.compareTo(b.dueAt!));
    undated.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    completedEarlier.sort((a, b) {
      final aAt = a.completedAt ?? a.updatedAt;
      final bAt = b.completedAt ?? b.updatedAt;
      return bAt.compareTo(aAt);
    });

    return TaskGroups(
      today: today,
      upcoming: upcoming,
      undated: undated,
      completedEarlier: completedEarlier,
      progress: progressFor(today),
    );
  }

  /// Whether [item] belongs in the Hoy group (PRD §6.2).
  static bool belongsToToday(NoteItem item, {DateTime? now}) {
    if (item.type != NoteType.task || item.isArchived) return false;
    final reference = now ?? DateTime.now();
    return _belongsToToday(item, dateOnly(reference), reference);
  }

  /// PRD §6.2: switch today OR due today OR overdue incomplete;
  /// completed today stay (due today / switch); overdue completed leave.
  static bool _belongsToToday(
    NoteItem item,
    DateTime todayDay,
    DateTime now,
  ) {
    final commitment = item.isTodayCommitment(now);
    final dueToday = item.isDueToday(now);

    if (item.completed) {
      if (!item.isCompletedToday(now)) return false;
      // Vencidas completadas salen de Hoy.
      if (item.dueAt != null && dateOnly(item.dueAt!).isBefore(todayDay)) {
        return false;
      }
      return commitment || dueToday;
    }

    return commitment || dueToday || item.isOverdue(now);
  }

  /// Order: overdue asc → due today with time asc → due today no time →
  /// switch-only → completed today last.
  static int _compareToday(
    NoteItem a,
    NoteItem b,
    DateTime todayDay,
    DateTime now,
  ) {
    final aCompleted = a.completed && a.isCompletedToday(now);
    final bCompleted = b.completed && b.isCompletedToday(now);
    if (aCompleted != bCompleted) {
      return aCompleted ? 1 : -1;
    }

    final aRank = _todayRank(a, todayDay, now);
    final bRank = _todayRank(b, todayDay, now);
    if (aRank != bRank) return aRank.compareTo(bRank);

    if (aRank == 0) {
      // Overdue: oldest due first.
      return a.dueAt!.compareTo(b.dueAt!);
    }
    if (aRank == 1) {
      return a.dueAt!.compareTo(b.dueAt!);
    }
    if (aRank == 3) {
      return (a.todayAt ?? a.updatedAt).compareTo(b.todayAt ?? b.updatedAt);
    }
    return a.updatedAt.compareTo(b.updatedAt);
  }

  static int _todayRank(NoteItem item, DateTime todayDay, DateTime now) {
    if (item.isOverdue(now) ||
        (item.completed &&
            item.dueAt != null &&
            dateOnly(item.dueAt!).isBefore(todayDay))) {
      return 0;
    }
    if (item.isDueToday(now) && item.dueHasTime) return 1;
    if (item.isDueToday(now)) return 2;
    if (item.isTodayCommitment(now)) return 3;
    return 4;
  }
}
