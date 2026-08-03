import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_log.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  group('commitmentDayFor', () {
    final now = DateTime(2026, 8, 3, 15);
    final yesterday = DateTime(2026, 8, 2);

    NoteItem task({DateTime? todayAt, DateTime? dueAt}) {
      return NoteItem(
        id: 't',
        type: NoteType.task,
        title: 't',
        body: '',
        pinned: false,
        completed: false,
        createdAt: yesterday,
        updatedAt: now,
        todayAt: todayAt,
        dueAt: dueAt,
      );
    }

    test('uses stale todayAt instead of today', () {
      expect(
        commitmentDayFor(task(todayAt: yesterday), now),
        dateOnly(yesterday),
      );
    });

    test('prefers explicit onDay', () {
      expect(
        commitmentDayFor(task(dueAt: yesterday), now, onDay: yesterday),
        dateOnly(yesterday),
      );
    });
  });

  group('completionOutcomeAt', () {
    test('anchors past days to end of local day', () {
      final day = DateTime(2026, 8, 2);
      final now = DateTime(2026, 8, 3, 10);
      expect(
        completionOutcomeAt(day, now),
        DateTime(2026, 8, 2, 23, 59, 59),
      );
    });

    test('keeps clock time when completing today', () {
      final now = DateTime(2026, 8, 3, 10, 30);
      expect(completionOutcomeAt(now, now), now);
    });
  });

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
