import 'package:flutter/material.dart';

sealed class ThemeTokens {
  static const double padding = 8.0;
  static const double appRadius = 12.0;
  static const BorderRadius borderRadius =
      BorderRadius.all(Radius.circular(appRadius));
  static const OutlinedBorder buttonsShape = RoundedRectangleBorder(
    borderRadius: borderRadius,
  );
  static const double outlineWidth = 1.0;
  static const double outlineInputFocusedWidth = 2.0;
}
