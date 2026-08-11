import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Whether the layout viewport already shrank for the software keyboard
/// (`interactive-widget=resizes-content` on web, or native resize).
///
/// When true, [MediaQuery.viewInsets] padding would double-shift sheet content.
bool viewportShrunkForKeyboard({
  required double viewHeight,
  required double viewInsetBottom,
  double? baselineViewHeight,
  double shrinkThreshold = 48,
}) {
  if (baselineViewHeight == null) return false;
  final shrink = baselineViewHeight - viewHeight;
  if (shrink < shrinkThreshold) return false;
  // Resized viewport: insets are usually zero; some WebKit builds also report
  // both shrink and a non-zero inset — still prefer the resize signal.
  return viewInsetBottom < shrinkThreshold || shrink >= viewInsetBottom * 0.5;
}

/// Bottom inset for modal sheets that must clear the software keyboard.
///
/// Prefer Flutter's [MediaQuery.viewInsets]:
/// - When the viewport already shrank for the keyboard, returns `0`.
/// - When the keyboard overlays (common on Android Chrome), uses
///   [viewInsetBottom], optionally reduced via [focusedFieldBottomGlobal] so
///   fields already above the IME do not lift the whole sheet.
double sheetKeyboardBottomInsetFor({
  required bool isWeb,
  required double layoutWidth,
  required double viewHeight,
  required double viewInsetBottom,
  double? baselineViewHeight,
  double? focusedFieldBottomGlobal,
  TargetPlatform platform = TargetPlatform.android,
  double clearance = 12,
}) {
  if (viewInsetBottom <= 0) return 0;
  if (viewportShrunkForKeyboard(
    viewHeight: viewHeight,
    viewInsetBottom: viewInsetBottom,
    baselineViewHeight: baselineViewHeight,
  )) {
    return 0;
  }
  return focusAwareSheetKeyboardInset(
    viewInsetBottom: viewInsetBottom,
    viewHeight: viewHeight,
    focusedFieldBottomGlobal: focusedFieldBottomGlobal,
    clearance: clearance,
  );
}

/// Keyboard padding needed so [focusedFieldBottomGlobal] clears the IME.
///
/// When the focused field is already above the keyboard, returns `0` instead of
/// lifting the whole sheet (fixes title-focus over-elevation on Android).
/// When [focusedFieldBottomGlobal] is null, returns the full [viewInsetBottom].
double focusAwareSheetKeyboardInset({
  required double viewInsetBottom,
  required double viewHeight,
  double? focusedFieldBottomGlobal,
  double clearance = 12,
}) {
  if (viewInsetBottom <= 0) return 0;
  if (focusedFieldBottomGlobal == null) return viewInsetBottom;

  final keyboardTop = viewHeight - viewInsetBottom;
  if (focusedFieldBottomGlobal <= keyboardTop - clearance) {
    return 0;
  }
  final overlap = focusedFieldBottomGlobal + clearance - keyboardTop;
  return overlap.clamp(0.0, viewInsetBottom);
}

double sheetKeyboardBottomInset(
  BuildContext context, {
  double? baselineViewHeight,
  double? focusedFieldBottomGlobal,
}) {
  final media = MediaQuery.of(context);
  return sheetKeyboardBottomInsetFor(
    isWeb: kIsWeb,
    layoutWidth: media.size.width,
    viewHeight: media.size.height,
    viewInsetBottom: media.viewInsets.bottom,
    baselineViewHeight: baselineViewHeight,
    focusedFieldBottomGlobal: focusedFieldBottomGlobal,
    platform: defaultTargetPlatform,
  );
}

/// Layout height still visible above the software keyboard.
double sheetVisibleHeightFor({
  required double viewHeight,
  required double viewInsetBottom,
}) {
  return (viewHeight - viewInsetBottom).clamp(0.0, viewHeight);
}

/// Max height for a scroll-controlled bottom sheet above the keyboard.
///
/// Uses the visible viewport (`viewHeight - keyboard inset`), capped at
/// [maxHeightFraction] of the full [viewHeight]. Optional [minHeight] keeps
/// small sheets usable on short viewports, but never exceeds the visible
/// height (forcing taller than the keyboard-safe area causes overflow).
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
  if (minHeight <= 0 || maxHeight < minHeight) return maxHeight;
  return maxHeight.clamp(minHeight, cap);
}

double sheetMaxHeight(
  BuildContext context, {
  double maxHeightFraction = 0.92,
  double minHeight = 0,
  double? baselineViewHeight,
}) {
  final media = MediaQuery.of(context);
  final obstruction = sheetKeyboardBottomInsetFor(
    isWeb: kIsWeb,
    layoutWidth: media.size.width,
    viewHeight: media.size.height,
    viewInsetBottom: media.viewInsets.bottom,
    baselineViewHeight: baselineViewHeight,
    platform: defaultTargetPlatform,
  );
  // Cap height using full IME obstruction when overlaying, not focus-aware pad.
  final layoutObstruction = media.viewInsets.bottom > 0 &&
          !viewportShrunkForKeyboard(
            viewHeight: media.size.height,
            viewInsetBottom: media.viewInsets.bottom,
            baselineViewHeight: baselineViewHeight,
          )
      ? media.viewInsets.bottom
      : obstruction;

  return sheetMaxHeightFor(
    viewHeight: media.size.height,
    viewInsetBottom: layoutObstruction,
    maxHeightFraction: maxHeightFraction,
    minHeight: minHeight,
  );
}

/// Height for fixed-ratio sheets (e.g. tags picker) above the keyboard.
double sheetFixedHeight(
  BuildContext context, {
  required double heightFraction,
  double? baselineViewHeight,
}) {
  final media = MediaQuery.of(context);
  final obstruction = media.viewInsets.bottom > 0 &&
          !viewportShrunkForKeyboard(
            viewHeight: media.size.height,
            viewInsetBottom: media.viewInsets.bottom,
            baselineViewHeight: baselineViewHeight,
          )
      ? media.viewInsets.bottom
      : sheetKeyboardBottomInset(
          context,
          baselineViewHeight: baselineViewHeight,
        );
  final visibleHeight = sheetVisibleHeightFor(
    viewHeight: media.size.height,
    viewInsetBottom: obstruction,
  );
  return visibleHeight * heightFraction;
}

/// Global Y of the bottom edge of [fieldKey], or null when not laid out.
double? globalFieldBottom(GlobalKey fieldKey) {
  final context = fieldKey.currentContext;
  if (context == null) return null;
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize) return null;
  return box.localToGlobal(Offset(0, box.size.height)).dy;
}
