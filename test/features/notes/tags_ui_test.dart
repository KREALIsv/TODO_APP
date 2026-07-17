import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/note_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_card.dart';
import 'package:todos_app/features/notes/presentation/widgets/tag_pill.dart';
import 'package:todos_app/features/notes/presentation/widgets/tags_editor.dart';

void main() {
  final now = DateTime(2026, 7, 16, 12);

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

  testWidgets('TagsEditor can add and remove tags', (WidgetTester tester) async {
    var tags = <String>['Work'];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return TagsEditor(
                tags: tags,
                suggestions: const {'Personal', 'Ideas'},
                onChanged: (next) => setState(() => tags = next),
              );
            },
          ),
        ),
      ),
    );

    expect(find.text('Work'), findsOneWidget);
    expect(find.text('Sin etiquetas'), findsNothing);

    await tester.enterText(find.byType(TextField), 'Personal');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    expect(tags, contains('Personal'));
    expect(find.text('Personal'), findsWidgets);

    await tester.tap(find.byIcon(Icons.close).first);
    await tester.pumpAndSettle();

    expect(tags.contains('Work'), isFalse);
  });

  testWidgets('TagsEditor dropdown filters and paginates suggestions', (
    WidgetTester tester,
  ) async {
    final suggestions = {
      for (var i = 1; i <= 12; i++) 'Cat${i.toString().padLeft(2, '0')}',
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TagsEditor(
            tags: const [],
            suggestions: suggestions,
            pageSize: 5,
            onChanged: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Cat01'), findsOneWidget);
    expect(find.text('Ver más (7)'), findsOneWidget);

    await tester.tap(find.text('Ver más (7)'));
    await tester.pumpAndSettle();

    // Segunda página: quedan 2 de 12 con pageSize 5.
    expect(find.text('Ver más (2)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Cat1');
    await tester.pumpAndSettle();

    expect(find.text('Cat10'), findsOneWidget);
    expect(find.text('Cat11'), findsOneWidget);
    expect(find.text('Cat12'), findsOneWidget);
    expect(find.text('Cat02'), findsNothing);
    expect(find.textContaining('Ver más'), findsNothing);
  });
}
