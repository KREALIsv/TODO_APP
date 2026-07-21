import 'package:flutter/material.dart';

import '../../global/themes/app_colors.dart';

/// Theme-aware surface, border and text tokens for cards and panels.
///
/// Prefer these over hardcoded [AppColors.white] so light and dark modes
/// stay in sync with [ColorScheme].
abstract final class AppSurface {
  static ColorScheme scheme(BuildContext context) =>
      Theme.of(context).colorScheme;

  static bool isDark(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark;

  /// Elevated card / list row background.
  static Color card(BuildContext context) =>
      Theme.of(context).cardTheme.color ?? scheme(context).surface;

  static Color border(BuildContext context) => scheme(context).outline;

  static Color divider(BuildContext context) =>
      Theme.of(context).dividerColor;

  /// Semi-transparent chrome for side panels and app bars over list backgrounds.
  static Color panelOverlay(BuildContext context) {
    final isDarkMode = isDark(context);
    return scheme(context).surface.withValues(alpha: isDarkMode ? 0.92 : 0.96);
  }

  static Color title(BuildContext context) => scheme(context).onSurface;

  static Color secondary(BuildContext context) => scheme(context).onSurfaceVariant;

  static Color mutedIcon(BuildContext context) =>
      scheme(context).onSurfaceVariant.withValues(alpha: 0.85);

  /// Heatmap / chart empty cell.
  static Color heatmapEmpty(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? scheme.outlineVariant
          : AppColors.neutral00;

  static BoxDecoration cardDecoration(
    BuildContext context, {
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(12)),
  }) {
    return BoxDecoration(
      color: card(context),
      borderRadius: borderRadius,
      border: Border.all(color: border(context)),
    );
  }
}
