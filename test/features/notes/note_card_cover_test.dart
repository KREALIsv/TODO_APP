import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';
import 'package:todos_app/global/widgets/app_loading.dart';

Future<Uint8List> _pngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    ui.Paint()..color = const ui.Color(0xFF8BC34A),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  return bytes!.buffer.asUint8List();
}

void main() {
  late Directory tempDir;
  late AttachmentsRepository attachments;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('note_card_cover_');
    Hive.init(tempDir.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    attachments = AttachmentsRepository.instance;
    await attachments.initWithBoxes(
      meta: await Hive.openBox<Map>('att_meta_$stamp'),
      blobs: await Hive.openBox<dynamic>('att_blob_$stamp'),
    );
    await attachments.clear();
  });

  tearDown(() async {
    await Hive.deleteFromDisk();
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  NoteItem _noteWithCover(String coverId) {
    final now = DateTime(2026, 8, 8, 12);
    return NoteItem(
      id: 'n1',
      type: NoteType.note,
      title: 'Con portada',
      body: '',
      pinned: false,
      completed: false,
      createdAt: now,
      updatedAt: now,
      coverAttachmentId: coverId,
    );
  }

  Future<AppMemoryImage> _pumpCover(
    WidgetTester tester, {
    required int imageWidth,
    required int imageHeight,
    required double cardWidth,
  }) async {
    final image = await attachments.addImage(
      noteId: 'n1',
      bytes: await _pngBytes(imageWidth, imageHeight),
      fileName: 'cover.png',
      mimeType: 'image/png',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: cardWidth,
              child: NoteCard(
                item: _noteWithCover(image.id),
                attachmentsRepository: attachments,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    );

    return tester.widget<AppMemoryImage>(find.byType(AppMemoryImage));
  }

  testWidgets('NoteCard cover keeps landscape aspect from card width', (
    tester,
  ) async {
    final cover = await _pumpCover(
      tester,
      imageWidth: 200,
      imageHeight: 100,
      cardWidth: 240,
    );

    expect(cover.fit, BoxFit.contain);
    expect(cover.width, 240);
    expect(cover.height, 120);
  });

  testWidgets('NoteCard cover caps tall portraits without stretching', (
    tester,
  ) async {
    final cover = await _pumpCover(
      tester,
      imageWidth: 100,
      imageHeight: 200,
      cardWidth: 240,
    );

    expect(cover.fit, BoxFit.contain);
    expect(cover.width, 240);
    expect(cover.height, NoteCard.maxCoverHeight);
  });
}
