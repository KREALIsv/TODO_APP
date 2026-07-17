import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:todos_app/global/widgets/searchable_dropdown.dart';

void main() {
  testWidgets('filters options and paginates with Ver más', (tester) async {
    final selected = <String>[];
    final options = [
      for (var i = 1; i <= 12; i++) 'Opt${i.toString().padLeft(2, '0')}',
    ];

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableDropdown(
            options: options,
            pageSize: 5,
            onSelected: selected.add,
          ),
        ),
      ),
    );

    await tester.tap(find.byType(TextField));
    await tester.pumpAndSettle();

    expect(find.text('Opt01'), findsOneWidget);
    expect(find.text('Ver más (7)'), findsOneWidget);

    await tester.tap(find.text('Ver más (7)'));
    await tester.pumpAndSettle();
    expect(find.text('Ver más (2)'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Opt1');
    await tester.pumpAndSettle();

    expect(find.text('Opt10'), findsOneWidget);
    expect(find.text('Opt11'), findsOneWidget);
    expect(find.text('Opt02'), findsNothing);
  });

  testWidgets('can create a new option from query', (tester) async {
    String? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SearchableDropdown(
            options: const ['Alpha'],
            onSelected: (value) => selected = value,
          ),
        ),
      ),
    );

    await tester.enterText(find.byType(TextField), 'Beta');
    await tester.pumpAndSettle();

    expect(find.text('Crear "Beta"'), findsOneWidget);
    await tester.tap(find.text('Crear "Beta"'));
    await tester.pumpAndSettle();

    expect(selected, 'Beta');
  });
}
