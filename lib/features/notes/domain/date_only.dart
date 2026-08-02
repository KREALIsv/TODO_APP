/// Date-only helper (local calendar day, time zeroed).
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

/// Timestamp for creating content on [day]: real [now] when it is today,
/// otherwise start of that calendar day.
DateTime timestampForContextDay(DateTime day, {DateTime? now}) {
  final reference = now ?? DateTime.now();
  return dateOnly(day) == dateOnly(reference) ? reference : dateOnly(day);
}

/// Task date fields when composing on a selected calendar [day].
({DateTime? todayAt, DateTime? dueAt}) taskDatesForContextDay(
  DateTime day, {
  DateTime? now,
}) {
  final reference = now ?? DateTime.now();
  final key = dateOnly(day);
  if (key == dateOnly(reference)) {
    return (todayAt: reference, dueAt: null);
  }
  return (todayAt: null, dueAt: key);
}

const List<String> _shortMonths = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// e.g. `20 Jul`
String formatDayMonth(DateTime date) =>
    '${date.day} ${_shortMonths[date.month - 1]}';

/// e.g. `Jul 20, 2026` (home header style).
String formatHeaderDate(DateTime date) =>
    '${_shortMonths[date.month - 1]} ${date.day}, ${date.year}';

/// e.g. `20 Jul 2026`
String formatDayMonthYear(DateTime date) =>
    '${date.day} ${_shortMonths[date.month - 1]} ${date.year}';
