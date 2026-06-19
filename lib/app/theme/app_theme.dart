import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF6C63FF);

  /// Shared input/card/navigation styling applied to both light and dark.
  static ThemeData _base(Brightness brightness) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: brightness,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: colorScheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: colorScheme.onSurface,
          letterSpacing: -0.3,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colorScheme.outlineVariant,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 12,
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        indicatorColor: colorScheme.primaryContainer,
      ),
    );
  }

  static ThemeData dark() => _base(Brightness.dark);
  static ThemeData light() => _base(Brightness.light);
}

/// Centralized text styles for consistent typography across the app.
///
/// Use these instead of inline `TextStyle(fontWeight: ...)` to ensure
/// all headers, subtitles, body text, and labels share the same sizing,
/// weight, and letter-spacing.
class AppTextStyles {
  AppTextStyles._();

  // ── Section Headers (screen-level) ─────────────────────

  /// Large section header used above settings groups, etc.
  /// e.g. "Appearance", "Downloads", "Device"
  static TextStyle sectionHeader(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
      color: cs.onSurface,
      letterSpacing: -0.2,
      height: 1.3,
    );
  }

  // ── Card / Tile Titles ─────────────────────────────────

  /// Primary title inside a card or list tile.
  /// e.g. model name, session title, feature name.
  static TextStyle cardTitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 15,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
      height: 1.3,
    );
  }

  // ── Subtitles / Descriptions ───────────────────────────

  /// Secondary text below a title: descriptions, metadata.
  static TextStyle subtitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
      height: 1.4,
    );
  }

  /// Smaller subtitle used for secondary info in dense layouts.
  static TextStyle subtitleSmall(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: cs.outline,
      height: 1.4,
    );
  }

  // ── Body Text ──────────────────────────────────────────

  /// Standard body text for paragraphs and long-form content.
  static TextStyle body(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: cs.onSurfaceVariant,
      height: 1.5,
    );
  }

  // ── Labels / Chips ─────────────────────────────────────

  /// Small label text used in chips, badges, status indicators.
  static TextStyle label(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: cs.onSurfaceVariant,
      height: 1.3,
    );
  }

  /// Extra-small label used in info chips and compact UI.
  static TextStyle labelSmall(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: cs.outline,
      height: 1.3,
    );
  }

  /// Status text on tiles (Installed, Failed, Pending, etc.).
  static TextStyle status(BuildContext context) {
    return TextStyle(
      fontSize: 12,
      fontWeight: FontWeight.w600,
      height: 1.3,
    );
  }

  /// Empty-state heading, used when a screen has no content.
  static TextStyle emptyTitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w600,
      color: cs.onSurface,
      height: 1.3,
    );
  }

  /// Empty-state helper text.
  static TextStyle emptyBody(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: cs.outline,
      height: 1.5,
    );
  }
}
