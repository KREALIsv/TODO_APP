import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/notes/data/task_reminders_service.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  late Directory tempDir;
  late NotesRepository repo;
  late DayEntriesRepository dayEntries;
  late AttachmentsRepository attachments;

  setUp(() async {
    TaskRemindersService.enabled = false;
    tempDir = await Directory.systemTemp.createTemp('notes_repo_test_');
    Hive.init(tempDir.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final box = await Hive.openBox<Map>('notes_test_$stamp');
    final dayBox = await Hive.openBox<Map>('day_entries_test_$stamp');
    repo = NotesRepository.instance;
    dayEntries = DayEntriesRepository.instance;
    attachments = AttachmentsRepository.instance;
    await repo.initWithBox(box);
    await dayEntries.initWithBox(dayBox);
    await attachments.initWithBoxes(
      meta: await Hive.openBox<Map>('att_meta_$stamp'),
      blobs: await Hive.openBox<dynamic>('att_blob_$stamp'),
    );
    repo.dayEntriesForTests = dayEntries;
    repo.attachmentsForTests = attachments;
    await repo.clear();
    await dayEntries.clear();
    await attachments.clear();
  });

  tearDownAll(() {
    TaskRemindersService.enabled = true;
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  NoteItem buildItem({
    String id = '1',
    NoteType type = NoteType.note,
    bool pinned = false,
    bool completed = false,
    DateTime? updatedAt,
    List<String> tags = const [],
  }) {
    final now = DateTime(2026, 7, 16, 12);
    return NoteItem(
      id: id,
      type: type,
      title: 'Title $id',
      body: 'Body $id',
      pinned: pinned,
      completed: completed,
      createdAt: now,
      updatedAt: updatedAt ?? now,
      tags: tags,
    );
  }

  test('add and getAll returns items sorted by updatedAt desc', () async {
    await repo.add(buildItem(id: 'old', updatedAt: DateTime(2026, 7, 1)));
    await repo.add(buildItem(id: 'new', updatedAt: DateTime(2026, 7, 15)));

    final all = repo.getAll();
    expect(all.map((e) => e.id).toList(), ['new', 'old']);
  });

  test('update replaces existing item', () async {
    await repo.add(buildItem(id: '1'));
    await repo.update(buildItem(id: '1').copyWith(title: 'Updated'));

    expect(repo.getById('1')?.title, 'Updated');
  });

  test('delete removes item', () async {
    await repo.add(buildItem(id: '1'));
    await repo.delete('1');
    expect(repo.getById('1'), isNull);
    expect(repo.getAll(), isEmpty);
  });

  test('togglePinned flips pinned flag', () async {
    await repo.add(buildItem(id: '1', pinned: false));
    await repo.togglePinned('1');
    expect(repo.getById('1')?.pinned, isTrue);
    await repo.togglePinned('1');
    expect(repo.getById('1')?.pinned, isFalse);
  });

  test('toggleCompleted only works for tasks and sets completedAt', () async {
    await repo.add(buildItem(id: 'note', type: NoteType.note));
    await repo.add(buildItem(id: 'task', type: NoteType.task));

    await repo.toggleCompleted('note');
    await repo.toggleCompleted('task');

    expect(repo.getById('note')?.completed, isFalse);
    expect(repo.getById('task')?.completed, isTrue);
    expect(repo.getById('task')?.completedAt, isNotNull);

    await repo.toggleCompleted('task');
    expect(repo.getById('task')?.completed, isFalse);
    expect(repo.getById('task')?.completedAt, isNull);
  });

  test('archive hides from getAll and restore brings back', () async {
    await repo.add(buildItem(id: '1'));
    await repo.archive('1');
    expect(repo.getAll(), isEmpty);
    expect(repo.getArchived().map((e) => e.id), ['1']);
    expect(repo.getById('1')?.archivedAt, isNotNull);

    await repo.restore('1');
    expect(repo.getAll().map((e) => e.id), ['1']);
    expect(repo.getArchived(), isEmpty);
  });

  test('add with todayAt creates an open DayEntry', () async {
    final now = DateTime.now();
    await repo.add(
      buildItem(id: 'task', type: NoteType.task).copyWith(todayAt: now),
    );

    final entry = dayEntries.findForNoteDay('task', dateOnly(now));
    expect(entry, isNotNull);
    expect(entry!.outcome, DayOutcome.open);
    expect(entry.via, DayVia.todaySwitch);
  });

  test('setTodayCommitment toggles todayAt and clears due when on', () async {
    await repo.add(
      buildItem(id: 't', type: NoteType.task).copyWith(
        dueAt: DateTime(2026, 7, 20),
        dueHasTime: true,
        reminderMinutesBefore: 30,
      ),
    );
    await repo.setTodayCommitment('t', true);
    final on = repo.getById('t')!;
    expect(on.todayAt, isNotNull);
    expect(on.dueAt, isNull);
    expect(on.dueHasTime, isFalse);
    expect(on.reminderMinutesBefore, isNull);

    final entry = dayEntries.findForNoteDay('t', dateOnly(DateTime.now()));
    expect(entry, isNotNull);
    expect(entry!.outcome, DayOutcome.open);
    expect(entry.via, DayVia.todaySwitch);

    await repo.setTodayCommitment('t', false);
    expect(repo.getById('t')?.todayAt, isNull);
    final closed = dayEntries.findForNoteDay('t', dateOnly(on.todayAt!));
    expect(closed?.outcome, DayOutcome.backlogged);
  });

  test('applyTaskWhen matches exclusive Hoy / Mañana semantics', () async {
    await repo.add(buildItem(id: 't', type: NoteType.task));

    await repo.applyTaskWhen('t', todayOn: true, dueAt: null);
    expect(repo.getById('t')?.todayAt, isNotNull);
    expect(repo.getById('t')?.dueAt, isNull);
    expect(
      dayEntries.findForNoteDay('t', dateOnly(DateTime.now()))?.via,
      DayVia.todaySwitch,
    );

    final tomorrow = dateOnly(DateTime.now()).add(const Duration(days: 1));
    await repo.applyTaskWhen(
      't',
      todayOn: false,
      dueAt: tomorrow,
      dueHasTime: false,
    );
    final after = repo.getById('t')!;
    expect(after.todayAt, isNull);
    expect(after.dueAt, tomorrow);
    expect(
      dayEntries.findForNoteDay('t', tomorrow)?.via,
      DayVia.due,
    );
    expect(
      dayEntries.findForNoteDay('t', tomorrow)?.outcome,
      DayOutcome.open,
    );
  });

  test('toggleCompleted marks DayEntry completed and reopen restores open',
      () async {
    await repo.add(buildItem(id: 'task', type: NoteType.task));
    await repo.setTodayCommitment('task', true);
    await repo.toggleCompleted('task');

    final day = dateOnly(DateTime.now());
    final done = dayEntries.findForNoteDay('task', day);
    expect(done?.outcome, DayOutcome.completed);
    expect(done?.outcomeAt, isNotNull);
    expect(repo.getById('task')?.completedAt, isNotNull);

    await repo.toggleCompleted('task');
    expect(dayEntries.findForNoteDay('task', day)?.outcome, DayOutcome.open);
    expect(repo.getById('task')?.completedAt, isNull);
  });

  test('migrateTaskToDay creates an open destination and closes origin',
      () async {
    final origin = dateOnly(DateTime.now());
    final destination = dateOnly(DateTime.now().add(const Duration(days: 2)));
    await repo.add(
      buildItem(
        id: 'task',
        type: NoteType.task,
      ).copyWith(todayAt: DateTime.now()),
    );

    await repo.migrateTaskToDay('task', destination, fromDay: origin);

    final task = repo.getById('task')!;
    expect(task.todayAt, isNull);
    expect(task.dueAt, destination);
    expect(task.dueHasTime, isFalse);
    expect(task.reminderMinutesBefore, isNull);
    final closed = dayEntries.findForNoteDay('task', origin)!;
    expect(closed.outcome, DayOutcome.migrated);
    expect(closed.targetDay, destination);
    final opened = dayEntries.findForNoteDay('task', destination)!;
    expect(opened.outcome, DayOutcome.open);
    expect(opened.via, DayVia.migratedIn);
  });

  test('scheduleTaskToDay sets dueAt and creates a scheduled destination',
      () async {
    final origin = dateOnly(DateTime.now());
    final destination = dateOnly(DateTime.now().add(const Duration(days: 3)));
    await repo.add(
      buildItem(
        id: 'task',
        type: NoteType.task,
      ).copyWith(todayAt: DateTime.now()),
    );

    await repo.scheduleTaskToDay('task', destination, fromDay: origin);

    final task = repo.getById('task')!;
    expect(task.todayAt, isNull);
    expect(task.dueAt, destination);
    final closed = dayEntries.findForNoteDay('task', origin)!;
    expect(closed.outcome, DayOutcome.scheduled);
    expect(closed.targetDay, destination);
    final opened = dayEntries.findForNoteDay('task', destination)!;
    expect(opened.outcome, DayOutcome.open);
    expect(opened.via, DayVia.scheduledIn);
  });

  test('sendTaskToBacklog clears dates and marks origin backlogged', () async {
    final origin = dateOnly(DateTime.now().add(const Duration(days: 1)));
    await repo.add(
      buildItem(id: 'task', type: NoteType.task).copyWith(
        dueAt: origin,
        dueHasTime: true,
        reminderMinutesBefore: 30,
      ),
    );

    await repo.sendTaskToBacklog('task', fromDay: origin);

    final task = repo.getById('task')!;
    expect(task.todayAt, isNull);
    expect(task.dueAt, isNull);
    expect(task.dueHasTime, isFalse);
    expect(task.reminderMinutesBefore, isNull);
    expect(
      dayEntries.findForNoteDay('task', origin)?.outcome,
      DayOutcome.backlogged,
    );
  });

  test('cancelTaskOnDay clears that commitment and marks origin cancelled',
      () async {
    final origin = dateOnly(DateTime.now().add(const Duration(days: 1)));
    await repo.add(
      buildItem(id: 'task', type: NoteType.task).copyWith(
        dueAt: origin,
        reminderMinutesBefore: 15,
      ),
    );

    await repo.cancelTaskOnDay('task', fromDay: origin);

    final task = repo.getById('task')!;
    expect(task.dueAt, isNull);
    expect(repo.getById('task'), isNotNull);
    expect(
      dayEntries.findForNoteDay('task', origin)?.outcome,
      DayOutcome.cancelled,
    );
  });

  test('duplicate copies content and resets pin/completed/archive', () async {
    await repo.add(
      buildItem(id: 'src', type: NoteType.task, pinned: true, completed: true)
          .copyWith(
        tags: const ['Work'],
        dueAt: DateTime(2026, 7, 22),
        completedAt: DateTime(2026, 7, 16),
        archivedAt: DateTime(2026, 7, 16),
      ),
    );

    final copy = await repo.duplicate('src');
    expect(copy, isNotNull);
    expect(copy!.id, isNot('src'));
    expect(copy.title, 'Title src');
    expect(copy.tags, ['Work']);
    expect(copy.dueAt, DateTime(2026, 7, 22));
    expect(copy.pinned, isFalse);
    expect(copy.completed, isFalse);
    expect(copy.completedAt, isNull);
    expect(copy.archivedAt, isNull);
    expect(repo.getById(copy.id), isNotNull);
  });

  test('toMap and fromMap roundtrip', () {
    final original = buildItem(
      id: 'round',
      type: NoteType.task,
      pinned: true,
      tags: const ['Work', 'Personal'],
    );
    final restored = NoteItem.fromMap(original.toMap());

    expect(restored.id, original.id);
    expect(restored.type, original.type);
    expect(restored.title, original.title);
    expect(restored.body, original.body);
    expect(restored.pinned, original.pinned);
    expect(restored.completed, original.completed);
    expect(restored.createdAt, original.createdAt);
    expect(restored.updatedAt, original.updatedAt);
    expect(restored.tags, original.tags);
  });

  test('fromMap defaults missing tags to empty list', () {
    final map = buildItem(id: 'legacy').toMap()..remove('tags');
    final restored = NoteItem.fromMap(map);
    expect(restored.tags, isEmpty);
  });

  test('getAllTags returns unique set', () async {
    await repo.add(buildItem(id: '1', tags: const ['Work', 'Personal']));
    await repo.add(buildItem(id: '2', tags: const ['Work', 'Ideas']));
    await repo.add(buildItem(id: '3', tags: const []));

    expect(repo.getAllTags(), {'Work', 'Personal', 'Ideas'});
  });

  test('exportAllMaps and replaceAllFromMaps roundtrip', () async {
    await repo.add(buildItem(id: 'a'));
    await repo.add(buildItem(id: 'b'));
    final exported = repo.exportAllMaps();
    expect(exported.length, 2);

    await repo.replaceAllFromMaps([exported.first]);
    expect(repo.getAll().map((e) => e.id), ['a']);
  });

  test('resetAll clears all notes', () async {
    await repo.add(buildItem(id: 'x'));
    await repo.resetAll();
    expect(repo.getAll(), isEmpty);
    expect(repo.getArchived(), isEmpty);
  });
}
