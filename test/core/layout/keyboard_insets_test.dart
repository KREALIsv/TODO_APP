import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';

void main() {
  test('sheetKeyboardBottomInsetFor follows viewInsets on compact mobile web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 320,
      ),
      320,
    );
  });

  test('sheetKeyboardBottomInsetFor is zero when viewport already resized', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 0,
      ),
      0,
    );
  });

  test('sheetKeyboardBottomInsetFor follows viewInsets on wide web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 1280,
        viewInsetBottom: 320,
      ),
      320,
    );
  });

  test('sheetKeyboardBottomInsetFor follows viewInsets on native mobile', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: false,
        layoutWidth: 390,
        viewInsetBottom: 320,
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

  test('sheetVisibleHeightFor subtracts keyboard inset', () {
    expect(
      sheetVisibleHeightFor(viewHeight: 800, viewInsetBottom: 320),
      480,
    );
  });
}
