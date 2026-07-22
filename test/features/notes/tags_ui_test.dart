import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';

import 'package:todos_app/features/notes/data/attachments_repository.dart';
import 'package:todos_app/features/notes/data/tags_repository.dart';
import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';
import 'package:todos_app/features/notes/presentation/widgets/tag_pill.dart';
import 'package:todos_app/features/notes/presentation/widgets/tags_editor.dart';

void main() {
  final now = DateTime(2026, 7, 16, 12);
  late Directory tempDir;
  late TagsRepository tagsRepo;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('tags_ui_');
    Hive.init(tempDir.path);
    final box = await Hive.openBox<dynamic>(
      'tags_ui_${DateTime.now().microsecondsSinceEpoch}',
    );
    tagsRepo = TagsRepository.instance;
    await tagsRepo.initWithBox(box);
    await tagsRepo.clear();
    await tagsRepo.ensureTags(['Work', 'Personal', 'Ideas', 'A', 'B', 'C', 'D']);

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

  NoteItem buildNote({List<String> tags = const []}) {
    return NoteItem(
      id: '1',
      type: NoteType.note,
      title: 'Título',
      body: 'Cuerpo',
      pinned: false,
      completed: false,
      createdAt: now,
      updatedAt: now,
      tags: tags,
    );
  }

  testWidgets('NoteCard renders up to three tags and overflow', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: NoteCard(
            item: buildNote(tags: const ['A', 'B', 'C', 'D']),
            tagsRepository: tagsRepo,
            onTap: () {},
          ),
        ),
      ),
    );

    expect(find.text('A'), findsOneWidget);
    expect(find.text('B'), findsOneWidget);
    expect(find.text('C'), findsOneWidget);
    expect(find.text('D'), findsNothing);
    expect(find.text('+1'), findsOneWidget);
    expect(find.byType(TagPill), findsNWidgets(3));
  });

  testWidgets('TagsEditor shows add circle beside tags', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagsEditor(
            tags: const ['Work'],
            suggestions: const {'Personal', 'Ideas'},
            tagsRepository: tagsRepo,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    // Con tags existentes, el botón es solo el círculo (sin label de texto).
    expect(find.text('Añadir etiqueta'), findsNothing);
  });

  testWidgets('TagsEditor shows CTA pill when there are no tags yet', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagsEditor(
            tags: const [],
            suggestions: const {'Personal', 'Ideas'},
            tagsRepository: tagsRepo,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('Añadir etiqueta'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget);
    expect(find.text('Toca + para buscar o crear etiquetas'), findsNothing);

    await tester.tap(find.text('Añadir etiqueta'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Buscar etiquetas…'), findsOneWidget);
  });

  testWidgets('TagsEditor + opens picker to search select and create', (
    WidgetTester tester,
  ) async {
    var tags = <String>['Work'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TagsEditor(
                tags: tags,
                suggestions: const {'Personal', 'Ideas'},
                tagsRepository: tagsRepo,
                onChanged: (next) => setState(() => tags = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Etiquetas'), findsWidgets);
    expect(find.text('Buscar etiquetas…'), findsOneWidget);
    expect(find.text('Crear una etiqueta nueva'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Per');
    await tester.pump();

    expect(find.text('Personal'), findsOneWidget);
    expect(find.text('Ideas'), findsNothing);

    await tester.tap(find.byType(Checkbox).first);
    await tester.pump();

    expect(tags, contains('Personal'));

    await tester.tap(find.text('Crear una etiqueta nueva'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Crear etiqueta'), findsOneWidget);
    expect(find.byIcon(Icons.arrow_back_ios_new), findsOneWidget);
    expect(find.text('Seleccionar un color'), findsOneWidget);
    expect(find.text('Opacidad'), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
    expect(find.byIcon(Icons.check), findsOneWidget);

    // Misma ventana: volver a la lista sin apilar otro modal.
    await tester.tap(find.byIcon(Icons.arrow_back_ios_new));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Buscar etiquetas…'), findsOneWidget);
    expect(find.text('Crear una etiqueta nueva'), findsOneWidget);
    expect(find.text('Crear etiqueta'), findsNothing);
  });

  testWidgets('TagsEditor can remove a selected tag from the row', (
    WidgetTester tester,
  ) async {
    var tags = <String>['Work', 'Personal'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TagsEditor(
                tags: tags,
                suggestions: const {'Ideas'},
                tagsRepository: tagsRepo,
                onChanged: (next) => setState(() => tags = next),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pump();

    expect(tags.length, 1);
  });
}
