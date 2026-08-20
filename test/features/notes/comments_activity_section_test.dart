import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/attachment_actions.dart';
import 'package:todos_app/features/notes/presentation/widgets/comment_composer.dart';

void main() {
  testWidgets('new note composer shows hint and cannot send', (tester) async {
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            enabled: false,
            noteType: NoteType.note,
            onSubmit: _unusedSubmit,
          ),
        ),
      ),
    );

    expect(find.text('Guarda la nota para comentar'), findsOneWidget);
    expect(find.text('Enviar'), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Enviar'))
          .onPressed,
      isNull,
    );
  });

  testWidgets('new task composer uses task hint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            enabled: false,
            noteType: NoteType.task,
            onSubmit: _unusedSubmit,
          ),
        ),
      ),
    );

    expect(find.text('Guarda la tarea para comentar'), findsOneWidget);
  });

  testWidgets('enabled desktop composer can send text', (tester) async {
    var sent = '';
    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            enabled: true,
            noteType: NoteType.note,
            onSubmit: ({required body, required images}) async {
              sent = body;
            },
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Hoy avancé');
    await tester.pump();
    await tester.tap(find.text('Enviar'));
    await tester.pump();
    expect(sent, 'Hoy avancé');
  });

  testWidgets('compact composer shows send icon without label', (tester) async {
    tester.view.physicalSize = const Size(390, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            enabled: true,
            noteType: NoteType.note,
            onSubmit: _unusedSubmit,
          ),
        ),
      ),
    );

    expect(find.text('Enviar'), findsNothing);
    expect(find.byTooltip('Enviar'), findsOneWidget);
    expect(find.byIcon(Icons.send_rounded), findsOneWidget);
  });
}

Future<void> _unusedSubmit({
  required String body,
  required List<PickedImageBytes> images,
}) async {}
