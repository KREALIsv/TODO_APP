import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_migration.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  final now = DateTime(2026, 7, 20, 14, 30);

  NoteItem task({
    DateTime? dueAt,
    DateTime? todayAt,
    int? reminderMinutesBefore,
  }) {
    return NoteItem(
      id: 'task-1',
      type: NoteType.task,
      title: 'Task',
      body: '',
      pinned: false,
      completed: false,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      dueAt: dueAt,
      todayAt: todayAt,
      reminderMinutesBefore: reminderMinutesBefore,
    );
  }

  test('migrate is idempotent with date-only entry patches', () {
    final first = migrateTo(
      task(todayAt: DateTime(2026, 7, 19, 8)),
      DateTime(2026, 7, 19, 22),
      DateTime(2026, 7, 22, 18),
      now,
    );
    final patches = migrateTo(
      first.noteUpdate,
      DateTime(2026, 7, 19),
      DateTime(2026, 7, 22, 9),
      now,
    );

    expect(patches.originUpdate.day, DateTime(2026, 7, 19));
    expect(patches.originUpdate.outcome, DayOutcome.migrated);
    expect(patches.originUpdate.targetDay, DateTime(2026, 7, 22));
    expect(patches.destinationEnsure!.day, DateTime(2026, 7, 22));
    expect(patches.destinationEnsure!.via, DayVia.migratedIn);
    expect(patches.noteUpdate.todayAt, isNull);
    expect(patches.noteUpdate.dueAt, DateTime(2026, 7, 22));
    expect(patches.noteUpdate.dueHasTime, isFalse);
    expect(patches.noteUpdate.dueAt, first.noteUpdate.dueAt);
  });

  test('migrate to today uses a Hoy commitment', () {
    final patches = migrateTo(
      task(dueAt: DateTime(2026, 7, 19)),
      DateTime(2026, 7, 19),
      DateTime(2026, 7, 20, 23),
      now,
    );

    expect(patches.noteUpdate.todayAt, now);
    expect(patches.noteUpdate.dueAt, isNull);
  });

  test('schedule is idempotent and uses date-only all-day due date', () {
    final original = task(todayAt: DateTime(2026, 7, 19, 8));
    final first = scheduleTo(
      original,
      DateTime(2026, 7, 19, 12),
      DateTime(2026, 7, 23, 9),
      now,
    );
    final second = scheduleTo(
      first.noteUpdate,
      DateTime(2026, 7, 19),
      DateTime(2026, 7, 23, 17),
      now,
    );

    expect(first.originUpdate.outcome, DayOutcome.scheduled);
    expect(first.destinationEnsure!.via, DayVia.scheduledIn);
    expect(first.noteUpdate.dueAt, DateTime(2026, 7, 23));
    expect(first.noteUpdate.todayAt, isNull);
    expect(second.noteUpdate.dueAt, first.noteUpdate.dueAt);
    expect(second.originUpdate.targetDay, first.originUpdate.targetDay);
  });

  test('backlog is idempotent and clears commitment and reminder', () {
    final original = task(
      dueAt: DateTime(2026, 7, 20, 9),
      todayAt: DateTime(2026, 7, 20, 8),
      reminderMinutesBefore: 15,
    );
    final first = sendToBacklog(original, DateTime(2026, 7, 20, 18), now);
    final second = sendToBacklog(first.noteUpdate, DateTime(2026, 7, 20), now);

    expect(first.originUpdate.outcome, DayOutcome.backlogged);
    expect(first.destinationEnsure, isNull);
    expect(first.noteUpdate.todayAt, isNull);
    expect(first.noteUpdate.dueAt, isNull);
    expect(first.noteUpdate.reminderMinutesBefore, isNull);
    expect(second.noteUpdate.dueAt, isNull);
    expect(second.noteUpdate.todayAt, isNull);
  });

  test('cancel is idempotent and clears only its day commitment', () {
    final first = cancelOnDay(
      task(
        dueAt: DateTime(2026, 7, 20, 9),
        todayAt: DateTime(2026, 7, 21, 8),
      ),
      DateTime(2026, 7, 20, 16),
      now,
    );
    final patches = cancelOnDay(first.noteUpdate, DateTime(2026, 7, 20), now);

    expect(patches.originUpdate.outcome, DayOutcome.cancelled);
    expect(patches.noteUpdate.dueAt, isNull);
    expect(patches.noteUpdate.todayAt, DateTime(2026, 7, 21, 8));
    expect(dateOnly(patches.originUpdate.day), patches.originUpdate.day);
  });
}
