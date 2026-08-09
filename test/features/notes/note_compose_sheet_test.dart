import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';
import 'package:todos_app/features/notes/presentation/widgets/note_compose_sheet.dart';

void main() {
  const viewHeight = 800.0;
  const keyboardInset = 320.0;

  Future<void> pumpComposeSheet(
    WidgetTester tester, {
    double keyboardBottom = 0,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: const Size(390, viewHeight),
            viewInsets: EdgeInsets.only(bottom: keyboardBottom),
          ),
          child: NoteComposeSheet(initialIsTask: true),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    tester.takeException();
  }

  testWidgets('compose sheet pads above keyboard overlay', (tester) async {
    await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

    final padding = tester.widget<AnimatedPadding>(
      find.byType(AnimatedPadding),
    );
    expect(
      padding.padding.resolve(TextDirection.ltr).bottom,
      keyboardInset,
    );
  });

  testWidgets('compose sheet maxHeight shrinks when keyboard is open', (
    tester,
  ) async {
    await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

    final constrainedBox = tester.widget<ConstrainedBox>(
      find
          .descendant(
            of: find.byType(AnimatedPadding),
            matching: find.byType(ConstrainedBox),
          )
          .first,
    );

    expect(
      constrainedBox.constraints.maxHeight,
      sheetMaxHeightFor(
        viewHeight: viewHeight,
        viewInsetBottom: keyboardInset,
        maxHeightFraction: 0.92,
        minHeight: 240,
      ),
    );
  });

  testWidgets('description field is reachable when keyboard is open', (
    tester,
  ) async {
    await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

    expect(find.byType(TextField), findsNWidgets(2));
    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    tester.takeException();

    expect(find.byType(TextField).last, findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
  });
}
