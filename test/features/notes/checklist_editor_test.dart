import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/checklist_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/checklist_editor.dart';
import 'package:todos_app/global/widgets/outlined_add_chip.dart';

void main() {
  testWidgets('ChecklistEditor shows add button when no checklist', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistEditor(
            title: null,
            items: const [],
            onChanged: ({required title, required items}) {},
          ),
        ),
      ),
    );

    expect(find.text('Checklist'), findsOneWidget);
    expect(find.text('Añadir checklist'), findsOneWidget);
  });

  testWidgets('ChecklistEditor shows items and progress when checklist exists', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistEditor(
            title: 'Mi lista',
            items: const [
              ChecklistItem(id: '1', title: 'Paso 1', completed: true),
              ChecklistItem(id: '2', title: 'Paso 2', completed: false),
            ],
            onChanged: ({required title, required items}) {},
          ),
        ),
      ),
    );

    expect(find.text('Mi lista'), findsOneWidget);
    expect(find.text('Paso 1'), findsOneWidget);
    expect(find.text('Paso 2'), findsOneWidget);
    expect(find.text('1/2'), findsOneWidget);
    expect(find.text('Añade un elemento'), findsOneWidget);
  });

  testWidgets('tapping Añadir checklist opens anchored popover', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChecklistEditor(
            title: null,
            items: const [],
            onChanged: ({required title, required items}) {},
          ),
        ),
      ),
    );

    await tester.tap(find.text('Añadir checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Añadir checklist'), findsNWidgets(2));
    expect(find.text('Título'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('add checklist popover anchors below button within viewport', (
    WidgetTester tester,
  ) async {
    const viewport = Size(360, 640);
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: const MediaQueryData(size: viewport),
          child: Scaffold(
            body: ChecklistEditor(
              title: null,
              items: const [],
              onChanged: ({required title, required items}) {},
            ),
          ),
        ),
      ),
    );

    final buttonFinder = find.byType(OutlinedAddChip);
    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    final buttonRect = tester.getRect(buttonFinder);
    final popoverRect = tester.getRect(
      find.ancestor(
        of: find.text('Título'),
        matching: find.byType(Material),
      ),
    );

    expect(popoverRect.top, greaterThan(buttonRect.bottom));
    expect(popoverRect.left, greaterThanOrEqualTo(16));
    expect(popoverRect.right, lessThanOrEqualTo(viewport.width - 16));
    expect(
      (popoverRect.left - buttonRect.left).abs(),
      lessThan(24),
      reason: 'popover should align with the add button',
    );
  });

  testWidgets('cannot add another element while a draft row is empty', (
    WidgetTester tester,
  ) async {
    var checklistItems = const <ChecklistItem>[
      ChecklistItem(id: '1', title: 'Paso 1', completed: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ChecklistEditor(
                title: 'Mi lista',
                items: checklistItems,
                onChanged: ({required title, required items}) {
                  setState(() => checklistItems = items);
                },
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Añade un elemento'));
    await tester.pumpAndSettle();

    expect(checklistItems.length, 2);
    expect(checklistItems.last.title, '');

    await tester.tap(find.text('Añade un elemento'));
    await tester.pumpAndSettle();

    expect(checklistItems.length, 2);
  });

  testWidgets('draft row shows editing highlight until text is committed', (
    WidgetTester tester,
  ) async {
    var checklistItems = const <ChecklistItem>[
      ChecklistItem(id: '1', title: '', completed: false),
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return ChecklistEditor(
                title: 'Mi lista',
                items: checklistItems,
                onChanged: ({required title, required items}) {
                  setState(() => checklistItems = items);
                },
              );
            },
          ),
        ),
      ),
    );

    final draftRow = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    expect(draftRow.decoration, isNotNull);
    final decoration = draftRow.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);

    await tester.enterText(find.byType(TextField), 'Nuevo paso');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();

    final committedRow = tester.widget<AnimatedContainer>(
      find.ancestor(
        of: find.byType(TextField),
        matching: find.byType(AnimatedContainer),
      ).first,
    );
    final committedDecoration = committedRow.decoration! as BoxDecoration;
    expect(committedDecoration.border, isNull);
  });
}
