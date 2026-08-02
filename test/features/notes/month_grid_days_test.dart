import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/activity_stats.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';

void main() {
  group('monthGridDays', () {
    test('July 2026 starts on Monday padding from June 29', () {
      final days = monthGridDays(DateTime(2026, 7, 1));
      expect(days.first, DateTime(2026, 6, 29));
      expect(days.last, DateTime(2026, 8, 2));
      expect(days.length % 7, 0);
    });

    test('includes every day in the visible month', () {
      final days = monthGridDays(DateTime(2026, 7, 1));
      final julyDays = days
          .where((d) => d.month == 7 && d.year == 2026)
          .map((d) => d.day)
          .toList();
      expect(julyDays, List<int>.generate(31, (i) => i + 1));
    });

    test('February 2026 grid is Monday-first', () {
      final days = monthGridDays(DateTime(2026, 2, 1));
      expect(days.first.weekday, DateTime.monday);
      expect(days.last.weekday, DateTime.sunday);
    });
  });
}
