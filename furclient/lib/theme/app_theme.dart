import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppColors {
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
}

class AppBreakpoints {
  static const double desktop = 840;
  static const double tablet = 600;
}

class AppTheme {
  static ThemeData get darkTheme {
    return _buildTheme(const ColorScheme.dark(
      primary: AppColors.fluentCyanDark,
      onPrimary: Colors.white,
      secondary: AppColors.materialLavenderDark,
      onSecondary: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: Colors.white,
    ));
  }

  static ThemeData buildFromDynamicColor(ColorScheme darkDynamic) {
    return _buildTheme(darkDynamic.copyWith(
      surface: darkDynamic.surface,
      onSurface: darkDynamic.onSurface,
    ));
  }

  static ThemeData buildFromSystemAccent(Color accent) {
    return _buildTheme(ColorScheme.dark(
      primary: accent,
      onPrimary: Colors.white,
      secondary: AppColors.materialLavenderDark,
      onSecondary: Colors.white,
      surface: AppColors.bgCard,
      onSurface: AppColors.text,
      error: AppColors.danger,
      onError: Colors.white,
    ));
  }

  static ThemeData _buildTheme(ColorScheme colorScheme) {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.bg,
      colorScheme: colorScheme,
      cardTheme: CardThemeData(
        color: AppColors.bgCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.border),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.bg,
        foregroundColor: AppColors.text,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.bgCard,
        selectedItemColor: AppColors.fluentCyanDark,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle:
            TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
        unselectedLabelStyle: TextStyle(fontSize: 12),
      ),
      navigationRailTheme: const NavigationRailThemeData(
        backgroundColor: AppColors.bgCard,
        selectedIconTheme: IconThemeData(color: AppColors.fluentCyan, size: 24),
        unselectedIconTheme:
            IconThemeData(color: AppColors.textMuted, size: 22),
        selectedLabelTextStyle: TextStyle(
          color: AppColors.fluentCyan,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
        unselectedLabelTextStyle: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
        ),
        indicatorColor: AppColors.fluentCyanBg,
        minWidth: 72,
        minExtendedWidth: 200,
        groupAlignment: 0,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.bgInput,
        selectedColor: AppColors.materialLavenderBg,
        labelStyle: const TextStyle(color: AppColors.textDim, fontSize: 13),
        secondaryLabelStyle:
            const TextStyle(color: AppColors.materialLavender, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide.none,
        ),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.bgInput,
        hintStyle: const TextStyle(color: AppColors.textMuted),
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
          borderSide: const BorderSide(color: AppColors.fluentCyan, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.fluentCyanDark,
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
          foregroundColor: AppColors.fluentCyan,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return Colors.white;
          return AppColors.textMuted;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AppColors.fluentCyanDark;
          }
          return AppColors.bgInput;
        }),
      ),
      iconTheme: const IconThemeData(
        color: AppColors.textDim,
        size: 24,
      ),
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: AppColors.text,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
        headlineMedium: TextStyle(
          color: AppColors.text,
          fontSize: 24,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.3,
        ),
        headlineSmall: TextStyle(
          color: AppColors.text,
          fontSize: 20,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleLarge: TextStyle(
          color: AppColors.text,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: -0.1,
        ),
        titleMedium: TextStyle(
          color: AppColors.text,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: AppColors.text, fontSize: 16),
        bodyMedium: TextStyle(color: AppColors.textDim, fontSize: 14),
        bodySmall: TextStyle(color: AppColors.textMuted, fontSize: 12),
        labelLarge: TextStyle(
          color: AppColors.text,
          fontSize: 14,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
        ),
        labelMedium: TextStyle(
          color: AppColors.textDim,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        labelSmall: TextStyle(
          color: AppColors.textMuted,
          fontSize: 11,
        ),
      ),
      pageTransitionsTheme: PageTransitionsTheme(
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

  static void setSystemOverlay() {
    SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: AppColors.bgCard,
      systemNavigationBarIconBrightness: Brightness.light,
    ));
  }
}
