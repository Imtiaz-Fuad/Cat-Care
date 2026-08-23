import 'package:flutter/material.dart';

/// Base theme for CatCare BD per docs/catcare.design §7.
///
/// The cat-photo-derived accent (Phase 3) is applied as a small override on
/// top of this stable base. Body text and accessibility-critical colors are
/// never replaced.
class AppTheme {
  AppTheme._();

  // Base palette (sage / teal primary + warm peach secondary).
  static const Color _seedSage = Color(0xFF6E8E7E);
  static const Color _seedPeach = Color(0xFFE9B59B);
  static const Color _ivory = Color(0xFFFDF8F3);
  static const Color _warmWhite = Color(0xFFFFFDFA);
  static const Color _deepCharcoal = Color(0xFF2A2A2E);
  static const Color _warmGray = Color(0xFF6B6B70);

  // Semantic colors (independent of cat-derived accent).
  static const Color success = Color(0xFF4F9D69);
  static const Color warning = Color(0xFFE6A23C);
  static const Color error = Color(0xFFD9534F);
  static const Color info = Color(0xFF4A90E2);

  static ThemeData light() {
    final ColorScheme scheme =
        ColorScheme.fromSeed(
          seedColor: _seedSage,
          brightness: Brightness.light,
          secondary: _seedPeach,
          surface: _warmWhite,
        ).copyWith(
          surface: _warmWhite,
          onSurface: _deepCharcoal,
          onSurfaceVariant: _warmGray,
        );

    return _build(scheme, _ivory);
  }

  static ThemeData dark() {
    final ColorScheme scheme = ColorScheme.fromSeed(
      seedColor: _seedSage,
      brightness: Brightness.dark,
      secondary: _seedPeach,
      surface: const Color(0xFF2A1F18),
      onSurface: const Color(0xFFF1E6DA),
    );
    return _build(scheme, const Color(0xFF221A14));
  }

  static ThemeData _build(ColorScheme scheme, Color background) {
    final TextTheme text = ThemeData.light().textTheme.apply(
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      textTheme: text.copyWith(
        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: text.titleLarge?.copyWith(fontWeight: FontWeight.w600),
        bodyLarge: text.bodyLarge?.copyWith(height: 1.4),
        bodyMedium: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
        ),
        margin: EdgeInsets.zero,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.outlineVariant),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: scheme.primary, width: 1.6),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),
        labelTextStyle: WidgetStatePropertyAll(
          text.labelMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
      ),
      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}
