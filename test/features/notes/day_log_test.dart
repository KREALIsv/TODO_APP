import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_log.dart';

void main() {
  test('entriesForNote returns rows sorted by newest day first', () {
    final entries = [
      DayEntry(
        id: '1',
        noteId: 'task-1',
        day: DateTime(2026, 7, 19),
        via: DayVia.due,
        outcome: DayOutcome.scheduled,
        targetDay: DateTime(2026, 7, 22),
        outcomeAt: DateTime(2026, 7, 19, 10),
        createdAt: DateTime(2026, 7, 19, 9),
      ),
      DayEntry(
        id: '2',
        noteId: 'task-1',
        day: DateTime(2026, 7, 22),
        via: DayVia.scheduledIn,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 19, 11),
      ),
      DayEntry(
        id: '3',
        noteId: 'task-2',
        day: DateTime(2026, 7, 20),
        via: DayVia.manual,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 20),
      ),
    ];

    final rows = entriesForNote(entries, 'task-1');
    expect(rows.map((e) => e.id), ['2', '1']);
    expect(dateOnly(rows.first.day), DateTime(2026, 7, 22));
  });
}
