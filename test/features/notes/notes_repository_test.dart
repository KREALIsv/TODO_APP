import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';

import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/notes/data/task_reminders_service.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

void main() {
  late Directory tempDir;
  late NotesRepository repo;

  setUp(() async {
    TaskRemindersService.enabled = false;
    tempDir = await Directory.systemTemp.createTemp('notes_repo_test_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<Map>('notes_test_${DateTime.now().microsecondsSinceEpoch}');
    repo = NotesRepository.instance;
    await repo.initWithBox(box);
    await repo.clear();
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

  test('setTodayCommitment toggles todayAt', () async {
    await repo.add(buildItem(id: 't', type: NoteType.task));
    await repo.setTodayCommitment('t', true);
    expect(repo.getById('t')?.todayAt, isNotNull);
    await repo.setTodayCommitment('t', false);
    expect(repo.getById('t')?.todayAt, isNull);
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
