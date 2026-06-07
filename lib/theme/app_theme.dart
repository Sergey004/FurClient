import 'dart:io' show Platform;
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:system_theme/system_theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Static colour palette (the "Original" dark theme — never changes)
// ─────────────────────────────────────────────────────────────────────────────

class AppColors {
  // ── Dark / Original palette ────────────────────────────────────────────────
  static const bg = Color(0xFF0f0f11);
  static const bgDeep = Color(0xFF090909);
  static const bgCard = Color(0xFF141414);
  static const bgCardHover = Color(0xFF1c1c1e);
  static const bgInput = Color(0xFF1e1e22);
  static const bgMica = Color(0x1Affffff);

  static const border = Color(0x0Dffffff);
  static const borderLight = Color(0x1Affffff);

  static const text = Color(0xFFe5e5e5);
  static const textDim = Color(0xFF9ca3af);
  static const textMuted = Color(0xFF6b7280);

  static const danger = Color(0xFFef4444);
  static const success = Color(0xFF10b981);
  static const warning = Color(0xFFf59e0b);

  static const fluentCyan = Color(0xFF60cdff);
  static const fluentCyanDark = Color(0xFF0078d4);
  static const fluentCyanBg = Color(0x1A60cdff);

  static const materialGreen = Color(0xFF10b981);
  static const materialGreenDark = Color(0xFF059669);
  static const materialGreenBg = Color(0x1A10b981);

  static const materialLavender = Color(0xFFe8def8);
  static const materialLavenderDark = Color(0xFF9a82db);
  static const materialLavenderBg = Color(0x1Ae8def8);

  static const cupertinoPurple = Color(0xFFa78bfa);
  static const cupertinoPurpleDark = Color(0xFF7c3aed);
  static const cupertinoPurpleBg = Color(0x1Aa78bfa);

  static const accent = fluentCyanDark;
  static const accentLight = fluentCyan;

  static const notifFave = Color(0xFF60cdff);
  static const notifComment = Color(0xFF10b981);
  static const notifWatch = Color(0xFFa78bfa);
  static const notifJournal = Color(0xFFf59e0b);

  // ── Light palette ──────────────────────────────────────────────────────────
  static const lightBg = Color(0xFFfafafa);
  static const lightBgDeep = Color(0xFFf0f0f0);
  static const lightBgCard = Color(0xFFffffff);
  static const lightBgInput = Color(0xFFf0f0f2);
  static const lightBorder = Color(0x1A000000);
  static const lightBorderLight = Color(0x33000000);
  static const lightText = Color(0xFF1a1a1a);
  static const lightTextDim = Color(0xFF666666);
  static const lightTextMuted = Color(0xFF999999);
}

class AppBreakpoints {
  static const double desktop = 840;
  static const double tablet = 600;
}

// ─────────────────────────────────────────────────────────────────────────────
// Adaptive palette — resolves colours based on current brightness.
// Use `Palette.of(context)` instead of raw `AppColors.*` in widgets so that
// they automatically adapt when the user switches between dark / light / system.
// ─────────────────────────────────────────────────────────────────────────────

class Palette {
  final Color bg;
  final Color bgCard;
  final Color bgInput;
  final Color border;
  final Color text;
  final Color textDim;
  final Color textMuted;

  const Palette._({
    required this.bg,
    required this.bgCard,
    required this.bgInput,
    required this.border,
    required this.text,
    required this.textDim,
    required this.textMuted,
  });

  static const dark = Palette._(
    bg: AppColors.bg,
    bgCard: AppColors.bgCard,
    bgInput: AppColors.bgInput,
    border: AppColors.border,
    text: AppColors.text,
    textDim: AppColors.textDim,
    textMuted: AppColors.textMuted,
  );

  static const light = Palette._(
    bg: AppColors.lightBg,
    bgCard: AppColors.lightBgCard,
    bgInput: AppColors.lightBgInput,
    border: AppColors.lightBorder,
    text: AppColors.lightText,
    textDim: AppColors.lightTextDim,
    textMuted: AppColors.lightTextMuted,
  );

  /// Resolve the correct palette for the current widget's brightness.
  /// On Windows this reads FluentTheme, on other platforms Theme.of.
  static Palette of(BuildContext context) {
    final brightness = _resolveBrightness(context);
    return brightness == Brightness.dark ? dark : light;
  }

