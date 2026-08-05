import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/data/day_entries_repository.dart';
import 'package:todos_app/features/notes/data/notes_repository.dart';
import 'package:todos_app/features/notes/data/task_reminders_service.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/attachment_actions.dart';

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
  late NotesRepository notes;
  late AttachmentsRepository attachments;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    TaskRemindersService.enabled = false;
    tempDir = await Directory.systemTemp.createTemp('cover_actions_');
    Hive.init(tempDir.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    notes = NotesRepository.instance;
    final dayEntries = DayEntriesRepository.instance;
    await dayEntries.initWithBox(await Hive.openBox<Map>('day_$stamp'));
    await notes.initWithBox(await Hive.openBox<Map>('notes_$stamp'));
    attachments = AttachmentsRepository.instance;
    await attachments.initWithBoxes(
      meta: await Hive.openBox<Map>('att_meta_$stamp'),
      blobs: await Hive.openBox<dynamic>('att_blob_$stamp'),
    );
    notes.dayEntriesForTests = dayEntries;
    notes.attachmentsForTests = attachments;
    await notes.clear();
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

  test('applyCoverAttachmentChange persists clear on existing note', () async {
    final now = DateTime(2026, 8, 5, 12);
    final image = await attachments.addImage(
      noteId: 'n1',
      bytes: await _tinyPng(),
      fileName: 'clip.png',
      mimeType: 'image/png',
    );
    await notes.add(
      NoteItem(
        id: 'n1',
        type: NoteType.note,
        title: 'Con portada',
        body: '',
        pinned: false,
        completed: false,
        createdAt: now,
        updatedAt: now,
        coverAttachmentId: image.id,
      ),
    );

    String? draftCover = image.id;
    await applyCoverAttachmentChange(
      noteId: 'n1',
      coverAttachmentId: null,
      onCoverChanged: (id) => draftCover = id,
    );

    expect(draftCover, isNull);
    expect(notes.getById('n1')!.coverAttachmentId, isNull);
  });

  test('applyCoverAttachmentChange only updates draft for unsaved note', () async {
    String? draftCover = 'temp-cover';
    await applyCoverAttachmentChange(
      noteId: 'draft-only',
      coverAttachmentId: null,
      onCoverChanged: (id) => draftCover = id,
    );

    expect(draftCover, isNull);
    expect(notes.getById('draft-only'), isNull);
  });
}
