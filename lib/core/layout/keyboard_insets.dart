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

/// Layout height still visible above the software keyboard.
double sheetVisibleHeightFor({
  required double viewHeight,
  required double viewInsetBottom,
}) {
  return viewHeight - viewInsetBottom;
}

/// Max height for a scroll-controlled bottom sheet above the keyboard.
///
/// Uses the visible viewport (`viewHeight - keyboard inset`), capped at
/// [maxHeightFraction] of the full [viewHeight]. Optional [minHeight] keeps
/// small sheets usable on short viewports.
double sheetMaxHeightFor({
  required double viewHeight,
  required double viewInsetBottom,
  double maxHeightFraction = 0.92,
  double minHeight = 0,
}) {
  final visibleHeight = sheetVisibleHeightFor(
    viewHeight: viewHeight,
    viewInsetBottom: viewInsetBottom,
  );
  final cap = viewHeight * maxHeightFraction;
  final maxHeight = visibleHeight > cap ? cap : visibleHeight;
  if (minHeight <= 0) return maxHeight;
  return maxHeight.clamp(minHeight, cap);
}

double sheetMaxHeight(
  BuildContext context, {
  double maxHeightFraction = 0.92,
  double minHeight = 0,
}) {
  final viewHeight = MediaQuery.sizeOf(context).height;
  return sheetMaxHeightFor(
    viewHeight: viewHeight,
    viewInsetBottom: sheetKeyboardBottomInset(context),
    maxHeightFraction: maxHeightFraction,
    minHeight: minHeight,
  );
}

/// Height for fixed-ratio sheets (e.g. tags picker) above the keyboard.
double sheetFixedHeight(
  BuildContext context, {
  required double heightFraction,
}) {
  final viewHeight = MediaQuery.sizeOf(context).height;
  final visibleHeight = sheetVisibleHeightFor(
    viewHeight: viewHeight,
    viewInsetBottom: sheetKeyboardBottomInset(context),
  );
  return visibleHeight * heightFraction;
}