  static Brightness _resolveBrightness(BuildContext context) {
    try {
      if (Platform.isWindows) {
        return fluent.FluentTheme.of(context).brightness;
      }
      return Theme.of(context).brightness;
    } catch (_) {
      return Brightness.dark;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Dark colour parameters (used by buildColorParams for Original theme ONLY)
// ─────────────────────────────────────────────────────────────────────────────

class _DarkParams {
  final Color bg;
  final Color bgDeep;
  final Color bgCard;
  final Color bgInput;
  final Color border;
  final Color text;
  final Color textDim;
  final Color textMuted;
  final Color primary;
  final Color primaryBg;

  const _DarkParams({
    required this.bg,
    required this.bgDeep,
    required this.bgCard,
    required this.bgInput,
    required this.border,
    required this.text,
    required this.textDim,
    required this.textMuted,
    required this.primary,
    required this.primaryBg,
  });
}

// ─────────────────────────────────────────────────────────────────────────────
// Theme builder
// ─────────────────────────────────────────────────────────────────────────────

class AppTheme {
  // ═════════════════════════════════════════════════════════════════════════
  // ORIGINAL DARK THEME (hard-coded, no system colour)
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData get darkTheme => _buildMaterialTheme(
        dark: _DarkParams(
          bg: AppColors.bg,
          bgDeep: AppColors.bgDeep,
          bgCard: AppColors.bgCard,
          bgInput: AppColors.bgInput,
          border: AppColors.border,
          text: AppColors.text,
          textDim: AppColors.textDim,
          textMuted: AppColors.textMuted,
          primary: AppColors.fluentCyanDark,
          primaryBg: AppColors.fluentCyanBg,
        ),
      );

  // ═════════════════════════════════════════════════════════════════════════
  // MATERIAL 3 THEMES (system / light / dark modes)
  //
  // These use proper M3 color roles from ColorScheme.
  // On Android 12+: DynamicColorBuilder provides wallpaper-derived ColorScheme.
  // On desktop: we generate ColorScheme.fromSeed(accent).
  // ═════════════════════════════════════════════════════════════════════════

  /// Build M3 dark theme from dynamic color (Android wallpaper).
  static ThemeData buildFromDynamicColor(ColorScheme darkDynamic) {
    return _buildM3Theme(darkDynamic);
  }

  /// Build M3 dark theme from system accent (desktop fallback).
  static ThemeData buildFromSystemAccent(Color accent) {
    return _buildM3Theme(
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.dark,
      ),
    );
  }

  /// Build M3 light theme from system accent.
  static ThemeData buildLightTheme({Color accent = const Color(0xFF0078d4)}) {
    return _buildM3Theme(
      ColorScheme.fromSeed(
        seedColor: accent,
        brightness: Brightness.light,
      ),
    );
  }

  /// Build M3 light theme from dynamic color.
  static ThemeData buildLightFromDynamic(ColorScheme lightDynamic) {
    return _buildM3Theme(lightDynamic);
  }

  // ── M3 Core builder — derives EVERYTHING from ColorScheme ───────────────

  static ThemeData _buildM3Theme(ColorScheme colorScheme) {
    final isDark = colorScheme.brightness == Brightness.dark;

    // M3 surface hierarchy:
    //   surfaceContainerLowest  → most elevated (cards, dialogs)
    //   surfaceContainerLow     → slightly elevated
    //   surfaceContainer        → medium
    //   surfaceContainerHigh   → slightly recessed
    //   surfaceContainerHighest → most recessed (navigation, bottom bar)
    //   surface                 → base scaffold background
    final scaffoldBg = colorScheme.surface;
    final cardBg = isDark
        ? colorScheme.surfaceContainerLow
        : colorScheme.surfaceContainerLowest;
    final inputBg = colorScheme.surfaceContainerHighest;
    final borderCol = colorScheme.outlineVariant;
    final subtleBorder = colorScheme.outline.withValues(alpha: 0.15);

    return ThemeData(
      useMaterial3: true,
      brightness: colorScheme.brightness,
      scaffoldBackgroundColor: scaffoldBg,
      colorScheme: colorScheme,

      // M3 surface tint: the "elevation glow" tint color
      // Transparent for original mode, M3 surface tint for M3 modes.
      // Flutter automatically applies it via surfaceTintColor on Card/Scaffold.

      // ── Cards ────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: subtleBorder),
        ),
        margin: EdgeInsets.zero,
        // M3 tonal elevation is handled by surfaceTintColor automatically
      ),

      // ── AppBar (top app bar) ─────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: scaffoldBg,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
        scrolledUnderElevation: 3.0,
        centerTitle: false,
        surfaceTintColor: isDark
            ? colorScheme.surfaceTint.withValues(alpha: 0.0)
            : colorScheme.surfaceTint,
        titleTextStyle: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
      ),

      // ── Bottom navigation bar ─────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: colorScheme.surfaceContainer,
        selectedItemColor: colorScheme.primary,
        unselectedItemColor: colorScheme.onSurfaceVariant,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),

