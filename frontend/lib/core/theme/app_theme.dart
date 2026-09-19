import 'package:flutter/material.dart';

import 'app_colors.dart';

class AppTheme {
  static ThemeData light() => _build(
        brightness: Brightness.light,
        colors: TradePulseColors.light,
        onSurface: const Color(0xFF102033),
      );

  static ThemeData dark() => _build(
        brightness: Brightness.dark,
        colors: TradePulseColors.dark,
        onSurface: const Color(0xFFF4F7FF),
      );

  static ThemeData _build({
    required Brightness brightness,
    required TradePulseColors colors,
    required Color onSurface,
  }) {
    final scheme = ColorScheme(
      brightness: brightness,
      primary: colors.accent,
      onPrimary: const Color(0xFF06201C),
      secondary: colors.accentSecondary,
      onSecondary: Colors.white,
      error: colors.danger,
      onError: Colors.white,
      surface: colors.canvas,
      onSurface: onSurface,
      onSurfaceVariant: colors.mutedText,
      outline: colors.cardBorder,
      surfaceContainerHighest: colors.card,
      tertiary: colors.accentSecondary,
      onTertiary: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: scheme,
      scaffoldBackgroundColor: colors.canvas,
      canvasColor: colors.canvas,
      extensions: [colors],
      visualDensity: VisualDensity.standard,
      dividerColor: colors.cardBorder.withValues(alpha: 0.7),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: colors.card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(color: colors.cardBorder),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: colors.canvasAlt,
        selectedColor: colors.accent.withValues(alpha: 0.18),
        labelStyle: TextStyle(color: onSurface),
        side: BorderSide(color: colors.cardBorder),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colors.inputFill,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.accent, width: 1.4),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colors.danger),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colors.accent,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: onSurface,
          side: BorderSide(color: colors.cardBorder),
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: colors.accent),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: colors.sidebar,
        indicatorColor: colors.accent.withValues(alpha: 0.18),
        height: 72,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colors.card,
        contentTextStyle: TextStyle(color: onSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.linux: FadeUpwardsPageTransitionsBuilder(),
          TargetPlatform.macOS: FadeUpwardsPageTransitionsBuilder(),
        },
      ),
    );
  }
}
