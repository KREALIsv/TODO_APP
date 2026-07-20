import 'package:flutter/material.dart';

import '../../global/themes/theme.dart' show AppThemes;

class AppTheme {
  AppTheme._();

  static ThemeData light() => AppThemes.lightTheme;

  static ThemeData dark() => AppThemes.darkTheme;
}
