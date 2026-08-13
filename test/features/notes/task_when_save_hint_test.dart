import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/task_when_save_hint.dart';

void main() {
  final now = DateTime(2026, 7, 31, 12);

  NoteItem task({DateTime? dueAt, DateTime? todayAt}) {
    return NoteItem(
      id: 't1',
      type: NoteType.task,
      title: 'Demo',
      body: '',
      pinned: false,
      completed: false,
      createdAt: DateTime(2026, 7, 1),
      updatedAt: DateTime(2026, 7, 1),
      dueAt: dueAt,
      todayAt: todayAt,
    );
  }

  test('returns null when when-fields unchanged', () {
    final item = task(dueAt: DateTime(2026, 8, 2));
    expect(
      taskWhenSaveHint(
        previous: item,
        nextTodayOn: false,
        nextDueAt: DateTime(2026, 8, 2),
        now: now,
      ),
      isNull,
    );
  });

  test('hints reschedule from one due day to another', () {
    final hint = taskWhenSaveHint(
      previous: task(dueAt: DateTime(2026, 7, 28)),
      nextTodayOn: false,
      nextDueAt: DateTime(2026, 7, 31),
      now: now,
    );
    expect(hint, 'Al guardar: Del 28 Jul al 31 Jul.');
  });

  test('instant hint uses shorter copy without save prefix', () {
    final hint = taskWhenChangeHint(
      previous: task(dueAt: DateTime(2026, 8, 3)),
      nextTodayOn: false,
      nextDueAt: DateTime(2026, 8, 19),
      now: now,
    );
    expect(hint, 'Del 3 Aug al 19 Aug.');
  });

  test('hints removing day commitment when clearing date', () {
    final hint = taskWhenSaveHint(
      previous: task(dueAt: DateTime(2026, 7, 30)),
      nextTodayOn: false,
      nextDueAt: null,
      now: now,
    );
    expect(hint, contains('Se quita del día'));
  });

  test('dayOutcomeShortLabel covers BuJo states without icons', () {
    final migrated = DayEntry(
      id: '1',
      noteId: 't1',
      day: DateTime(2026, 7, 28),
      via: DayVia.due,
      outcome: DayOutcome.migrated,
      targetDay: DateTime(2026, 7, 31),
      outcomeAt: now,
      createdAt: now,
    );
    expect(dayOutcomeShortLabel(migrated), 'Migrada → 31 Jul');
  });
}
