import 'date_only.dart';
import 'note_item.dart';
import 'task_dates.dart';

export 'date_only.dart';

/// Monday of the week containing [value] (local calendar).
DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Active days and per-day event counts from note write activity.
/// Archived items are ignored. Completions prefer [completedAt].
({Set<DateTime> activeDays, Map<DateTime, int> eventCounts})
    activityMetricsFrom(List<NoteItem> items) {
  final activeDays = <DateTime>{};
  final eventCounts = <DateTime, int>{};

  void bump(DateTime day) {
    activeDays.add(day);
    eventCounts[day] = (eventCounts[day] ?? 0) + 1;
  }

  for (final item in items) {
    if (item.isArchived) continue;

    final createdDay = dateOnly(item.createdAt);
    bump(createdDay);

    if (item.completed && item.completedAt != null) {
      final completedDay = dateOnly(item.completedAt!);
      if (completedDay != createdDay) {
        bump(completedDay);
      }
      final updatedDay = dateOnly(item.updatedAt);
      if (updatedDay != createdDay && updatedDay != completedDay) {
        bump(updatedDay);
      }
    } else {
      final updatedDay = dateOnly(item.updatedAt);
      if (updatedDay != createdDay) {
        bump(updatedDay);
      }
    }
  }

  return (activeDays: activeDays, eventCounts: eventCounts);
}

/// Days with write activity: create or update (includes complete via updatedAt).
Set<DateTime> activeDaysFrom(List<NoteItem> items) =>
    activityMetricsFrom(items).activeDays;

/// Event counts per calendar day (create + later update counted separately).
Map<DateTime, int> dayEventCounts(List<NoteItem> items) =>
    activityMetricsFrom(items).eventCounts;

/// Active content counts for profile cards (archived/deleted excluded by caller).
({int notes, int tasks, int pendingTasks}) contentCounts(List<NoteItem> items) {
  var notes = 0;
  var tasks = 0;
  var pendingTasks = 0;
  for (final item in items) {
    if (item.type == NoteType.note) {
      notes++;
    } else {
      tasks++;
      if (!item.completed) pendingTasks++;
    }
  }
  return (notes: notes, tasks: tasks, pendingTasks: pendingTasks);
}

/// Streak ending today; if today is empty, may start from yesterday.
int currentStreak(Set<DateTime> activeDays, {DateTime? now}) {
  var cursor = dateOnly(now ?? DateTime.now());
  if (!activeDays.contains(cursor)) {
    cursor = cursor.subtract(const Duration(days: 1));
  }
  var streak = 0;
  while (activeDays.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }
  return streak;
}

/// Longest consecutive run of active days (historical).
int longestStreak(Set<DateTime> activeDays) {
  if (activeDays.isEmpty) return 0;
  final sorted = activeDays.toList()..sort();
  var best = 1;
  var run = 1;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].difference(sorted[i - 1]).inDays;
    if (gap == 1) {
      run++;
      if (run > best) best = run;
    } else if (gap > 1) {
      run = 1;
    }
  }
  return best;
}

/// Monday-first mask of active days in the week containing [now].
List<bool> weekActiveMaskFor(Set<DateTime> activeDays, {DateTime? now}) {
  final weekStart = startOfWeek(now ?? DateTime.now());
  return List<bool>.generate(
    7,
    (i) => activeDays.contains(weekStart.add(Duration(days: i))),
  );
}

/// Flattened heatmap cells: [week0day0, week0day1, …] with Monday-first weeks.
/// Oldest week first; last cell is the end of the current week (Sunday).
DateTime heatmapRangeStart({required int weeks, DateTime? now}) {
  final endOfWeek = startOfWeek(now ?? DateTime.now()).add(const Duration(days: 6));
  return endOfWeek.subtract(Duration(days: weeks * 7 - 1));
}

List<int> weekCounts({
  required Map<DateTime, int> counts,
  required int weeks,
  DateTime? now,
}) {
  final start = heatmapRangeStart(weeks: weeks, now: now);
  final totalDays = weeks * 7;

  final cells = List<int>.filled(totalDays, 0);
  for (var i = 0; i < totalDays; i++) {
    final day = start.add(Duration(days: i));
    cells[i] = counts[day] ?? 0;
  }
  return cells;
}

