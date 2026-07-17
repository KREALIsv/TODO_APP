import 'note_item.dart';

/// Date-only helper (local calendar day, time zeroed).
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Monday of the week containing [value] (local calendar).
DateTime startOfWeek(DateTime value) {
  final day = dateOnly(value);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

/// Active days and per-day event counts from note write activity.
({Set<DateTime> activeDays, Map<DateTime, int> eventCounts})
    activityMetricsFrom(List<NoteItem> items) {
  final activeDays = <DateTime>{};
  final eventCounts = <DateTime, int>{};

  for (final item in items) {
    final createdDay = dateOnly(item.createdAt);
    final updatedDay = dateOnly(item.updatedAt);

    activeDays.add(createdDay);
    activeDays.add(updatedDay);

    eventCounts[createdDay] = (eventCounts[createdDay] ?? 0) + 1;
    if (updatedDay != createdDay) {
      eventCounts[updatedDay] = (eventCounts[updatedDay] ?? 0) + 1;
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