      // ── Navigation rail (desktop side bar) ─────────────────────────────────
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: colorScheme.surfaceContainerLow,
        selectedIconTheme:
            IconThemeData(color: colorScheme.primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: colorScheme.onSurfaceVariant, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: colorScheme.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
        ),
        indicatorColor: colorScheme.primaryContainer,
        minWidth: 72,
        minExtendedWidth: 200,
        groupAlignment: 0,
      ),

      // ── Chips (tags) ─────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: colorScheme.surfaceContainerHighest,
        selectedColor: colorScheme.secondaryContainer,
        labelStyle: TextStyle(
            color: colorScheme.onSurfaceVariant, fontSize: 13),
        secondaryLabelStyle: TextStyle(
            color: colorScheme.onSecondaryContainer, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
      ),

      // ── Input / text fields ──────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        hintStyle: TextStyle(color: colorScheme.onSurfaceVariant),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(28),
          borderSide:
              BorderSide(color: colorScheme.primary, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      ),

      // ── Dividers ─────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: borderCol,
        thickness: 1,
        space: 1,
      ),

      // ── Elevated buttons ──────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20), // M3 full-round button
          ),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // ── Text buttons ──────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: colorScheme.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      // ── Filled button (M3 primary FAB-like) ──────────────────────────────
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: colorScheme.primary,
          foregroundColor: colorScheme.onPrimary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ── Outlined button ──────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: colorScheme.primary,
          side: BorderSide(color: colorScheme.outline),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
        ),
      ),

      // ── Toggle / Switch ─────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.onPrimary;
          }
          // OFF: thumb brighter than track for clear visibility
          return colorScheme.onSurfaceVariant;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          // OFF: track distinctly darker/lighter than scaffold bg
          return colorScheme.outline.withValues(alpha: 0.4);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return colorScheme.outline.withValues(alpha: 0.6);
        }),
      ),

      // ── Checkbox ─────────────────────────────────────────────────────────
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return colorScheme.primary;
          }
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(colorScheme.onPrimary),
        side: BorderSide(color: colorScheme.outline, width: 2),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),

      // ── Icons ────────────────────────────────────────────────────────────
      iconTheme: IconThemeData(
        color: colorScheme.onSurfaceVariant,
        size: 24,
      ),

      // ── M3 Typography ────────────────────────────────────────────────────
      // Uses the new M3 type scale: Display / Headline / Title / Body / Label
      textTheme: TextTheme(
        // Display (large hero text — rarely used in apps)
        displayLarge: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 57,
          fontWeight: FontWeight.w400,
          letterSpacing: -0.25,
        ),
        displayMedium: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 45,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        displaySmall: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 36,
          fontWeight: FontWeight.w400,
          letterSpacing: 0,
        ),
        // Headline (section headers)
        headlineLarge: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 32,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineMedium: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 28,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        headlineSmall: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: 0,
        ),
        // Title (card titles, list items)
        titleLarge: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 22,
          fontWeight: FontWeight.w500,
          letterSpacing: 0,
        ),
        titleMedium: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
        ),
        titleSmall: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
        ),
        // Body
        bodyLarge: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 16,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.5,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 14,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.25,
          height: 1.43,
        ),
        bodySmall: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w400,
          letterSpacing: 0.4,
          height: 1.33,
        ),
        // Label (buttons, chips, navigation)
        labelLarge: TextStyle(
          color: colorScheme.onSurface,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.1,
        ),
        labelMedium: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
        labelSmall: TextStyle(
          color: colorScheme.onSurfaceVariant,
          fontSize: 11,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.5,
        ),
      ),

      // ── Dialog ────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: colorScheme.surfaceContainerHigh,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(28), // M3 extra-large shape
        ),
      ),

      // ── Snackbar ─────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: colorScheme.inverseSurface,
        contentTextStyle: TextStyle(color: colorScheme.onInverseSurface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),

      // ── Page transitions (iOS-style on all platforms for smooth feel) ──
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ═════════════════════════════════════════════════════════════════════════
  // ORIGINAL THEME BUILDER (uses hard-coded AppColors, NOT M3 ColorScheme)
  // ═════════════════════════════════════════════════════════════════════════

  static ThemeData _buildMaterialTheme({
    required _DarkParams dark,
  }) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: dark.bg,
      colorScheme: ColorScheme.dark(primary: dark.primary),
      cardTheme: CardThemeData(
        color: dark.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: dark.bg,
        foregroundColor: dark.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: dark.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: dark.bgCard,
        selectedItemColor: dark.primary,
        unselectedItemColor: dark.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: const TextStyle(fontSize: 12),
      ),
      navigationRailTheme: NavigationRailThemeData(
        backgroundColor: dark.bgCard,
        selectedIconTheme: IconThemeData(color: dark.primary, size: 24),
        unselectedIconTheme:
            IconThemeData(color: dark.textMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: dark.primary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: dark.textMuted,
          fontSize: 11,
        ),
        indicatorColor: dark.primaryBg,
        minWidth: 72,
        minExtendedWidth: 200,
        groupAlignment: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: dark.bgInput,
        selectedColor: dark.primaryBg,
        labelStyle: TextStyle(color: dark.textDim, fontSize: 13),
        secondaryLabelStyle:
            TextStyle(color: dark.primary.withValues(alpha: 0.7), fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: dark.bgInput,
        hintStyle: TextStyle(color: dark.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide(color: dark.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      dividerTheme: DividerThemeData(
        color: dark.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: dark.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: dark.primary,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          // OFF: brighter thumb so it's visible against the dark track
          return const Color(0xFF9ca3af);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark.primary;
          }
          // OFF: distinct dark track, not too close to bgCard
          return const Color(0xFF3a3a42);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return dark.primary;
          }
          return const Color(0xFF555560);
        }),
      ),
      iconTheme: IconThemeData(
        color: dark.textDim,
        size: 24,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: dark.text,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: dark.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: dark.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          color: dark.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          color: dark.text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: dark.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: dark.text, fontSize: 16),
        bodyMedium: TextStyle(color: dark.textDim, fontSize: 14),
        bodySmall: TextStyle(color: dark.textMuted, fontSize: 12),
        labelLarge: TextStyle(
          color: dark.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          color: dark.textDim,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: dark.textMuted,
          fontSize: 11,
        ),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: CupertinoPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: CupertinoPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }

  // ── System overlay (status bar / nav bar) ─────────────────────────────────

  static void setSystemOverlay({bool dark = true}) {
    SystemChrome.setSystemUIOverlayStyle(SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor:
          dark ? AppColors.bgCard : AppColors.lightBgCard,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    ));
  }

  // ═════════════════════════════════════════════════════════════════════════
  // FLUENT UI THEMES (Windows only)
  // ═════════════════════════════════════════════════════════════════════════

  static fluent.FluentThemeData get fluentDarkTheme {
    return fluent.FluentThemeData(
      brightness: Brightness.dark,
      accentColor: fluent.AccentColor.swatch(const <String, Color>{
        'darkest': AppColors.fluentCyanDark,
        'darker': AppColors.fluentCyanDark,
        'dark': AppColors.fluentCyanDark,
        'normal': AppColors.fluentCyan,
        'light': AppColors.fluentCyan,
        'lighter': AppColors.fluentCyan,
        'lightest': AppColors.fluentCyan,
      }),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.bgCard,
      micaBackgroundColor: AppColors.bg,
      acrylicBackgroundColor: AppColors.bg,
      activeColor: AppColors.fluentCyanDark,
      inactiveColor: AppColors.textMuted,
      inactiveBackgroundColor: const Color(0xFF1a1a1e),
      shadowColor: Colors.transparent,
    );
  }

  static fluent.FluentThemeData fluentFromSystemAccent(Color accent) {
    return fluent.FluentThemeData(
      brightness: Brightness.dark,
      accentColor: _accentSwatch(accent),
      scaffoldBackgroundColor: AppColors.bg,
      cardColor: AppColors.bgCard,
      micaBackgroundColor: AppColors.bg,
      acrylicBackgroundColor: AppColors.bg,
      activeColor: accent,
      inactiveColor: AppColors.textMuted,
      inactiveBackgroundColor: const Color(0xFF1a1a1e),
      shadowColor: Colors.transparent,
    );
  }

  static fluent.FluentThemeData fluentLightTheme(
      {Color accent = const Color(0xFF0078d4)}) {
    return fluent.FluentThemeData(
      brightness: Brightness.light,
      accentColor: _accentSwatch(accent),
      scaffoldBackgroundColor: AppColors.lightBg,
      cardColor: AppColors.lightBgCard,
      micaBackgroundColor: AppColors.lightBgDeep,
      acrylicBackgroundColor: AppColors.lightBgDeep,
      activeColor: accent,
      inactiveColor: AppColors.lightTextDim,
      inactiveBackgroundColor: const Color(0xFFF5F5F5),
      shadowColor: const Color(0x1A000000),
    );
  }

  static fluent.AccentColor _accentSwatch(Color accent) {
    return fluent.AccentColor.swatch(<String, Color>{
      'darkest': Color.lerp(accent, Colors.black, 0.5)!,
      'darker': Color.lerp(accent, Colors.black, 0.3)!,
      'dark': Color.lerp(accent, Colors.black, 0.1)!,
      'normal': accent,
      'light': Color.lerp(accent, Colors.white, 0.4)!,
      'lighter': Color.lerp(accent, Colors.white, 0.6)!,
      'lightest': Color.lerp(accent, Colors.white, 0.8)!,
    });
  }

  // ── Get system accent colour (with fallback) ────────────────────────────────

  static Color get systemAccent {
    final c = SystemTheme.accentColor.accent;
    return (c != Colors.transparent) ? c : const Color(0xFF0078d4);
  }
}
