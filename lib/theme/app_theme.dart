import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

// ─── Color Tokens ─────────────────────────────────────────────────────────────
// Inspired by Binondo, Manila — red lanterns, golden signage, warm ivory walls
class AppColors {
  AppColors._();

  // Core brand
  static const Color primary = Color(0xFF7F1D1D);      // Deep maroon — Binondo red
  static const Color primaryDark = Color(0xFF5C0A14);  // Rich dark maroon
  static const Color primaryLight = Color(0xFF9F2626); // Lighter maroon

  static const Color gold = Color(0xFFD97706);         // Amber gold — lantern glow
  static const Color goldLight = Color(0xFFF59E0B);    // Warm gold
  static const Color goldMuted = Color(0xFFFDE68A);    // Pale gold — borders

  // Surface
  static const Color background = Color(0xFFFDF6E3);   // Warm ivory — old paper
  static const Color surface = Color(0xFFFFFFFF);      // Clean white
  static const Color surfaceWarm = Color(0xFFFEF3C7);  // Very warm cream
  static const Color card = Color(0xFFFFFFFF);

  // Text
  static const Color textPrimary = Color(0xFF3B0A0A);  // Dark maroon-brown
  static const Color textSecondary = Color(0xFF78350F); // Medium warm brown
  static const Color textMuted = Color(0xFF9CA3AF);     // Cool gray muted
  static const Color textOnDark = Color(0xFFFFFBEB);   // Warm off-white on dark bg

  // Status
  static const Color success = Color(0xFF15803D);
  static const Color error = Color(0xFFDC2626);
  static const Color warning = Color(0xFFD97706);

  // Divider / border
  static const Color border = Color(0xFFFDE68A);       // Subtle gold border
  static const Color borderStrong = Color(0xFFD97706); // Gold border strong

  // Input field
  static const Color inputFill = Color(0xFFFEF9F0);    // Warm off-white
  static const Color inputBorder = Color(0xFFE5C58B);

  // Shadows
  static const Color shadow = Color(0x157F1D1D);
  static const Color shadowGold = Color(0x20D97706);
}

// ─── Text Styles ──────────────────────────────────────────────────────────────
class AppTextStyles {
  AppTextStyles._();

  // Display — Playfair Display SC (elegant, classic, restaurant-like)
  static TextStyle display1(BuildContext context) => GoogleFonts.playfairDisplaySc(
    fontSize: 36,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.5,
    height: 1.2,
  );

  static TextStyle display2(BuildContext context) => GoogleFonts.playfairDisplaySc(
    fontSize: 28,
    fontWeight: FontWeight.w700,
    color: AppColors.textPrimary,
    letterSpacing: -0.3,
    height: 1.25,
  );

  static TextStyle headline(BuildContext context) => GoogleFonts.playfairDisplaySc(
    fontSize: 22,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    letterSpacing: 0.2,
    height: 1.3,
  );

  // Body — Karla (clean, readable, modern)
  static TextStyle bodyLarge(BuildContext context) => GoogleFonts.karla(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.5,
  );

  static TextStyle bodyMedium(BuildContext context) => GoogleFonts.karla(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.5,
  );

  static TextStyle bodySmall(BuildContext context) => GoogleFonts.karla(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    height: 1.4,
  );

  static TextStyle label(BuildContext context) => GoogleFonts.karla(
    fontSize: 13,
    fontWeight: FontWeight.w600,
    color: AppColors.textSecondary,
    letterSpacing: 0.3,
    height: 1.4,
  );

  static TextStyle button(BuildContext context) => GoogleFonts.karla(
    fontSize: 15,
    fontWeight: FontWeight.w700,
    letterSpacing: 0.8,
    height: 1,
  );

  static TextStyle caption(BuildContext context) => GoogleFonts.karla(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: AppColors.textMuted,
    letterSpacing: 0.2,
    height: 1.4,
  );

  static TextStyle link(BuildContext context) => GoogleFonts.karla(
    fontSize: 14,
    fontWeight: FontWeight.w600,
    color: AppColors.gold,
    decoration: TextDecoration.underline,
    decorationColor: AppColors.gold,
    height: 1.5,
  );
}

// ─── Spacing ──────────────────────────────────────────────────────────────────
class AppSpacing {
  AppSpacing._();

  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
  static const double xxxl = 64;
}

// ─── Radius ───────────────────────────────────────────────────────────────────
class AppRadius {
  AppRadius._();

  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double pill = 100;
}

// ─── Shadows ──────────────────────────────────────────────────────────────────
class AppShadows {
  AppShadows._();

  static List<BoxShadow> card = [
    BoxShadow(
      color: AppColors.shadow,
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> goldGlow = [
    BoxShadow(
      color: AppColors.shadowGold,
      blurRadius: 20,
      offset: const Offset(0, 6),
      spreadRadius: 0,
    ),
  ];

  static List<BoxShadow> input = [
    BoxShadow(
      color: const Color(0x0A000000),
      blurRadius: 4,
      offset: const Offset(0, 2),
    ),
  ];
}

// ─── Theme Data ───────────────────────────────────────────────────────────────
class AppTheme {
  AppTheme._();

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        brightness: Brightness.light,
        primary: AppColors.primary,
        onPrimary: AppColors.textOnDark,
        secondary: AppColors.gold,
        onSecondary: AppColors.textPrimary,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      fontFamily: GoogleFonts.karla().fontFamily,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.playfairDisplaySc(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.inputFill,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.md,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.inputBorder, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.gold, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: GoogleFonts.karla(
          color: AppColors.textMuted,
          fontSize: 14,
        ),
        labelStyle: GoogleFonts.karla(
          color: AppColors.textSecondary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        floatingLabelStyle: GoogleFonts.karla(
          color: AppColors.gold,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
        errorStyle: GoogleFonts.karla(
          color: AppColors.error,
          fontSize: 12,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.textOnDark,
          elevation: 0,
          shadowColor: Colors.transparent,
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          minimumSize: const Size(double.infinity, 52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.md,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.gold,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: AppSpacing.xs,
          ),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.primaryDark,
        contentTextStyle: GoogleFonts.karla(
          color: AppColors.textOnDark,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
      ),
    );
  }
}