import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('note_card_completion_');
    Hive.init(tempDir.path);
    await AttachmentsRepository.instance.initWithBoxes(
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

  NoteItem task({required bool completed}) {
    return NoteItem(
      id: 'feedback',
      type: NoteType.task,
      title: 'darle feedback a gaby',
      body: '',
      pinned: false,
      completed: completed,
      createdAt: DateTime(2026, 7, 30),
      updatedAt: DateTime(2026, 7, 31, 18),
      completedAt: completed ? DateTime(2026, 7, 31, 18) : null,
    );
  }

  testWidgets('Backlog completed task shows a checked checkbox', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            item: task(completed: true),
            onTap: () {},
          ),
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isTrue);
  });

  testWidgets('Backlog open task shows an empty checkbox', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            item: task(completed: false),
            onTap: () {},
          ),
        ),
      ),
    );

    final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
    expect(checkbox.value, isFalse);
  });
}
