import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Width thresholds for adaptive shell layout.
abstract final class AdaptiveBreakpoints {
  /// Below this width: single-column mobile layout (stack navigation).
  static const double compact = 600;

  /// At or above this width: three-column layout (profile + list + context).
  static const double expanded = 1200;

  static const double profileSidebarWidth = 300;
  static const double contextPanelWidth = 340;

  static AdaptiveLayout layoutForWidth(double width) {
    if (width < compact) return AdaptiveLayout.compact;
    if (width < expanded) return AdaptiveLayout.medium;
    return AdaptiveLayout.expanded;
  }

  static AdaptiveLayout layoutOf(BuildContext context) {
    return layoutForWidth(MediaQuery.sizeOf(context).width);
  }

  /// True on macOS, Windows, Linux, or web — used for mouse-first affordances.
  static bool get isDesktopPlatform {
    if (kIsWeb) return true;
    return switch (defaultTargetPlatform) {
      TargetPlatform.macOS ||
      TargetPlatform.windows ||
      TargetPlatform.linux =>
        true,
      _ => false,
    };
  }

  /// Show explicit settings control (not only long-press) on desktop or wide layouts.
  static bool showDesktopAffordances(BuildContext context) {
    return isDesktopPlatform || layoutOf(context) != AdaptiveLayout.compact;
  }
}

enum AdaptiveLayout {
  /// Phone: full-screen stack navigation.
  compact,

  /// Tablet / narrow desktop: profile sidebar + main list.
  medium,

  /// Wide desktop: profile + list + contextual right panel.
  expanded,
}
