import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/features/notes/presentation/widgets/task_dates_sheet.dart';

void main() {
  Future<void> pumpSheet(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskDatesSheet(
            dueAt: DateTime(2026, 7, 20),
            dueHasTime: false,
          ),
        ),
      ),
    );
  }

  testWidgets('date opens inline calendar without dialog', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('20 jul 2026'));
    await tester.pumpAndSettle();

    expect(find.byType(CalendarDatePicker), findsOneWidget);
    expect(find.text('Vencimiento'), findsOneWidget);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('time opens inline picker without dialog', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Sin hora'));
    await tester.pumpAndSettle();

    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    expect(find.text('Hora'), findsWidgets);
    expect(find.byTooltip('Volver'), findsOneWidget);
    expect(find.byType(Dialog), findsNothing);
  });

  testWidgets('back returns to form without applying time', (tester) async {
    await pumpSheet(tester);

    await tester.tap(find.text('Sin hora'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Volver'));
    await tester.pumpAndSettle();

    expect(find.text('Sin hora'), findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.byType(CupertinoDatePicker), findsNothing);
  });
}
