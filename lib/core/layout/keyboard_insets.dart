import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'adaptive_breakpoints.dart';

/// Bottom inset for modal sheets that must clear the software keyboard.
///
/// On compact mobile web, [index.html] uses
/// `interactive-widget=resizes-content`, so the layout viewport already shrinks
/// when the keyboard opens. Applying [MediaQuery.viewInsets] padding there
/// would shift sheet content twice and make text fields drift with the
/// keyboard.
double sheetKeyboardBottomInsetFor({
  required bool isWeb,
  required double layoutWidth,
  required double viewInsetBottom,
}) {
  if (isWeb && layoutWidth < AdaptiveBreakpoints.compact) {
    return 0;
  }
  return viewInsetBottom;
}

double sheetKeyboardBottomInset(BuildContext context) {
  return sheetKeyboardBottomInsetFor(
    isWeb: kIsWeb,
    layoutWidth: MediaQuery.sizeOf(context).width,
    viewInsetBottom: MediaQuery.viewInsetsOf(context).bottom,
  );
}
