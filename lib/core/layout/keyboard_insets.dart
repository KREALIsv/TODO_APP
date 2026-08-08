import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Bottom inset for modal sheets that must clear the software keyboard.
///
/// Prefer Flutter's [MediaQuery.viewInsets]:
/// - With `interactive-widget=resizes-content` (see `web/index.html`), when the
///   layout viewport already shrank for the keyboard, [viewInsetBottom] is
///   typically `0` — no extra padding.
/// - When the keyboard overlays instead (common on Android Chrome / some iOS
///   browsers), [viewInsetBottom] carries the height we must pad so fields
///   like the compose description stay visible.
///
/// [layoutWidth] is retained for call-site compatibility / future heuristics.
double sheetKeyboardBottomInsetFor({
  required bool isWeb,
  required double layoutWidth,
  required double viewInsetBottom,
}) {
  return viewInsetBottom;
}

double sheetKeyboardBottomInset(BuildContext context) {
  return sheetKeyboardBottomInsetFor(
    isWeb: kIsWeb,
    layoutWidth: MediaQuery.sizeOf(context).width,
    viewInsetBottom: MediaQuery.viewInsetsOf(context).bottom,
  );
}
