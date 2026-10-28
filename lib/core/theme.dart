import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Brand Primary ────────────────────────────────────────────────────────────
  static const Color primary = Color(0xFF087F8C);
  static const Color primaryDark = Color(0xFF055A63);
  static const Color primaryContainer = Color(0xFFE0F8FF);
  static const Color onPrimary = Color(0xFFFFFFFF);

  // ── Surface & Background ────────────────────────────────────────────────────
  static const Color surfaceLowest = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF0FBFF);
  static const Color surfaceLow = Color(0xFFE0F8FF);
  static const Color surfaceContainerDim = Color(0xFFC2DFE8);
  static const Color outlineBorder = Color(0xFFD1E5EC);

  // ── Status — Success ─────────────────────────────────────────────────────────
  static const Color successText = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);

  // ── Status — Warning ─────────────────────────────────────────────────────────
  static const Color warningText = Color(0xFFD97706);
  static const Color warningBg = Color(0xFFFEF3C7);

  // ── Status — Error ───────────────────────────────────────────────────────────
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);

  // ── Status — Muted ───────────────────────────────────────────────────────────
  static const Color mutedText = Color(0xFF64748B);
  static const Color mutedBg = Color(0xFFF1F5F9);

  // ── Status — Info ────────────────────────────────────────────────────────────
  static const Color infoText = Color(0xFF0284C7);
  static const Color infoBg = Color(0xFFE0F2FE);

  // ── Typography ───────────────────────────────────────────────────────────────
  static const Color text = Color(0xFF0F172A);
  static const Color textSecondary = Color(0xFF334155);
  static const Color textDisabled = Color(0xFF94A3B8);

  // ── Accent ───────────────────────────────────────────────────────────────────
  static const Color adminHeaderDark = Color(0xFF0F172A);
  static const Color adminBrandBlue = Color(0xFF1E40AF);
  static const Color subsidyTeal = Color(0xFF0D9488);
  static const Color deliveryYellow = Color(0xFFEAB308);

  // ── Theme ────────────────────────────────────────────────────────────────────
  static ThemeData get lightTheme {
    final base = GoogleFonts.dmSansTextTheme().copyWith(
      displayLarge: GoogleFonts.dmSans(fontSize: 32, fontWeight: FontWeight.bold, color: text, letterSpacing: -0.5),
      displayMedium: GoogleFonts.dmSans(fontSize: 28, fontWeight: FontWeight.bold, color: text, letterSpacing: -0.5),
      displaySmall: GoogleFonts.dmSans(fontSize: 24, fontWeight: FontWeight.bold, color: text),
      headlineLarge: GoogleFonts.dmSans(fontSize: 22, fontWeight: FontWeight.bold, color: text),
      headlineMedium: GoogleFonts.dmSans(fontSize: 18, fontWeight: FontWeight.w700, color: text),
      headlineSmall: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w700, color: text),
      titleLarge: GoogleFonts.dmSans(fontSize: 16, fontWeight: FontWeight.w600, color: text),
      titleMedium: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: text),
      titleSmall: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.w600, color: text),
      bodyLarge: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.normal, color: text),
      bodyMedium: GoogleFonts.dmSans(fontSize: 13, fontWeight: FontWeight.normal, color: textSecondary),
      bodySmall: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.normal, color: mutedText),
      labelLarge: GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600, color: text),
      labelMedium: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500, color: mutedText),
      labelSmall: GoogleFonts.dmSans(fontSize: 10, fontWeight: FontWeight.w500, color: mutedText, letterSpacing: 0.5),
    );

    return ThemeData(
      useMaterial3: false,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.light(
        primary: primary,
        surface: background,
        error: error,
      ),
      textTheme: base,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      // ── AppBar ──────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: background,
        elevation: 0,
        scrolledUnderElevation: 0,
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: background,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
        ),
        iconTheme: const IconThemeData(color: text),
        actionsIconTheme: const IconThemeData(color: text),
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: text,
          letterSpacing: -0.2,
        ),
        toolbarTextStyle: GoogleFonts.dmSans(fontSize: 17, fontWeight: FontWeight.w700, color: text),
      ),
      // ── Bottom Nav ──────────────────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: background,
        selectedItemColor: primary,
        unselectedItemColor: mutedText,
        selectedLabelStyle: GoogleFonts.dmSans(fontSize: 11, fontWeight: FontWeight.w600),
        unselectedLabelStyle: GoogleFonts.dmSans(fontSize: 11),
        elevation: 8,
        type: BottomNavigationBarType.fixed,
      ),
      // ── ElevatedButton ──────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
          elevation: 0,
        ),
      ),
      // ── OutlinedButton ──────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: primary,
          side: const BorderSide(color: primary),
          minimumSize: const Size(double.infinity, 50),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.dmSans(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),
      // ── Input ───────────────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: GoogleFonts.dmSans(fontSize: 14, color: textDisabled),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outlineBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 1.5),
        ),
      ),
      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: outlineBorder),
        ),
        margin: EdgeInsets.zero,
      ),
      // ── Chip ────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white,
        selectedColor: primaryContainer,
        labelStyle: GoogleFonts.dmSans(fontSize: 12, fontWeight: FontWeight.w500),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        side: const BorderSide(color: outlineBorder),
      ),
      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: const DividerThemeData(color: outlineBorder, thickness: 1, space: 1),
    );
  }
}
