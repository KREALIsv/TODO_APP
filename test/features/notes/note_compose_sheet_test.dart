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
    double height = viewHeight,
    double width = 390,
  }) async {
    await tester.binding.setSurfaceSize(Size(width, height));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(
            size: Size(width, height),
            viewInsets: EdgeInsets.only(bottom: keyboardBottom),
          ),
          // Align to bottom like showModalBottomSheet so compact-sheet
          // geometry matches production (sheet sits above the keyboard).
          child: const Material(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: NoteComposeSheet(initialIsTask: true),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    // Flush delayed title autofocus timer so tests do not leak pending timers.
    await tester.pump(const Duration(milliseconds: 400));
    tester.takeException();
  }

  testWidgets('compose sheet pads when description overlaps keyboard', (
    tester,
  ) async {
    // Short viewport forces the description field under the overlay IME.
    await pumpComposeSheet(
      tester,
      keyboardBottom: keyboardInset,
      height: 520,
    );

    await tester.tap(find.byType(TextField).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    tester.takeException();

    final padding = tester.widget<AnimatedPadding>(
      find.byType(AnimatedPadding),
    );
    expect(
      padding.padding.resolve(TextDirection.ltr).bottom,
      greaterThan(0),
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

  testWidgets('title focus keeps header and title on screen with keyboard', (
    tester,
  ) async {
    await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

    final titleField = find.byType(TextField).first;
    await tester.tap(titleField);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 250));
    tester.takeException();

    expect(find.text('Nueva tarea'), findsOneWidget);
    expect(titleField, findsOneWidget);
    expect(find.text('Guardar'), findsOneWidget);
    expect(find.text('Cancelar'), findsOneWidget);

    // Title must remain in the laid-out surface (not scrolled off-screen).
    final titleBox = tester.renderObject<RenderBox>(titleField);
    final surface = tester.binding.renderViews.first.size;
    expect(titleBox.localToGlobal(Offset.zero).dy, greaterThanOrEqualTo(0));
    expect(
      titleBox.localToGlobal(Offset.zero).dy,
      lessThan(surface.height),
    );
  });

  testWidgets(
    'title focus does not pad when field already clears keyboard overlay',
    (tester) async {
      await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

      await tester.tap(find.byType(TextField).first);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
      tester.takeException();

      final padding = tester.widget<AnimatedPadding>(
        find.byType(AnimatedPadding),
      );
      expect(padding.padding.resolve(TextDirection.ltr).bottom, 0);
    },
  );

  testWidgets(
    'compose sheet stays compact above keyboard instead of stretching',
    (tester) async {
      await pumpComposeSheet(tester, keyboardBottom: keyboardInset);

      final maxHeight = sheetMaxHeightFor(
        viewHeight: viewHeight,
        viewInsetBottom: keyboardInset,
        maxHeightFraction: 0.92,
        minHeight: 240,
      );

      final scrollView = find.descendant(
        of: find.byType(AnimatedPadding),
        matching: find.byType(ListView),
      );
      final sheetHeight =
          tester.renderObject<RenderBox>(scrollView).size.height;

      // shrinkWrap intrinsic height — must not fill the whole safe area,
      // which would park the title at the top with a large empty gap.
      expect(sheetHeight, lessThan(maxHeight));
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(find.text('Guardar'), findsOneWidget);

      // Title should sit in the lower half (compact sheet above keyboard),
      // not pinned to the top of the viewport.
      final titleY = tester.getTopLeft(find.byType(TextField).first).dy;
      expect(titleY, greaterThan(viewHeight * 0.15));
    },
  );

  testWidgets(
    'description then title keeps title above keyboard in landscape',
    (tester) async {
      // Short landscape viewport + overlay IME (Android Chrome-style).
      const landscapeHeight = 390.0;
      const landscapeWidth = 800.0;
      const landscapeKeyboard = 200.0;
      await pumpComposeSheet(
        tester,
        keyboardBottom: landscapeKeyboard,
        height: landscapeHeight,
        width: landscapeWidth,
      );

      final description = find.byType(TextField).last;
      final title = find.byType(TextField).first;

      // Focus via FocusNode to mimic switching fields after description edit
      // (avoid ensureVisible, which can mask the pad drop).
      tester.widget<TextField>(description).focusNode!.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));
      tester.takeException();

      final descriptionPad = tester
          .widget<AnimatedPadding>(find.byType(AnimatedPadding))
          .padding
          .resolve(TextDirection.ltr)
          .bottom;
      expect(descriptionPad, greaterThan(0));

      tester.widget<TextField>(title).focusNode!.requestFocus();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      tester.takeException();

      final titlePad = tester
          .widget<AnimatedPadding>(find.byType(AnimatedPadding))
          .padding
          .resolve(TextDirection.ltr)
          .bottom;

      final titleBox = tester.renderObject<RenderBox>(title);
      final titleBottom =
          titleBox.localToGlobal(Offset(0, titleBox.size.height)).dy;
      const keyboardTop = landscapeHeight - landscapeKeyboard;

      // Without current-pad projection, title focus would drop the description
      // lift and park the title under the IME (titleBottom >> keyboardTop).
      expect(titlePad, greaterThan(0));
      expect(titleBottom, lessThanOrEqualTo(keyboardTop));
      expect(find.text('Nueva tarea'), findsOneWidget);
      expect(title, findsOneWidget);
    },
  );
}
