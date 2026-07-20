import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_log.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  final now = DateTime(2026, 7, 20, 14, 30);

  DayEntry buildEntry({
    String id = 'e1',
    String noteId = 'n1',
    DateTime? day,
    DayVia via = DayVia.todaySwitch,
    DayOutcome outcome = DayOutcome.open,
    DateTime? targetDay,
    DateTime? outcomeAt,
  }) {
    return DayEntry(
      id: id,
      noteId: noteId,
      day: day ?? DateTime(2026, 7, 20),
      via: via,
      outcome: outcome,
      targetDay: targetDay,
      outcomeAt: outcomeAt,
      createdAt: now,
    );
  }

  test('toMap/fromMap roundtrip preserves enums and null targetDay', () {
    final original = buildEntry();
    final restored = DayEntry.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.noteId, original.noteId);
    expect(restored.day, dateOnly(original.day));
    expect(restored.via, DayVia.todaySwitch);
    expect(restored.outcome, DayOutcome.open);
    expect(restored.targetDay, isNull);
    expect(restored.outcomeAt, isNull);
    expect(restored.createdAt, original.createdAt);
  });

  test('toMap/fromMap roundtrip with targetDay and outcomeAt', () {
    final original = buildEntry(
      via: DayVia.migratedIn,
      outcome: DayOutcome.migrated,
      targetDay: DateTime(2026, 7, 21, 9),
      outcomeAt: now,
    );
    final restored = DayEntry.fromMap(original.toMap());

    expect(restored.via, DayVia.migratedIn);
    expect(restored.outcome, DayOutcome.migrated);
    expect(restored.targetDay, DateTime(2026, 7, 21));
    expect(restored.outcomeAt, now);
  });

  test('copyWith can clear nullable fields', () {
    final entry = buildEntry(
      targetDay: DateTime(2026, 7, 22),
      outcomeAt: now,
      outcome: DayOutcome.scheduled,
    );
    final cleared = entry.copyWith(targetDay: null, outcomeAt: null);
    expect(cleared.targetDay, isNull);
    expect(cleared.outcomeAt, isNull);
  });

  test('entriesForDay filters by dateOnly ignoring time', () {
    final all = [
      buildEntry(id: 'a', day: DateTime(2026, 7, 19, 8)),
      buildEntry(id: 'b', day: DateTime(2026, 7, 20, 23)),
      buildEntry(id: 'c', day: DateTime(2026, 7, 20, 1)),
    ];
    final day = entriesForDay(all, DateTime(2026, 7, 20, 15));
    expect(day.map((e) => e.id), ['b', 'c']);
  });

  test('synthesizeEntriesFromNotes builds completed and open from NoteItem', () {
    final day = DateTime(2026, 7, 19);
    final notes = [
      NoteItem(
        id: 'done',
        type: NoteType.task,
        title: 'Done',
        body: '',
        pinned: false,
        completed: true,
        createdAt: now,
        updatedAt: now,
        completedAt: DateTime(2026, 7, 19, 10),
      ),
      NoteItem(
        id: 'today',
        type: NoteType.task,
        title: 'Today',
        body: '',
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
        todayAt: DateTime(2026, 7, 19, 8),
      ),
      NoteItem(
        id: 'other',
        type: NoteType.task,
        title: 'Other',
        body: '',
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
        dueAt: DateTime(2026, 7, 21),
      ),
    ];

    var i = 0;
    final synthesized = synthesizeEntriesFromNotes(
      notes: notes,
      day: day,
      newId: () => 'id-${i++}',
      now: now,
    );

    expect(synthesized.length, 2);
    expect(
      synthesized.map((e) => e.noteId).toSet(),
      {'done', 'today'},
    );
    expect(
      synthesized.firstWhere((e) => e.noteId == 'done').outcome,
      DayOutcome.completed,
    );
    expect(
      synthesized.firstWhere((e) => e.noteId == 'today').outcome,
      DayOutcome.open,
    );
  });
}
