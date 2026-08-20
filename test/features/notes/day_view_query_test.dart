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

    test('completed backlog task shows checked when browsing today', () {
      final today = DateTime(2026, 8, 14);
      final task = NoteItem(
        id: 'feedback',
        type: NoteType.task,
        title: 'darle feedback a gaby',
        body: '',
        pinned: false,
        completed: true,
        createdAt: DateTime(2026, 7, 30),
        updatedAt: DateTime(2026, 7, 31, 18),
        completedAt: DateTime(2026, 7, 31, 18),
      );

      expect(DayViewQuery.isDisplayedCompleted(task, today), isTrue);
      expect(
        DayViewQuery.canToggleCompletionOnDay(
          item: task,
          day: today,
          now: today,
        ),
        isTrue,
      );
    });

    test('open backlog task stays unchecked when browsing today', () {
      final today = DateTime(2026, 8, 14);
      final task = NoteItem(
        id: 'open',
        type: NoteType.task,
        title: 'open backlog',
        body: '',
        pinned: false,
        completed: false,
        createdAt: DateTime(2026, 7, 30),
        updatedAt: DateTime(2026, 7, 30),
      );

      expect(DayViewQuery.isDisplayedCompleted(task, today), isFalse);
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

  group('DayViewQuery PRD §8.2 today live vs past replay', () {
    test('scheduled-away task leaves today work list but stays in past diary', () {
      final today = DateTime(2026, 8, 19, 15);
      final tomorrow = DateTime(2026, 8, 20);
      final task = NoteItem(
        id: 'wro',
        type: NoteType.task,
        title: 'Terminar WRO Learn',
        body: '',
        pinned: false,
        completed: false,
        createdAt: today,
        updatedAt: today,
        dueAt: tomorrow,
      );
      final scheduledOnToday = DayEntry(
        id: 'e-sched',
        noteId: 'wro',
        day: today,
        via: DayVia.manual,
        outcome: DayOutcome.scheduled,
        targetDay: tomorrow,
        outcomeAt: today,
        createdAt: today,
      );
      final openOnTomorrow = DayEntry(
        id: 'e-open',
        noteId: 'wro',
        day: tomorrow,
        via: DayVia.scheduledIn,
        outcome: DayOutcome.open,
        createdAt: today,
      );

      expect(
        NotesQuery.ofDayFrom(
          [task],
          today,
          now: today,
          dayEntriesByNoteId: {task.id: scheduledOnToday},
        ),
        isEmpty,
      );
      expect(
        NotesQuery.ofDayFrom(
          [task],
          tomorrow,
          now: today,
          dayEntriesByNoteId: {task.id: openOnTomorrow},
        ).map((e) => e.id),
        ['wro'],
      );

      // Looking back from a later day, the origin diary still shows the move.
      final later = DateTime(2026, 8, 21, 10);
      expect(
        NotesQuery.ofDayFrom(
          [task],
          today,
          now: later,
          dayEntriesByNoteId: {task.id: scheduledOnToday},
        ).map((e) => e.id),
        ['wro'],
      );
    });

    test('migrated-away task leaves today work list', () {
      final today = DateTime(2026, 8, 19, 15);
      final tomorrow = DateTime(2026, 8, 20);
      final task = NoteItem(
        id: 'mig',
        type: NoteType.task,
        title: 'Migrada',
        body: '',
        pinned: false,
        completed: false,
        createdAt: today,
        updatedAt: today,
        todayAt: tomorrow,
      );
      final migratedOnToday = DayEntry(
        id: 'e-mig',
        noteId: 'mig',
        day: today,
        via: DayVia.todaySwitch,
        outcome: DayOutcome.migrated,
        targetDay: tomorrow,
        outcomeAt: today,
        createdAt: today,
      );

      expect(
        DayViewQuery.taskBelongsToDay(
          task,
          today,
          now: today,
          entry: migratedOnToday,
        ),
        isFalse,
      );
    });

    test('completed today still appears on today execution list', () {
      final today = DateTime(2026, 8, 19, 18);
      final task = NoteItem(
        id: 'done',
        type: NoteType.task,
        title: 'Hecha hoy',
        body: '',
        pinned: false,
        completed: true,
        createdAt: today,
        updatedAt: today,
        dueAt: today,
        completedAt: today,
      );
      final completedEntry = DayEntry(
        id: 'e-done',
        noteId: 'done',
        day: today,
        via: DayVia.due,
        outcome: DayOutcome.completed,
        outcomeAt: today,
        createdAt: today,
      );

      expect(
        NotesQuery.ofDayFrom(
          [task],
          today,
          now: today,
          dayEntriesByNoteId: {task.id: completedEntry},
        ).map((e) => e.id),
        ['done'],
      );
    });

    test('cancelled and backlogged closed rows stay out of today', () {
      final today = DateTime(2026, 8, 19, 15);
      final cancelled = NoteItem(
        id: 'c',
        type: NoteType.task,
        title: 'Cancelada',
        body: '',
        pinned: false,
        completed: false,
        createdAt: today,
        updatedAt: today,
      );
      final backlogged = NoteItem(
        id: 'b',
        type: NoteType.task,
        title: 'Cola',
        body: '',
        pinned: false,
        completed: false,
        createdAt: today,
        updatedAt: today,
      );

      expect(
        DayViewQuery.taskBelongsToDay(
          cancelled,
          today,
          now: today,
          entry: DayEntry(
            id: 'ec',
            noteId: 'c',
            day: today,
            via: DayVia.manual,
            outcome: DayOutcome.cancelled,
            outcomeAt: today,
            createdAt: today,
          ),
        ),
        isFalse,
      );
      expect(
        DayViewQuery.taskBelongsToDay(
          backlogged,
          today,
          now: today,
          entry: DayEntry(
            id: 'eb',
            noteId: 'b',
            day: today,
            via: DayVia.manual,
            outcome: DayOutcome.backlogged,
            outcomeAt: today,
            createdAt: today,
          ),
        ),
        isFalse,
      );
    });

    test('past open day-log row stays in diary even without live schedule', () {
      final today = DateTime(2026, 8, 19, 12);
      final past = DateTime(2026, 8, 18);
      final task = NoteItem(
        id: 'orphan',
        type: NoteType.task,
        title: 'Pendiente huérfana',
        body: '',
        pinned: false,
        completed: false,
        createdAt: past,
        updatedAt: today,
        dueAt: today,
      );
      final openOnPast = DayEntry(
        id: 'e-open-past',
        noteId: 'orphan',
        day: past,
        via: DayVia.due,
        outcome: DayOutcome.open,
        createdAt: past,
      );

      expect(
        DayViewQuery.taskBelongsToDay(
          task,
          past,
          now: today,
          entry: openOnPast,
        ),
        isTrue,
      );
      expect(
        NotesQuery.ofDayFrom(
          [task],
          past,
          now: today,
          dayEntriesByNoteId: {task.id: openOnPast},
        ).map((e) => e.id),
        ['orphan'],
      );
    });

    test('cardEntryForDay hides diary-only outcomes on live days', () {
      final today = DateTime(2026, 8, 19, 12);
      final scheduled = DayEntry(
        id: 'e',
        noteId: 'n',
        day: today,
        via: DayVia.manual,
        outcome: DayOutcome.scheduled,
        targetDay: DateTime(2026, 8, 20),
        outcomeAt: today,
        createdAt: today,
      );
      expect(
        DayViewQuery.cardEntryForDay(scheduled, today, now: today),
        isNull,
      );
      expect(
        DayViewQuery.cardEntryForDay(scheduled, today, now: DateTime(2026, 8, 21)),
        scheduled,
      );
    });

    test('isReplayDay is true only for past calendar days', () {
      final now = DateTime(2026, 8, 19, 12);
      expect(DayViewQuery.isReplayDay(DateTime(2026, 8, 18), now: now), isTrue);
      expect(DayViewQuery.isReplayDay(DateTime(2026, 8, 19), now: now), isFalse);
      expect(DayViewQuery.isReplayDay(DateTime(2026, 8, 20), now: now), isFalse);
      expect(DayViewQuery.isPlanDay(DateTime(2026, 8, 20), now: now), isTrue);
      expect(DayViewQuery.isPlanDay(DateTime(2026, 8, 19), now: now), isFalse);
    });
  });

  group('DayViewQuery live vs audit rows', () {
    test('destination open entry is a live row on today', () {
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
      final openOnDay3 = DayEntry(
        id: 'e',
        noteId: 't',
        day: day3,
        via: DayVia.migratedIn,
        outcome: DayOutcome.open,
        createdAt: day3,
      );

      expect(
        DayViewQuery.isLiveDayRow(task, day3, entry: openOnDay3, now: now),
        isTrue,
      );
      expect(
        DayViewQuery.showOutcomeMetaForDayRow(
          task,
          day3,
          entry: openOnDay3,
          now: now,
        ),
        isFalse,
      );
    });

    test('past-day open commitment is muted audit row', () {
      final task = NoteItem(
        id: 't',
        type: NoteType.task,
        title: 'Pendiente de ayer',
        body: '',
        pinned: false,
        completed: false,
        createdAt: day2,
        updatedAt: now,
        dueAt: day2,
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
        DayViewQuery.isLiveDayRow(task, day2, entry: openOnDay2, now: now),
        isFalse,
      );
      expect(
        DayViewQuery.showOutcomeMetaForDayRow(
          task,
          day2,
          entry: openOnDay2,
          now: now,
        ),
        isTrue,
      );
    });

    test('migrated origin is audit row with meta', () {
      final task = migratedTask();
      final entry = migratedFromDay2();

      expect(
        DayViewQuery.isLiveDayRow(task, day2, entry: entry, now: now),
        isFalse,
      );
      expect(
        DayViewQuery.showOutcomeMetaForDayRow(
          task,
          day2,
          entry: entry,
          now: now,
        ),
        isTrue,
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
