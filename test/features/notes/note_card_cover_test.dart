import 'dart:io';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';
import 'package:todos_app/global/widgets/app_loading.dart';

final _onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/p9sAAAAASUVORK5CYII=',
);

void main() {
  late Directory tempDir;
  late AttachmentsRepository attachments;
  late Box<Map> metaBox;
  late Box<dynamic> blobBox;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    tempDir = await Directory.systemTemp.createTemp('note_card_cover_');
    Hive.init(tempDir.path);
    final stamp = DateTime.now().microsecondsSinceEpoch;
    attachments = AttachmentsRepository.instance;
    metaBox = await Hive.openBox<Map>('att_meta_$stamp');
    blobBox = await Hive.openBox<dynamic>('att_blob_$stamp');
    await attachments.initWithBoxes(meta: metaBox, blobs: blobBox);
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

  Future<String> _addCoverMeta({
    required int imageWidth,
    required int imageHeight,
  }) async {
    const id = 'cover-1';
    await blobBox.put(id, _onePixelPng);
    await metaBox.put(id, {
      'id': id,
      'noteId': 'n1',
      'fileName': 'cover.png',
      'mimeType': 'image/png',
      'byteSize': _onePixelPng.lengthInBytes,
      'createdAt': DateTime(2026, 8, 8, 12).toIso8601String(),
      'sortOrder': 0,
      'width': imageWidth,
      'height': imageHeight,
    });
    return id;
  }

  Future<AppMemoryImage> _pumpCover(
    WidgetTester tester, {
    required int imageWidth,
    required int imageHeight,
    required double cardWidth,
  }) async {
    final coverId = await _addCoverMeta(
      imageWidth: imageWidth,
      imageHeight: imageHeight,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: cardWidth,
              child: NoteCard(
                item: _noteWithCover(coverId),
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
