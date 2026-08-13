import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';

void main() {
  test('sheetKeyboardBottomInsetFor follows viewInsets on compact Android web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewHeight: 800,
        viewInsetBottom: 320,
        platform: TargetPlatform.android,
      ),
      320,
    );
  });

  test('viewportShrunkForKeyboard detects resize-mode keyboard', () {
    expect(
      viewportShrunkForKeyboard(
        viewHeight: 480,
        viewInsetBottom: 0,
        baselineViewHeight: 800,
      ),
      isTrue,
    );
    expect(
      viewportShrunkForKeyboard(
        viewHeight: 500,
        viewInsetBottom: 280,
        baselineViewHeight: 800,
      ),
      isTrue,
    );
    expect(
      viewportShrunkForKeyboard(
        viewHeight: 780,
        viewInsetBottom: 320,
        baselineViewHeight: 800,
      ),
      isFalse,
    );
  });

  test('sheetKeyboardBottomInsetFor skips inset when viewport resized', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewHeight: 480,
        viewInsetBottom: 0,
        baselineViewHeight: 800,
        platform: TargetPlatform.iOS,
      ),
      0,
    );
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewHeight: 500,
        viewInsetBottom: 280,
        baselineViewHeight: 800,
        platform: TargetPlatform.iOS,
      ),
      0,
    );
  });

  test('focusAwareSheetKeyboardInset skips pad when field clears keyboard', () {
    expect(
      focusAwareSheetKeyboardInset(
        viewInsetBottom: 320,
        viewHeight: 800,
        focusedFieldBottomGlobal: 400,
      ),
      0,
    );
  });

  test('focusAwareSheetKeyboardInset pads when field overlaps keyboard', () {
    expect(
      focusAwareSheetKeyboardInset(
        viewInsetBottom: 320,
        viewHeight: 800,
        focusedFieldBottomGlobal: 550,
      ),
      82,
    );
    expect(
      focusAwareSheetKeyboardInset(
        viewInsetBottom: 320,
        viewHeight: 800,
        focusedFieldBottomGlobal: 900,
      ),
      320,
    );
  });

  test(
    'focusAwareSheetKeyboardInset projects through current pad on focus switch',
    () {
      // Landscape-ish overlay: description lift already applied (pad=72),
      // title global bottom looks clear, but unpadded it still overlaps.
      const viewHeight = 390.0;
      const viewInsetBottom = 200.0;
      const currentPad = 72.0;
      const titleBottomWhileLifted = 170.0;

      expect(
        focusAwareSheetKeyboardInset(
          viewInsetBottom: viewInsetBottom,
          viewHeight: viewHeight,
          focusedFieldBottomGlobal: titleBottomWhileLifted,
        ),
        0,
        reason: 'without current pad, title looks clear (stale geometry)',
      );

      final nextPad = focusAwareSheetKeyboardInset(
        viewInsetBottom: viewInsetBottom,
        viewHeight: viewHeight,
        focusedFieldBottomGlobal: titleBottomWhileLifted,
        currentBottomPad: currentPad,
      );
      expect(nextPad, greaterThan(0));
      expect(nextPad, lessThanOrEqualTo(viewInsetBottom));
      // Unpadded title bottom = 170 + 72 = 242; keyboardTop = 190; +12 clearance.
      expect(nextPad, 64);
    },
  );

  test(
    'sheetKeyboardBottomInsetFor keeps pad when current lift hides overlap',
    () {
      expect(
        sheetKeyboardBottomInsetFor(
          isWeb: true,
          layoutWidth: 800,
          viewHeight: 390,
          viewInsetBottom: 200,
          focusedFieldBottomGlobal: 170,
          currentBottomPad: 72,
          platform: TargetPlatform.android,
        ),
        64,
      );
    },
  );

  test('sheetKeyboardBottomInsetFor is zero when viewport already resized', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewHeight: 800,
        viewInsetBottom: 0,
        platform: TargetPlatform.android,
      ),
      0,
    );
  });

  test('sheetKeyboardBottomInsetFor follows viewInsets on wide web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 1280,
        viewHeight: 800,
        viewInsetBottom: 320,
        platform: TargetPlatform.android,
      ),
      320,
    );
  });

  test('sheetKeyboardBottomInsetFor follows viewInsets on native mobile', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: false,
        layoutWidth: 390,
        viewHeight: 800,
        viewInsetBottom: 320,
        platform: TargetPlatform.iOS,
      ),
      320,
    );
  });

  test('sheetMaxHeightFor shrinks when keyboard overlays viewport', () {
    expect(
      sheetMaxHeightFor(
        viewHeight: 800,
        viewInsetBottom: 320,
        maxHeightFraction: 0.92,
        minHeight: 240,
      ),
      480,
    );
  });

  test('sheetMaxHeightFor uses fraction cap when keyboard is closed', () {
    expect(
      sheetMaxHeightFor(
        viewHeight: 800,
        viewInsetBottom: 0,
        maxHeightFraction: 0.92,
        minHeight: 240,
      ),
      736,
    );
  });

  test('sheetMaxHeightFor never exceeds visible height for minHeight', () {
    expect(
      sheetMaxHeightFor(
        viewHeight: 400,
        viewInsetBottom: 300,
        maxHeightFraction: 0.92,
        minHeight: 240,
      ),
      100,
    );
  });

  test('sheetVisibleHeightFor subtracts keyboard inset', () {
    expect(
      sheetVisibleHeightFor(viewHeight: 800, viewInsetBottom: 320),
      480,
    );
  });
}
