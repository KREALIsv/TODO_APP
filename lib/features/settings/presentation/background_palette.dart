import 'package:flutter/material.dart';

import '../../../global/themes/app_colors.dart';
import '../data/settings_repository.dart';
import '../domain/list_background.dart';

/// Soft / strong companions derived from a list-background accent.
class BackgroundPalette {
  const BackgroundPalette({
    required this.accent,
    required this.soft,
    required this.muted,
    required this.strong,
  });

  final Color accent;
  final Color soft;
  final Color muted;
  final Color strong;

  factory BackgroundPalette.fromAccent(Color accent, Brightness brightness) {
    if (brightness == Brightness.dark) {
      return BackgroundPalette(
        accent: accent,
        soft: Color.lerp(accent, const Color(0xFF1C2128), 0.78)!,
        muted: Color.lerp(accent, const Color(0xFF1C2128), 0.45)!,
        strong: Color.lerp(accent, Colors.white, 0.35)!,
      );
    }
    return BackgroundPalette(
      accent: accent,
      soft: Color.lerp(accent, Colors.white, 0.88)!,
      muted: Color.lerp(accent, Colors.white, 0.62)!,
      strong: Color.lerp(accent, Colors.black, 0.28)!,
    );
  }

  factory BackgroundPalette.of(
    BuildContext context, {
    SettingsRepository? settings,
  }) {
    final repo = settings ?? SettingsRepository.instance;
    final brightness = Theme.of(context).brightness;
    return BackgroundPalette.fromAccent(
      repo.listBackground.resolveAccent(brightness),
      brightness,
    );
  }

  factory BackgroundPalette.fromOption(
    ListBackgroundOption option,
    Brightness brightness,
  ) {
    return BackgroundPalette.fromAccent(
      option.resolveAccent(brightness),
      brightness,
    );
  }

  /// Applies the accent to buttons, FAB, checkboxes and [ColorScheme.primary].
  ThemeData tint(ThemeData base) {
    final scheme = base.colorScheme.copyWith(
      primary: accent,
      onPrimary: AppColors.white,
      primaryContainer: soft,
      onPrimaryContainer: strong,
      secondary: strong,
      onSecondary: AppColors.white,
    );

    return base.copyWith(
      colorScheme: scheme,
      primaryColor: accent,
      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: accent,
        foregroundColor: AppColors.white,
      ),
      checkboxTheme: base.checkboxTheme.copyWith(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accent;
          return scheme.surface;
        }),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.outline;
            }
            return accent;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.white),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return scheme.outline;
            }
            return accent;
          }),
          foregroundColor: WidgetStateProperty.all(AppColors.white),
          elevation: WidgetStateProperty.all(0),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.all(accent),
          side: WidgetStateProperty.all(BorderSide(color: accent)),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: accent),
      inputDecorationTheme: base.inputDecorationTheme.copyWith(
        floatingLabelStyle: TextStyle(
          color: accent,
          fontWeight: FontWeight.w600,
        ),
        focusedBorder: (base.inputDecorationTheme.focusedBorder
                    as OutlineInputBorder?)
                ?.copyWith(borderSide: BorderSide(color: accent, width: 2)) ??
            OutlineInputBorder(
              borderSide: BorderSide(color: accent, width: 2),
            ),
      ),
    );
  }
}
