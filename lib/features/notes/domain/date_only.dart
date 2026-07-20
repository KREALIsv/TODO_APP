/// Date-only helper (local calendar day, time zeroed).
DateTime dateOnly(DateTime value) =>
    DateTime(value.year, value.month, value.day);

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
