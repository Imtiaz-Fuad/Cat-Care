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
    final ColorScheme scheme = ColorScheme.fromSeed(
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
      fontFamily: 'Nunito',
      bodyColor: scheme.onSurface,
      displayColor: scheme.onSurface,
    );

    return ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      fontFamily: 'Nunito',
      scaffoldBackgroundColor: background,

      // ============================================================
      // TYPOGRAPHY
      // ============================================================
      //
      // Headlines / titles: Nunito Bold 700
      // Body / labels: Nunito Regular 400
      //
      // All text sizes are increased by approximately 6%.
      // ============================================================

      textTheme: text.copyWith(
        // ------------------------------------------------------------
        // DISPLAY — Bold 700
        // ------------------------------------------------------------

        displayLarge: text.displayLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.displayLarge?.fontSize ?? 57) * 1.06,
        ),

        displayMedium: text.displayMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.displayMedium?.fontSize ?? 45) * 1.06,
        ),

        displaySmall: text.displaySmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.displaySmall?.fontSize ?? 36) * 1.06,
        ),

        // ------------------------------------------------------------
        // HEADLINES — Bold 700
        // ------------------------------------------------------------

        headlineLarge: text.headlineLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.headlineLarge?.fontSize ?? 32) * 1.06,
          letterSpacing: -0.2,
        ),

        headlineMedium: text.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.headlineMedium?.fontSize ?? 28) * 1.06,
          letterSpacing: -0.2,
        ),

        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.headlineSmall?.fontSize ?? 24) * 1.06,
        ),

        // ------------------------------------------------------------
        // TITLES — Bold 700
        // ------------------------------------------------------------

        titleLarge: text.titleLarge?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.titleLarge?.fontSize ?? 22) * 1.06,
        ),

        titleMedium: text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.titleMedium?.fontSize ?? 16) * 1.06,
        ),

        titleSmall: text.titleSmall?.copyWith(
          fontWeight: FontWeight.w700,
          fontSize: (text.titleSmall?.fontSize ?? 14) * 1.06,
        ),

        // ------------------------------------------------------------
        // BODY — Regular 400
        // ------------------------------------------------------------

        bodyLarge: text.bodyLarge?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.bodyLarge?.fontSize ?? 16) * 1.06,
          height: 1.4,
        ),

        bodyMedium: text.bodyMedium?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.bodyMedium?.fontSize ?? 14) * 1.06,
          color: scheme.onSurfaceVariant,
        ),

        bodySmall: text.bodySmall?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.bodySmall?.fontSize ?? 12) * 1.06,
        ),

        // ------------------------------------------------------------
        // LABELS — Regular 400
        // ------------------------------------------------------------

        labelLarge: text.labelLarge?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.labelLarge?.fontSize ?? 14) * 1.06,
        ),

        labelMedium: text.labelMedium?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.labelMedium?.fontSize ?? 12) * 1.06,
        ),

        labelSmall: text.labelSmall?.copyWith(
          fontWeight: FontWeight.w400,
          fontSize: (text.labelSmall?.fontSize ?? 11) * 1.06,
        ),
      ),

      // ============================================================
      // CARDS
      // ============================================================

      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: scheme.outlineVariant.withValues(alpha: 0.4),
          ),
        ),
        margin: EdgeInsets.zero,
      ),

      // ============================================================
      // FILLED BUTTONS
      // ============================================================

      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
        ),
      ),

      // ============================================================
      // OUTLINED BUTTONS
      // ============================================================

      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          textStyle: const TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w400,
            fontSize: 15,
          ),
        ),
      ),

      // ============================================================
      // INPUT FIELDS
      // ============================================================

      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surface,

        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),

        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.outlineVariant,
          ),
        ),

        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(
            color: scheme.primary,
            width: 1.6,
          ),
        ),

        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),

      // ============================================================
      // NAVIGATION BAR
      // ============================================================

      navigationBarTheme: NavigationBarThemeData(
        height: 68,
        backgroundColor: scheme.surface,
        indicatorColor: scheme.primary.withValues(alpha: 0.12),

        labelTextStyle: WidgetStatePropertyAll(
          TextStyle(
            fontFamily: 'Nunito',
            fontWeight: FontWeight.w400,
            fontSize: 13,
          ),
        ),
      ),

      // ============================================================
      // APP BAR
      // ============================================================

      appBarTheme: AppBarTheme(
        backgroundColor: background,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,

        titleTextStyle: TextStyle(
          fontFamily: 'Nunito',
          fontWeight: FontWeight.w700,
          fontSize: 22,
          color: scheme.onSurface,
        ),
      ),

      // ============================================================
      // DIVIDERS
      // ============================================================

      dividerTheme: DividerThemeData(
        color: scheme.outlineVariant.withValues(alpha: 0.5),
        space: 1,
      ),
    );
  }
}
