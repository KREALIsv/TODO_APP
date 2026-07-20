import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'color_scheme.dart';
import 'tokens.dart';

const String _fontFamily = 'Inter';

const Set<WidgetState> _interactiveStates = <WidgetState>{
  WidgetState.pressed,
  WidgetState.hovered,
  WidgetState.focused,
};

class AppThemes {
  static const InputDecorationTheme inputDecorationTheme = InputDecorationTheme(
    filled: true,
    fillColor: AppColors.white,
    floatingLabelStyle: TextStyle(
      color: AppColors.primary,
      fontWeight: FontWeight.w600,
      fontFamily: _fontFamily,
    ),
    labelStyle: TextStyle(
      color: AppColors.neutral60,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    hintStyle: TextStyle(
      color: AppColors.neutral40,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    errorStyle: TextStyle(
      color: AppColors.error,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: BorderSide(
        color: AppColors.neutral20,
        width: ThemeTokens.outlineWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: BorderSide(
        color: AppColors.primary,
        width: ThemeTokens.outlineInputFocusedWidth,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: BorderSide(
        color: AppColors.error,
        width: ThemeTokens.outlineInputFocusedWidth,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: BorderSide(color: AppColors.neutral20),
    ),
    iconColor: AppColors.neutral60,
    prefixIconColor: AppColors.neutral60,
    suffixIconColor: AppColors.neutral60,
  );

  static final lightTheme = ThemeData(
    useMaterial3: true,
    colorScheme: appColorScheme,
    fontFamily: _fontFamily,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    brightness: Brightness.light,
    primaryColor: AppColors.primary,
    scaffoldBackgroundColor: AppColors.neutral00,
    dividerColor: AppColors.neutral20,
    appBarTheme: const AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: AppColors.white,
      foregroundColor: AppColors.black,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: AppColors.black),
      titleTextStyle: TextStyle(
        color: AppColors.black,
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: inputDecorationTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.neutral20;
          }
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.white),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return AppColors.neutral20;
          }
          if (states.any(_interactiveStates.contains)) {
            return AppColors.secondary;
          }
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.white),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
        elevation: WidgetStateProperty.all<double>(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.primary),
        side: WidgetStateProperty.all<BorderSide>(
          const BorderSide(color: AppColors.primary),
        ),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all<Color>(AppColors.white),
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return AppColors.white;
      }),
      side: const BorderSide(color: AppColors.neutral40),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: AppColors.white,
      shape: RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
        side: const BorderSide(color: AppColors.neutral20),
      ),
    ),
    textTheme: const TextTheme(
      // Headline
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.black,
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
      // Body
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.black,
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.neutral80,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.neutral60,
      ),
      // Label
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.black,
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.neutral80,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.neutral60,
      ),
    ),
  );

  static final InputDecorationTheme _darkInputDecorationTheme =
      InputDecorationTheme(
    filled: true,
    fillColor: const Color(0xFF2D333B),
    floatingLabelStyle: const TextStyle(
      color: AppColors.primary40,
      fontWeight: FontWeight.w600,
      fontFamily: _fontFamily,
    ),
    labelStyle: const TextStyle(
      color: AppColors.neutral40,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    hintStyle: const TextStyle(
      color: AppColors.neutral60,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    errorStyle: const TextStyle(
      color: AppColors.error,
      fontWeight: FontWeight.w400,
      fontFamily: _fontFamily,
    ),
    contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
    enabledBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: const BorderSide(
        color: Color(0xFF444C56),
        width: ThemeTokens.outlineWidth,
      ),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: const BorderSide(
        color: AppColors.primary40,
        width: ThemeTokens.outlineInputFocusedWidth,
      ),
    ),
    errorBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: const BorderSide(color: AppColors.error),
    ),
    focusedErrorBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: const BorderSide(
        color: AppColors.error,
        width: ThemeTokens.outlineInputFocusedWidth,
      ),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: ThemeTokens.borderRadius,
      borderSide: const BorderSide(color: Color(0xFF444C56)),
    ),
    iconColor: AppColors.neutral40,
    prefixIconColor: AppColors.neutral40,
    suffixIconColor: AppColors.neutral40,
  );

  static final darkTheme = ThemeData(
    useMaterial3: true,
    colorScheme: appDarkColorScheme,
    fontFamily: _fontFamily,
    splashColor: Colors.transparent,
    highlightColor: Colors.transparent,
    brightness: Brightness.dark,
    primaryColor: AppColors.primary40,
    scaffoldBackgroundColor: const Color(0xFF1C2128),
    dividerColor: const Color(0xFF444C56),
    appBarTheme: const AppBarTheme(
      surfaceTintColor: Colors.transparent,
      backgroundColor: Color(0xFF1C2128),
      foregroundColor: Color(0xFFE6EDF3),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFFE6EDF3)),
      titleTextStyle: TextStyle(
        color: Color(0xFFE6EDF3),
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
      ),
    ),
    inputDecorationTheme: _darkInputDecorationTheme,
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF444C56);
          }
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.white),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        backgroundColor: WidgetStateProperty.resolveWith<Color>((states) {
          if (states.contains(WidgetState.disabled)) {
            return const Color(0xFF444C56);
          }
          if (states.any(_interactiveStates.contains)) {
            return AppColors.secondary;
          }
          return AppColors.primary;
        }),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.white),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
        elevation: WidgetStateProperty.all<double>(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        minimumSize: WidgetStateProperty.all<Size>(const Size(100, 48)),
        foregroundColor: WidgetStateProperty.all<Color>(AppColors.primary40),
        side: WidgetStateProperty.all<BorderSide>(
          const BorderSide(color: AppColors.primary40),
        ),
        shape: WidgetStateProperty.all<OutlinedBorder>(ThemeTokens.buttonsShape),
      ),
    ),
    checkboxTheme: CheckboxThemeData(
      checkColor: WidgetStateProperty.all<Color>(AppColors.white),
      fillColor: WidgetStateProperty.resolveWith<Color?>((states) {
        if (states.contains(WidgetState.selected)) {
          return AppColors.primary;
        }
        return const Color(0xFF2D333B);
      }),
      side: const BorderSide(color: AppColors.neutral40),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: AppColors.primary,
      foregroundColor: AppColors.white,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF2D333B),
      shape: RoundedRectangleBorder(
        borderRadius: ThemeTokens.borderRadius,
        side: const BorderSide(color: Color(0xFF444C56)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: Color(0xFFE6EDF3),
      ),
      headlineMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE6EDF3),
      ),
      headlineSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE6EDF3),
      ),
      bodyLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: Color(0xFFE6EDF3),
      ),
      bodyMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.neutral40,
      ),
      bodySmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.neutral60,
      ),
      labelLarge: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: Color(0xFFE6EDF3),
      ),
      labelMedium: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.neutral40,
      ),
      labelSmall: TextStyle(
        fontFamily: _fontFamily,
        fontSize: 11,
        fontWeight: FontWeight.w500,
        color: AppColors.neutral60,
      ),
    ),
  );
}
