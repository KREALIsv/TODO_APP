import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/notes/data/tags_repository.dart';
import 'package:todos_app/features/notes/domain/date_only.dart';
import 'package:todos_app/features/notes/domain/day_entry.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/domain/tag_colors.dart';
import 'package:todos_app/features/settings/presentation/data_backup.dart';

NoteItem _task({
  required String id,
  List<String> tags = const [],
  DateTime? todayAt,
}) {
  final now = DateTime(2026, 7, 21, 10);
  return NoteItem(
    id: id,
    type: NoteType.task,
    title: 'Tarea $id',
    body: '',
    pinned: false,
    completed: false,
    createdAt: now,
    updatedAt: now,
    tags: tags,
    todayAt: todayAt ?? now,
  );
}

void main() {
  late Directory tempDir;
  late NotesRepository notes;
  late TagsRepository tags;
  late DayEntriesRepository dayEntries;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('data_backup_test_');
    Hive.init(tempDir.path);

    notes = NotesRepository.instance;
    tags = TagsRepository.instance;
    dayEntries = DayEntriesRepository.instance;

    await notes.initWithBox(
      await Hive.openBox('notes_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await tags.initWithBox(
      await Hive.openBox('tags_${DateTime.now().microsecondsSinceEpoch}'),
    );
    await dayEntries.initWithBox(
      await Hive.openBox('day_${DateTime.now().microsecondsSinceEpoch}'),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('parseBackup accepts v2 payload with tags and day entries', () {
    const raw = '''
{
  "version": 2,
  "notes": [
    {
      "id": "n1",
      "type": "task",
      "title": "SYVEX",
      "body": "",
      "pinned": false,
      "completed": false,
      "createdAt": "2026-07-21T10:00:00.000",
      "updatedAt": "2026-07-21T10:00:00.000",
      "tags": ["SYVEX"],
      "todayAt": "2026-07-21T10:00:00.000"
    }
  ],
  "tags": {
    "names": ["SYVEX"],
    "colors": { "syvex": "violet" },
    "opacities": { "syvex": 0.9 }
  },
  "dayEntries": [
    {
      "id": "e1",
      "noteId": "n1",
      "day": "2026-07-21",
      "via": "todaySwitch",
      "outcome": "open",
      "createdAt": "2026-07-21T10:00:00.000"
    }
  ]
}
''';

    final payload = parseBackup(raw);
    expect(payload, isNotNull);
    expect(payload!.version, 2);
    expect(payload.notes.length, 1);
    expect(payload.tags?['names'], ['SYVEX']);
    expect(payload.dayEntries.length, 1);
  });

  test('encodeBackup emits version 2 with tags and day entries', () async {
    await notes.add(_task(id: 't1', tags: ['SYVEX']));
    await tags.setStyle('SYVEX', colorId: 'violet', opacity: 0.9);
    await dayEntries.upsert(
      DayEntry(
        id: 'e1',
        noteId: 't1',
        day: dateOnly(DateTime(2026, 7, 21)),
        via: DayVia.todaySwitch,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 21, 10),
      ),
    );

    final raw = encodeBackup(
      notes: notes,
      tags: tags,
      dayEntries: dayEntries,
    );
    final payload = parseBackup(raw)!;

    expect(payload.version, backupFormatVersion);
    expect(payload.notes.length, 1);
    expect(payload.tags?['colors'], containsPair('syvex', 'violet'));
    expect(payload.dayEntries.length, 1);
  });

  test('applyBackupPayload roundtrips notes tags and day entries', () async {
    await notes.add(_task(id: 't1', tags: ['SYVEX']));
    await tags.setStyle('SYVEX', colorId: 'violet', opacity: 0.85);
    await dayEntries.upsert(
      DayEntry(
        id: 'e1',
        noteId: 't1',
        day: dateOnly(DateTime(2026, 7, 21)),
        via: DayVia.todaySwitch,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 21, 10),
      ),
    );

    final exported = parseBackup(
      encodeBackup(notes: notes, tags: tags, dayEntries: dayEntries),
    )!;

    await resetAllAppContent(
      notes: notes,
      tags: tags,
      dayEntries: dayEntries,
    );
    expect(notes.getAll(), isEmpty);
    expect(dayEntries.getAll(), isEmpty);

    await applyBackupPayload(
      payload: exported,
      notes: notes,
      tags: tags,
      dayEntries: dayEntries,
    );

    expect(notes.getById('t1')?.tags, ['SYVEX']);
    expect(tags.getColorId('SYVEX'), 'violet');
    expect(tags.getOpacity('SYVEX'), closeTo(0.85, 0.001));
    expect(dayEntries.findForNoteDay('t1', DateTime(2026, 7, 21)), isNotNull);
  });

  test('applyBackupPayload rolls back when day entry is invalid mid-apply',
      () async {
    await notes.add(_task(id: 'keep'));
    final snapshot = notes.exportAllMaps();

    final bad = BackupPayload(
      version: 2,
      notes: snapshot,
      tags: tags.exportSnapshot(),
      dayEntries: [
        {'id': 'bad', 'noteId': 'keep'},
      ],
    );

    expect(
      () => applyBackupPayload(
        payload: bad,
        notes: notes,
        tags: tags,
        dayEntries: dayEntries,
      ),
      throwsA(anything),
    );
    expect(notes.getById('keep'), isNotNull);
  });

  test('v1 import keeps notes and rebuilds tag defaults', () async {
    const raw = '''
{
  "version": 1,
  "notes": [
    {
      "id": "n1",
      "type": "note",
      "title": "Hola",
      "body": "",
      "pinned": false,
      "completed": false,
      "createdAt": "2026-07-21T10:00:00.000",
      "updatedAt": "2026-07-21T10:00:00.000",
      "tags": ["Custom"]
    }
  ]
}
''';

    final payload = parseBackup(raw)!;
    await applyBackupPayload(
      payload: payload,
      notes: notes,
      tags: tags,
      dayEntries: dayEntries,
    );

    expect(notes.getById('n1')?.title, 'Hola');
    expect(tags.getAll(), contains('Custom'));
    expect(
      tags.getColorId('Custom'),
      TagColors.defaultIdForTag('Custom'),
    );
  });

  test('resetAllAppContent clears notes tags and day entries', () async {
    await notes.add(_task(id: 't1', tags: ['SYVEX']));
    await tags.setStyle('SYVEX', colorId: 'violet');
    await dayEntries.upsert(
      DayEntry(
        id: 'e1',
        noteId: 't1',
        day: dateOnly(DateTime(2026, 7, 21)),
        via: DayVia.todaySwitch,
        outcome: DayOutcome.open,
        createdAt: DateTime(2026, 7, 21),
      ),
    );

    await resetAllAppContent(
      notes: notes,
      tags: tags,
      dayEntries: dayEntries,
    );

    expect(notes.getAll(), isEmpty);
    expect(dayEntries.getAll(), isEmpty);
    expect(tags.getColorId('SYVEX'), isNull);
  });
}
