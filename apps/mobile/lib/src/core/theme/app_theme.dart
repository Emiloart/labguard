import 'package:flutter/material.dart';

import 'app_colors.dart';

abstract final class AppTheme {
  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      primary: LabGuardColors.accent,
      secondary: LabGuardColors.success,
      surface: LabGuardColors.panel,
      error: LabGuardColors.danger,
      onPrimary: LabGuardColors.background,
      onSecondary: LabGuardColors.background,
      onSurface: LabGuardColors.textPrimary,
      onError: LabGuardColors.textPrimary,
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: LabGuardColors.background,
      dividerColor: LabGuardColors.border,
    );

    return base.copyWith(
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: LabGuardColors.textPrimary,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: base.textTheme
          .apply(
            bodyColor: LabGuardColors.textPrimary,
            displayColor: LabGuardColors.textPrimary,
          )
          .copyWith(
            displaySmall: base.textTheme.displaySmall?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: -1.2,
            ),
            headlineMedium: base.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
            titleLarge: base.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.2,
            ),
            bodyLarge: base.textTheme.bodyLarge?.copyWith(
              color: LabGuardColors.textPrimary,
              height: 1.4,
            ),
            bodyMedium: base.textTheme.bodyMedium?.copyWith(
              color: LabGuardColors.textSecondary,
              height: 1.4,
            ),
          ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: LabGuardColors.accent,
          foregroundColor: LabGuardColors.background,
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: LabGuardColors.textPrimary,
          side: const BorderSide(color: LabGuardColors.border),
          minimumSize: const Size.fromHeight(54),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: LabGuardColors.panel,
        hintStyle: const TextStyle(color: LabGuardColors.textSecondary),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: LabGuardColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: LabGuardColors.accent),
          borderRadius: BorderRadius.circular(18),
        ),
        border: OutlineInputBorder(
          borderSide: const BorderSide(color: LabGuardColors.border),
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: LabGuardColors.panel,
        indicatorColor: LabGuardColors.accentMuted,
        height: 74,
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => TextStyle(
            color: states.contains(WidgetState.selected)
                ? LabGuardColors.textPrimary
                : LabGuardColors.textSecondary,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? LabGuardColors.background
              : LabGuardColors.textSecondary,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? LabGuardColors.accent
              : LabGuardColors.border,
        ),
      ),
    );
  }
}
