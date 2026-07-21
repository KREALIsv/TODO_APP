import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/domain/note_attachment.dart';
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

void main() {
  late Directory tempDir;
  late AttachmentsRepository repo;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('attachments_test_');
    Hive.init(tempDir.path);
    repo = AttachmentsRepository.instance;
    await repo.initWithBoxes(
      meta: await Hive.openBox<Map>(
        'att_meta_${DateTime.now().microsecondsSinceEpoch}',
      ),
      blobs: await Hive.openBox<dynamic>(
        'att_blob_${DateTime.now().microsecondsSinceEpoch}',
      ),
    );
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  test('NoteAttachment roundtrip map', () {
    final original = NoteAttachment(
      id: 'a1',
      noteId: 'n1',
      fileName: 'shot.png',
      mimeType: 'image/png',
      byteSize: 12,
      createdAt: DateTime(2026, 7, 21, 12),
      sortOrder: 0,
      width: 8,
      height: 8,
    );
    final restored = NoteAttachment.fromMap(original.toMap());
    expect(restored.id, original.id);
    expect(restored.noteId, original.noteId);
    expect(restored.fileName, original.fileName);
  });

  test('NoteItem coverAttachmentId survives map roundtrip', () {
    final item = NoteItem(
      id: 'n1',
      type: NoteType.task,
      title: 'Con portada',
      body: '',
      pinned: false,
      completed: false,
      createdAt: DateTime(2026, 7, 21),
      updatedAt: DateTime(2026, 7, 21),
      coverAttachmentId: 'a1',
    );
    expect(NoteItem.fromMap(item.toMap()).coverAttachmentId, 'a1');
    expect(
      item.copyWith(coverAttachmentId: null).coverAttachmentId,
      isNull,
    );
  });

  test('addImage stores bytes and lists per note', () async {
    final bytes = await _tinyPng();
    final created = await repo.addImage(
      noteId: 'note-1',
      bytes: bytes,
      fileName: 'a.png',
      mimeType: 'image/png',
    );

    expect(repo.forNote('note-1').map((e) => e.id), [created.id]);
    expect(repo.bytesFor(created.id), isNotNull);
    expect(repo.countFor('note-1'), 1);
    expect(created.width, greaterThan(0));
    expect(created.height, greaterThan(0));
  });

  test('deleteForNote removes all attachments', () async {
    final bytes = await _tinyPng();
    await repo.addImage(noteId: 'n', bytes: bytes, fileName: '1.png');
    await repo.addImage(noteId: 'n', bytes: bytes, fileName: '2.png');
    await repo.deleteForNote('n');
    expect(repo.forNote('n'), isEmpty);
  });

  test('export and replace roundtrip keeps bytes', () async {
    final bytes = await _tinyPng();
    final created = await repo.addImage(
      noteId: 'n',
      bytes: bytes,
      fileName: 'a.png',
    );
    final exported = repo.exportAllMaps();
    await repo.resetAll();
    expect(repo.forNote('n'), isEmpty);

    await repo.replaceAllFromMaps(exported);
    expect(repo.getById(created.id)?.noteId, 'n');
    expect(repo.bytesFor(created.id), isNotNull);
  });
}
