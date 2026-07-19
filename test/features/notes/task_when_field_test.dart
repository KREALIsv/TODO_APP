import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/presentation/widgets/task_when_field.dart';

void main() {
  group('TaskWhenField.kindOf', () {
    final now = DateTime(2026, 7, 19, 10);

    test('today commitment wins', () {
      expect(
        TaskWhenField.kindOf(
          todayOn: true,
          dueAt: DateTime(2026, 7, 19),
          now: now,
        ),
        TaskWhenKind.today,
      );
    });

    test('tomorrow without time', () {
      expect(
        TaskWhenField.kindOf(
          todayOn: false,
          dueAt: DateTime(2026, 7, 20),
          now: now,
        ),
        TaskWhenKind.tomorrow,
      );
    });

    test('due today is Fecha, not Hoy', () {
      expect(
        TaskWhenField.kindOf(
          todayOn: false,
          dueAt: DateTime(2026, 7, 19),
          now: now,
        ),
        TaskWhenKind.date,
      );
    });

    test('someday when no due', () {
      expect(
        TaskWhenField.kindOf(todayOn: false, dueAt: null, now: now),
        TaskWhenKind.someday,
      );
    });
  });

  group('TaskWhenField.formatDueLabel', () {
    test('same shape for calendar today as any other day', () {
      final label = TaskWhenField.formatDueLabel(DateTime(2026, 7, 19));
      expect(label, '19 jul');
      expect(label.toLowerCase().contains('hoy'), isFalse);
    });

    test('includes time with comma separator', () {
      expect(
        TaskWhenField.formatDueLabel(
          DateTime(2026, 7, 19, 9, 0),
          hasTime: true,
        ),
        '19 jul, 9:00 AM',
      );
    });
  });

  group('TaskWhenField.isOverdueDue', () {
    test('all-day due yesterday is overdue', () {
      expect(
        TaskWhenField.isOverdueDue(
          dueAt: DateTime(2026, 7, 18),
          dueHasTime: false,
          now: DateTime(2026, 7, 19, 10),
        ),
        isTrue,
      );
    });

    test('all-day due today is not overdue', () {
      expect(
        TaskWhenField.isOverdueDue(
          dueAt: DateTime(2026, 7, 19),
          dueHasTime: false,
          now: DateTime(2026, 7, 19, 10),
        ),
        isFalse,
      );
    });
  });
}