/// One month column for the monthly activity bars chart.
class MonthActivityBar {
  const MonthActivityBar({
    required this.year,
    required this.month,
    required this.label,
    required this.count,
  });

  final int year;
  final int month;

  /// Single-letter Spanish month label (E, F, M…).
  final String label;
  final int count;
}

const _monthLetterLabels = [
  'E',
  'F',
  'M',
  'A',
  'M',
  'J',
  'J',
  'A',
  'S',
  'O',
  'N',
  'D',
];

/// First day of the calendar month containing [value].
DateTime startOfMonth(DateTime value) {
  final day = dateOnly(value);
  return DateTime(day.year, day.month);
}

/// Event counts for the last [months] calendar months (oldest → newest).
/// Uses the same write-activity definition as the heatmap.
List<MonthActivityBar> monthlyEventBars({
  required Map<DateTime, int> eventCounts,
  DateTime? now,
  int months = 12,
}) {
  assert(months > 0);
  final reference = now ?? DateTime.now();
  final current = startOfMonth(reference);

  final totals = <DateTime, int>{};
  for (final entry in eventCounts.entries) {
    final key = startOfMonth(entry.key);
    totals[key] = (totals[key] ?? 0) + entry.value;
  }

  return List<MonthActivityBar>.generate(months, (i) {
    final offset = months - 1 - i;
    final monthStart = DateTime(current.year, current.month - offset);
    return MonthActivityBar(
      year: monthStart.year,
      month: monthStart.month,
      label: _monthLetterLabels[monthStart.month - 1],
      count: totals[monthStart] ?? 0,
    );
  });
}

class ActivityStats {
  const ActivityStats({
    required this.streak,
    required this.bestStreak,
    required this.activeDaysThisWeek,
    required this.activeDayCount,
    required this.totalEvents,
    required this.activeToday,
    required this.weekActiveMask,
    required this.cells,
    required this.weeks,
    required this.rangeStart,
  });

  final int streak;
  final int bestStreak;
  final int activeDaysThisWeek;
  final int activeDayCount;
  final int totalEvents;
  final bool activeToday;
  final List<bool> weekActiveMask;
  final List<int> cells;
  final int weeks;
  final DateTime rangeStart;

  static const int defaultWeeks = 26;

  factory ActivityStats.fromNotes(
    List<NoteItem> items, {
    DateTime? now,
    int weeks = defaultWeeks,
  }) {
    final reference = now ?? DateTime.now();
    final metrics = activityMetricsFrom(items);
    final today = dateOnly(reference);
    final mask = weekActiveMaskFor(metrics.activeDays, now: reference);
    final cells = weekCounts(
      counts: metrics.eventCounts,
      weeks: weeks,
      now: reference,
    );

    return ActivityStats(
      streak: currentStreak(metrics.activeDays, now: reference),
      bestStreak: longestStreak(metrics.activeDays),
      activeDaysThisWeek: mask.where((active) => active).length,
      activeDayCount: metrics.activeDays.length,
      totalEvents: cells.fold<int>(0, (sum, count) => sum + count),
      activeToday: metrics.activeDays.contains(today),
      weekActiveMask: mask,
      cells: cells,
      weeks: weeks,
      rangeStart: heatmapRangeStart(weeks: weeks, now: reference),
    );
  }

  static ActivityStats empty({int weeks = defaultWeeks, DateTime? now}) {
    final rangeStart = heatmapRangeStart(weeks: weeks, now: now);
    return ActivityStats(
      streak: 0,
      bestStreak: 0,
      activeDaysThisWeek: 0,
      activeDayCount: 0,
      totalEvents: 0,
      activeToday: false,
      weekActiveMask: List<bool>.filled(7, false),
      cells: List<int>.filled(weeks * 7, 0),
      weeks: weeks,
      rangeStart: rangeStart,
    );
  }
}
