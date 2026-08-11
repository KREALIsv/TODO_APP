import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';

void main() {
  test('sheetKeyboardBottomInsetFor follows viewInsets on compact Android web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 320,
        platform: TargetPlatform.android,
      ),
      320,
    );
  });

  test('sheetKeyboardBottomInsetFor zeros Apple web to avoid double-shift', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 320,
        platform: TargetPlatform.iOS,
      ),
      0,
    );
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 320,
        platform: TargetPlatform.macOS,
      ),
      0,
    );
  });

  test('sheetKeyboardBottomInsetFor is zero when viewport already resized', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
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
