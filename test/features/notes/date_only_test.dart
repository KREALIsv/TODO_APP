import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';

void main() {
  final today = DateTime(2026, 8, 2, 15, 30);
  final tomorrow = DateTime(2026, 8, 3);
  final yesterday = DateTime(2026, 8, 1);

  group('timestampForContextDay', () {
    test('returns now when day is today', () {
      expect(
        timestampForContextDay(today, now: today),
        today,
      );
    });

    test('returns start of day for other calendar days', () {
      expect(
        timestampForContextDay(tomorrow, now: today),
        DateTime(2026, 8, 3),
      );
      expect(
        timestampForContextDay(yesterday, now: today),
        DateTime(2026, 8, 1),
      );
    });
  });

  group('taskDatesForContextDay', () {
    test('uses todayAt when composing for today', () {
      final dates = taskDatesForContextDay(today, now: today);
      expect(dates.todayAt, today);
      expect(dates.dueAt, isNull);
    });

    test('uses dueAt when composing for another day', () {
      final dates = taskDatesForContextDay(tomorrow, now: today);
      expect(dates.todayAt, isNull);
      expect(dates.dueAt, DateTime(2026, 8, 3));
    });
  });
}
