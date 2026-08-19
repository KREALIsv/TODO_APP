import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/attachment_actions.dart';
import 'package:todos_app/features/notes/presentation/widgets/comment_composer.dart';

void main() {
  testWidgets('new note composer shows hint and cannot send', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            noteId: 'draft',
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
      tester.widget<TextButton>(find.widgetWithText(TextButton, 'Enviar')).onPressed,
      isNull,
    );
  });

  testWidgets('new task composer uses task hint', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            noteId: 'draft',
            enabled: false,
            noteType: NoteType.task,
            onSubmit: _unusedSubmit,
          ),
        ),
      ),
    );

    expect(find.text('Guarda la tarea para comentar'), findsOneWidget);
  });

  testWidgets('enabled composer can send text', (tester) async {
    var sent = '';
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: CommentComposer(
            noteId: 'n1',
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
}

Future<void> _unusedSubmit({
  required String body,
  required List<PickedImageBytes> images,
}) async {}
