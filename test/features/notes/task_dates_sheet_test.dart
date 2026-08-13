import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';
import 'package:todos_app/features/notes/presentation/widgets/task_dates_sheet.dart';

void main() {
  const viewHeight = 800.0;
  const keyboardInset = 320.0;

  Future<void> pumpSheet(
    WidgetTester tester, {
    double keyboardBottom = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: keyboardBottom > 0
            ? MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, viewHeight),
                  viewInsets: EdgeInsets.only(bottom: keyboardBottom),
                ),
                child: TaskDatesSheet(
                  dueAt: DateTime(2026, 7, 20),
                  dueHasTime: false,
                ),
              )
            : Scaffold(
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

  testWidgets('task dates sheet maxHeight shrinks with keyboard inset', (
    tester,
  ) async {
    await pumpSheet(tester, keyboardBottom: keyboardInset);
    await tester.pump();
    tester.takeException();

    final constrainedBox = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(Padding).first,
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );

    expect(
      constrainedBox.constraints.maxHeight,
      sheetMaxHeightFor(
        viewHeight: viewHeight,
        viewInsetBottom: keyboardInset,
        maxHeightFraction: 0.9,
      ),
    );
  });
}
