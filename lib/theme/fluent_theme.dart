import 'package:flutter/material.dart';

/// WinUI 3 Fluent Design Tokens for Light and Dark modes.
/// Resolves dynamically via [FluentColors.of(context)] to prevent static token pitfalls.
class FluentColors {
  final Color canvas;
  final Color cardSurface;
  final Color container;
  final Color containerHigh;
  final Color border;
  final Color borderSubtle;
  final Color primary;
  final Color primaryHover;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color selectionFill;
  final Color selectionStroke;
  final Color error;
  final Color warning;
  final Color success;

  const FluentColors({
    required this.canvas,
    required this.cardSurface,
    required this.container,
    required this.containerHigh,
    required this.border,
    required this.borderSubtle,
    required this.primary,
    required this.primaryHover,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.selectionFill,
    required this.selectionStroke,
    required this.error,
    required this.warning,
    required this.success,
  });

  static const light = FluentColors(
    canvas: Color(0xFFF3F3F3),
    cardSurface: Color(0xFFFFFFFF),
    container: Color(0xFFEBEBEB),
    containerHigh: Color(0xFFE0E0E0),
    border: Color(0xFFD1D5DB),
    borderSubtle: Color(0xFFE5E7EB),
    primary: Color(0xFF0067B8),
    primaryHover: Color(0xFF0078D4),
    textPrimary: Color(0xFF1E1E1E),
    textSecondary: Color(0xFF5C5C5C),
    textMuted: Color(0xFF8A8A8A),
    selectionFill: Color(0x1A0067B8),
    selectionStroke: Color(0xFF0067B8),
    error: Color(0xFFBA1A1A),
    warning: Color(0xFFD97706),
    success: Color(0xFF107C41),
  );

  static const dark = FluentColors(
    canvas: Color(0xFF1F1F1F),
    cardSurface: Color(0xFF2B2B2B),
    container: Color(0xFF262626),
    containerHigh: Color(0xFF333333),
    border: Color(0xFF3D3D3D),
    borderSubtle: Color(0xFF333333),
    primary: Color(0xFF4CC2FF),
    primaryHover: Color(0xFF60CDFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD0D0D0),
    textMuted: Color(0xFF8A8A8A),
    selectionFill: Color(0x334CC2FF),
    selectionStroke: Color(0xFF4CC2FF),
    error: Color(0xFFFFB4AB),
    warning: Color(0xFFFBBF24),
    success: Color(0xFF4EDE9F),
  );

  static const amoled = FluentColors(
    canvas: Color(0xFF000000),
    cardSurface: Color(0xFF0C0C0C),
    container: Color(0xFF121212),
    containerHigh: Color(0xFF181818),
    border: Color(0xFF262626),
    borderSubtle: Color(0xFF1A1A1A),
    primary: Color(0xFF4CC2FF),
    primaryHover: Color(0xFF60CDFF),
    textPrimary: Color(0xFFFFFFFF),
    textSecondary: Color(0xFFD0D0D0),
    textMuted: Color(0xFF7A7A7A),
    selectionFill: Color(0x334CC2FF),
    selectionStroke: Color(0xFF4CC2FF),
    error: Color(0xFFFFB4AB),
    warning: Color(0xFFFBBF24),
    success: Color(0xFF4EDE9F),
  );

  static FluentColors of(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    if (!isDark) return light;
    if (theme.scaffoldBackgroundColor == const Color(0xFF000000)) {
      return amoled;
    }
    return dark;
  }
}

class FluentTheme {
  static ThemeData lightTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: FluentColors.light.canvas,
      colorScheme: ColorScheme.light(
        primary: FluentColors.light.primary,
        surface: FluentColors.light.cardSurface,
        onSurface: FluentColors.light.textPrimary,
        outline: FluentColors.light.border,
      ),
      fontFamily: 'Segoe UI',
      dividerTheme: const DividerThemeData(
        color: Color(0xFFE5E7EB),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  static ThemeData darkTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FluentColors.dark.canvas,
      colorScheme: ColorScheme.dark(
        primary: FluentColors.dark.primary,
        surface: FluentColors.dark.cardSurface,
        onSurface: FluentColors.dark.textPrimary,
        outline: FluentColors.dark.border,
      ),
      fontFamily: 'Segoe UI',
      dividerTheme: const DividerThemeData(
        color: Color(0xFF3D3D3D),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF333333),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }

  static ThemeData amoledTheme() {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: FluentColors.amoled.canvas,
      colorScheme: ColorScheme.dark(
        primary: FluentColors.amoled.primary,
        surface: FluentColors.amoled.cardSurface,
        onSurface: FluentColors.amoled.textPrimary,
        outline: FluentColors.amoled.border,
      ),
      fontFamily: 'Segoe UI',
      dividerTheme: const DividerThemeData(
        color: Color(0xFF222222),
        thickness: 1,
        space: 1,
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: const Color(0xFF141414),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: Colors.white, fontSize: 12),
        waitDuration: const Duration(milliseconds: 400),
      ),
    );
  }
}
