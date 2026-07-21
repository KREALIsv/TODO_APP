import 'package:flutter_test/flutter_test.dart';
import 'package:todos_app/core/layout/keyboard_insets.dart';

void main() {
  test('sheetKeyboardBottomInsetFor is zero on compact mobile web', () {
    expect(
      sheetKeyboardBottomInsetFor(
        isWeb: true,
        layoutWidth: 390,
        viewInsetBottom: 320,
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
}
