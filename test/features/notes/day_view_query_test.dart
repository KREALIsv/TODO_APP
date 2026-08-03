import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_view_query.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/notes_query.dart';

void main() {
  final day2 = DateTime(2026, 8, 2);
  final day3 = DateTime(2026, 8, 3);
  final now = DateTime(2026, 8, 3, 18);

  NoteItem migratedTask() {
    return NoteItem(
      id: 'fix-cards',
      type: NoteType.task,
      title: 'Fix: Flujo tarjetas',
      body: '',
      pinned: false,
      completed: true,
      createdAt: day2,
      updatedAt: now,
      dueAt: day3,
      completedAt: now,
    );
  }

  DayEntry migratedFromDay2() {
    return DayEntry(
      id: 'e1',
      noteId: 'fix-cards',
      day: day2,
      via: DayVia.manual,
      outcome: DayOutcome.migrated,
      targetDay: day3,
      outcomeAt: DateTime(2026, 8, 3, 10),
      createdAt: DateTime(2026, 8, 3, 10),
    );
  }

  DayEntry completedOnDay3() {
    return DayEntry(
      id: 'e2',
      noteId: 'fix-cards',
      day: day3,
      via: DayVia.migratedIn,
      outcome: DayOutcome.completed,
      outcomeAt: now,
      createdAt: now,
    );
  }

  group('DayViewQuery audit display', () {
    test('migrated origin day shows as pending even when globally completed', () {
      final task = migratedTask();
      final entry = migratedFromDay2();

      expect(
        DayViewQuery.isDisplayedCompleted(task, day2, entry: entry),
        isFalse,
      );
      expect(
        DayViewQuery.canToggleCompletionOnDay(
          item: task,
          day: day2,
          entry: entry,
          now: now,
        ),
        isFalse,
      );
    });

    test('destination day shows completed from its day entry', () {
      final task = migratedTask();
      final entry = completedOnDay3();

      expect(
        DayViewQuery.isDisplayedCompleted(task, day3, entry: entry),
        isTrue,
      );
    });

    test('task without schedule still appears on origin day via day entry', () {
      final task = migratedTask();
      final entries = {task.id: migratedFromDay2()};

      expect(
        NotesQuery.ofDayFrom(
          [task],
          day2,
          now: now,
          dayEntriesByNoteId: entries,
        ).map((e) => e.id),
        ['fix-cards'],
      );
      expect(
        NotesQuery.ofDayFrom(
          [task],
          day2,
          now: now,
        ),
        isEmpty,
      );
    });
  });

  group('DayViewQuery remove from day', () {
    test('can remove from viewed day even when dueAt is elsewhere', () {
      final task = NoteItem(
        id: 't',
        type: NoteType.task,
        title: 't',
        body: '',
        pinned: false,
        completed: false,
        createdAt: day2,
        updatedAt: now,
        dueAt: day3,
      );
      final openOnDay2 = DayEntry(
        id: 'e',
        noteId: 't',
        day: day2,
        via: DayVia.manual,
        outcome: DayOutcome.open,
        createdAt: day2,
      );

      expect(
        DayViewQuery.canRemoveFromDay(task, day2, entry: openOnDay2),
        isTrue,
      );
      expect(
        DayViewQuery.removeFromDayCandidates(
          item: task,
          entries: [openOnDay2],
        ),
        containsAll([day2, day3]),
      );
    });
  });
}
