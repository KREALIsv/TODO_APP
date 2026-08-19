import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/data/comments_repository.dart';
import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/note_audit_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/notes/data/task_reminders_service.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';

Future<Uint8List> _tinyPng() async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 8, 8),
    ui.Paint()..color = const ui.Color(0xFF2DA44E),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(8, 8);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

NoteItem _item({
  required String id,
  NoteType type = NoteType.note,
  String title = 'Nota',
  DateTime? updatedAt,
  String? coverAttachmentId,
}) {
  final now = DateTime(2026, 8, 19, 10);
  return NoteItem(
    id: id,
    type: type,
    title: title,
    body: '',
    pinned: false,
    completed: false,
    createdAt: now,
    updatedAt: updatedAt ?? now,
    coverAttachmentId: coverAttachmentId,
  );
}

void main() {
  late Directory tempDir;
  late NotesRepository notes;
  late CommentsRepository comments;
  late NoteAuditRepository audits;
  late AttachmentsRepository attachments;
  late DayEntriesRepository dayEntries;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TaskRemindersService.enabled = false;
    tempDir = await Directory.systemTemp.createTemp('comments_repo_test_');
    Hive.init(tempDir.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    notes = NotesRepository.instance;
    comments = CommentsRepository.instance;
    audits = NoteAuditRepository.instance;
    attachments = AttachmentsRepository.instance;
    dayEntries = DayEntriesRepository.instance;
    await notes.initWithBox(await Hive.openBox<Map>('notes_$stamp'));
    await comments.initWithBox(await Hive.openBox<Map>('comments_$stamp'));
    await audits.initWithBox(await Hive.openBox<Map>('audits_$stamp'));
    await dayEntries.initWithBox(await Hive.openBox<Map>('days_$stamp'));
    await attachments.initWithBoxes(
      meta: await Hive.openBox<Map>('att_meta_$stamp'),
      blobs: await Hive.openBox<dynamic>('att_blob_$stamp'),
    );
    notes.commentsForTests = comments;
    notes.auditsForTests = audits;
    notes.attachmentsForTests = attachments;
    notes.dayEntriesForTests = dayEntries;
    comments.attachmentsForTests = attachments;
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

  test('forNote excludes comment images from adjuntos count', () async {
    final bytes = await _tinyPng();
    await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'item.png',
    );
    await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'comment.png',
      commentId: 'c1',
    );
    expect(attachments.forNote('n1'), hasLength(1));
    expect(attachments.forComment('c1'), hasLength(1));
    expect(attachments.countFor('n1'), 1);
  });

  test('comment image can be resolved as cover bytes', () async {
    final bytes = await _tinyPng();
    final image = await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'cover.png',
      commentId: 'c1',
    );
    expect(attachments.getById(image.id)?.commentId, 'c1');
    expect(attachments.bytesFor(image.id), isNotNull);
  });

  test('add comment image does not auto-set cover', () async {
    await notes.add(_item(id: 'n1'));
    final bytes = await _tinyPng();
    await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'shot.png',
      commentId: 'c1',
    );
    expect(notes.getById('n1')?.coverAttachmentId, isNull);
  });

  test('delete comment cover clears cover and keeps item attachments', () async {
    await notes.add(_item(id: 'n1'));
    final bytes = await _tinyPng();
    final itemImage = await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'item.png',
    );
    final comment = await comments.add(noteId: 'n1', body: 'foto');
    final commentImage = await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'comment.png',
      commentId: comment.id,
    );
    await notes.update(
      notes.getById('n1')!.copyWith(coverAttachmentId: commentImage.id),
    );
    expect(audits.forNote('n1').map((e) => e.kind), contains(isNotNull));

    final note = notes.getById('n1')!;
    await comments.delete(comment.id);
    await notes.update(
      note.copyWith(
        coverAttachmentId: null,
        updatedAt: DateTime.now(),
      ),
    );

    expect(notes.getById('n1')?.coverAttachmentId, isNull);
    expect(attachments.forNote('n1').map((e) => e.id), [itemImage.id]);
    expect(attachments.forComment(comment.id), isEmpty);
  });

  test('add comment bumps updatedAt and writes no audits', () async {
    await notes.add(_item(id: 'n1'));
    final createdAudits = audits.forNote('n1').length;
    final before = notes.getById('n1')!.updatedAt;
    await comments.add(
      noteId: 'n1',
      body: 'avance',
      now: DateTime(2026, 8, 19, 12),
    );
    await notes.update(
      notes.getById('n1')!.copyWith(updatedAt: DateTime(2026, 8, 19, 12)),
    );
    expect(notes.getById('n1')!.updatedAt.isAfter(before), isTrue);
    expect(audits.forNote('n1'), hasLength(createdAudits));
  });

  test('saving title change writes audit', () async {
    await notes.add(_item(id: 'n1'));
    await notes.update(
      notes.getById('n1')!.copyWith(
            title: 'Otro título',
            updatedAt: DateTime(2026, 8, 19, 12),
          ),
    );
    expect(
      audits.forNote('n1').map((e) => e.kind.name),
      contains('titleChanged'),
    );
  });

  test('toggleCompleted writes no audits and keeps day entry', () async {
    await notes.add(_item(id: 't1', type: NoteType.task));
    expect(audits.forNote('t1'), isEmpty);
    await notes.toggleCompleted('t1');
    expect(audits.forNote('t1'), isEmpty);
    expect(dayEntries.entriesForNote('t1'), isNotEmpty);
  });

  test('saveFromSync does not record audits', () async {
    await notes.add(_item(id: 'n1'));
    final before = audits.forNote('n1').length;
    await notes.saveFromSync(
      _item(id: 'n1', title: 'Remoto', updatedAt: DateTime(2026, 8, 19, 15)),
    );
    expect(audits.forNote('n1'), hasLength(before));
  });

  test('delete note cascades comments audits and comment images', () async {
    await notes.add(_item(id: 'n1'));
    final comment = await comments.add(noteId: 'n1', body: 'bye');
    final bytes = await _tinyPng();
    await attachments.addImage(
      noteId: 'n1',
      bytes: bytes,
      fileName: 'c.png',
      commentId: comment.id,
    );
    await notes.delete('n1');
    expect(comments.forNote('n1'), isEmpty);
    expect(audits.forNote('n1'), isEmpty);
    expect(attachments.forComment(comment.id), isEmpty);
  });
}
