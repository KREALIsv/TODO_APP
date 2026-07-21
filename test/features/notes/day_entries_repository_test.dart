import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/day_migration.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  late Directory tempDir;
  late DayEntriesRepository repo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('day_entries_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<Map>(
      'day_entries_test_${DateTime.now().microsecondsSinceEpoch}',
    );
    repo = DayEntriesRepository.instance;
    await repo.initWithBox(box);
    await repo.clear();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('upsert is idempotent for (noteId, day)', () async {
    final day = DateTime(2026, 7, 20, 10);
    final first = await repo.upsert(
      DayEntry(
        id: 'a',
        noteId: 'n1',
        day: day,
        via: DayVia.todaySwitch,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 20, 9),
      ),
    );
    final second = await repo.upsert(
      DayEntry(
        id: 'b',
        noteId: 'n1',
        day: DateTime(2026, 7, 20, 22),
        via: DayVia.due,
        outcome: DayOutcome.completed,
        outcomeAt: DateTime(2026, 7, 20, 12),
        createdAt: DateTime(2026, 7, 20, 11),
      ),
    );

    expect(second.id, first.id);
    expect(second.createdAt, first.createdAt);
    expect(second.outcome, DayOutcome.completed);
    expect(repo.entriesForDay(day).length, 1);
  });

  test('entriesForDay filters by dateOnly', () async {
    await repo.upsert(
      DayEntry(
        id: '1',
        noteId: 'n1',
        day: DateTime(2026, 7, 19),
        via: DayVia.manual,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 19),
      ),
    );
    await repo.upsert(
      DayEntry(
        id: '2',
        noteId: 'n2',
        day: DateTime(2026, 7, 20, 8),
        via: DayVia.manual,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 20),
      ),
    );

    final day = repo.entriesForDay(DateTime(2026, 7, 20, 18));
    expect(day.map((e) => e.noteId), ['n2']);
  });

  test('ensurePlanned does not duplicate', () async {
    final day = dateOnly(DateTime(2026, 7, 20));
    final a = await repo.ensurePlanned(
      noteId: 'n1',
      day: day,
      via: DayVia.todaySwitch,
    );
    final b = await repo.ensurePlanned(
      noteId: 'n1',
      day: day,
      via: DayVia.due,
    );
    expect(a.id, b.id);
    expect(repo.entriesForDay(day).length, 1);
  });

  test('backfillDayIfEmpty synthesizes once then reuses', () async {
    final day = DateTime(2026, 7, 18);
    final notes = [
      NoteItem(
        id: 't1',
        type: NoteType.task,
        title: 'Legacy',
        body: '',
        pinned: false,
        completed: true,
        createdAt: DateTime(2026, 7, 18),
        updatedAt: DateTime(2026, 7, 18),
        completedAt: DateTime(2026, 7, 18, 16),
      ),
    ];

    final first = await repo.backfillDayIfEmpty(day: day, notes: notes);
    expect(first.length, 1);
    expect(first.first.outcome, DayOutcome.completed);

    final second = await repo.backfillDayIfEmpty(day: day, notes: notes);
    expect(second.length, 1);
    expect(second.first.id, first.first.id);
  });

  test('applyMigrationPatches closes origin and ensures destination once',
      () async {
    final fromDay = DateTime(2026, 7, 20, 15);
    final toDay = DateTime(2026, 7, 22, 11);
    final now = DateTime(2026, 7, 20, 16);
    final patches = migrateTo(
      NoteItem(
        id: 'n1',
        type: NoteType.task,
        title: 'Task',
        body: '',
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
      ),
      fromDay,
      toDay,
      now,
    );

    await repo.applyMigrationPatches(
      noteId: 'n1',
      patches: patches,
      now: now,
    );
    await repo.applyMigrationPatches(
      noteId: 'n1',
      patches: patches,
      now: now,
    );

    final origin = repo.findForNoteDay('n1', fromDay)!;
    final destination = repo.findForNoteDay('n1', toDay)!;
    expect(origin.outcome, DayOutcome.migrated);
    expect(origin.targetDay, dateOnly(toDay));
    expect(destination.outcome, DayOutcome.open);
    expect(destination.via, DayVia.migratedIn);
    expect(repo.getAll().length, 2);
  });

  test('applyMigrationPatches handles schedule, backlog, and cancel origins',
      () async {
    final now = DateTime(2026, 7, 20, 16);
    final task = NoteItem(
      id: 'task',
      type: NoteType.task,
      title: 'Task',
      body: '',
      pinned: false,
      completed: false,
      createdAt: now,
      updatedAt: now,
    );

    await repo.applyMigrationPatches(
      noteId: 'scheduled',
      patches: scheduleTo(
        task.copyWith(id: 'scheduled'),
        DateTime(2026, 7, 20),
        DateTime(2026, 7, 23),
        now,
      ),
      now: now,
    );
    await repo.applyMigrationPatches(
      noteId: 'backlogged',
      patches: sendToBacklog(
        task.copyWith(id: 'backlogged'),
        DateTime(2026, 7, 20),
        now,
      ),
      now: now,
    );
    await repo.applyMigrationPatches(
      noteId: 'cancelled',
      patches: cancelOnDay(
        task.copyWith(id: 'cancelled'),
        DateTime(2026, 7, 20),
        now,
      ),
      now: now,
    );

    expect(
      repo.findForNoteDay('scheduled', DateTime(2026, 7, 20))!.outcome,
      DayOutcome.scheduled,
    );
    expect(
      repo.findForNoteDay('scheduled', DateTime(2026, 7, 23))!.via,
      DayVia.scheduledIn,
    );
    expect(
      repo.findForNoteDay('backlogged', DateTime(2026, 7, 20))!.outcome,
      DayOutcome.backlogged,
    );
    expect(
      repo.findForNoteDay('cancelled', DateTime(2026, 7, 20))!.outcome,
      DayOutcome.cancelled,
    );
  });
}
