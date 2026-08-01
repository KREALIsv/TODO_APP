import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/features/notes/domain/checklist_item.dart';
import 'package:todos_app/features/notes/presentation/widgets/checklist_editor.dart';

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
    expect(find.byIcon(Icons.check_box_outlined), findsOneWidget);
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
    expect(find.text('Añadir elemento'), findsOneWidget);
  });

  testWidgets('tapping Checklist opens anchored popover', (
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

    await tester.tap(find.text('Checklist'));
    await tester.pumpAndSettle();

    expect(find.text('Añadir checklist'), findsOneWidget);
    expect(find.text('Título'), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
  });
}
