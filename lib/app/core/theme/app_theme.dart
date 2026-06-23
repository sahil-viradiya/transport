import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Bharat Transport theme — warm, bold, premium.
/// Display text uses Poppins (friendly, modern, strong headlines); body uses
/// Inter for readability. Cards are soft-rounded with warm shadows; the saffron
/// primary drives all call-to-action surfaces.
class AppTheme {
  AppTheme._();

  static TextTheme _textTheme(Color heading, Color body, Color faint) {
    final base = GoogleFonts.interTextTheme();
    return base.copyWith(
      headlineLarge: GoogleFonts.poppins(
          fontSize: 30, fontWeight: FontWeight.w800, color: heading, letterSpacing: -0.5),
      headlineMedium: GoogleFonts.poppins(
          fontSize: 24, fontWeight: FontWeight.w700, color: heading, letterSpacing: -0.3),
      headlineSmall: GoogleFonts.poppins(
          fontSize: 19, fontWeight: FontWeight.w700, color: heading),
      titleLarge: GoogleFonts.poppins(
          fontSize: 17, fontWeight: FontWeight.w600, color: heading),
      bodyLarge: GoogleFonts.inter(fontSize: 15.5, fontWeight: FontWeight.w500, color: body),
      bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: faint),
      labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.primary),
      labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: faint),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.background,
      splashColor: AppColors.primaryLight.withValues(alpha: 0.4),
      highlightColor: AppColors.primaryLight.withValues(alpha: 0.2),
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.secondaryDark,
        tertiary: AppColors.tertiary,
        error: AppColors.error,
        surface: AppColors.surface,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: AppColors.textPrimary,
        onError: Colors.white,
      ),
      textTheme: _textTheme(
          AppColors.textPrimary, AppColors.textPrimary, AppColors.textSecondary),
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.background,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: AppColors.textPrimary),
        titleTextStyle: GoogleFonts.poppins(
          color: AppColors.textPrimary,
          fontSize: 19,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.cardBg,
        elevation: 0,
        shadowColor: AppColors.secondaryDark.withValues(alpha: 0.06),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          shadowColor: AppColors.primary.withValues(alpha: 0.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primaryLight,
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.primaryLight,
        labelStyle: GoogleFonts.inter(
            fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.primaryDark),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide.none,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.border, width: 1.5),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 1.5),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: AppColors.error, width: 2),
        ),
        hintStyle: GoogleFonts.inter(color: AppColors.textHint, fontSize: 14),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1),
    );
  }

  static ThemeData get darkTheme {
    const darkBg = Color(0xFF14110F);
    const darkSurface = Color(0xFF1F1B18);
    const darkBorder = Color(0xFF332E2A);
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.tertiary,
        tertiary: AppColors.tertiary,
        error: AppColors.error,
        surface: darkSurface,
        onPrimary: Colors.white,
        onSurface: Color(0xFFF5F0E8),
        onError: Colors.white,
      ),
      textTheme: _textTheme(
          const Color(0xFFF5F0E8), const Color(0xFFEDE7E0), const Color(0xFFA8A29E)),
      appBarTheme: AppBarTheme(
        backgroundColor: darkBg,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.white),
        titleTextStyle: GoogleFonts.poppins(
            color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: darkBorder, width: 1),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          textStyle: GoogleFonts.poppins(fontSize: 15.5, fontWeight: FontWeight.w600),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: darkSurface,
        indicatorColor: AppColors.primary.withValues(alpha: 0.25),
        elevation: 0,
        height: 68,
        labelTextStyle: WidgetStateProperty.all(
          GoogleFonts.inter(fontSize: 11.5, fontWeight: FontWeight.w600),
        ),
      ),
      dividerTheme: const DividerThemeData(color: darkBorder, thickness: 1),
    );
  }
}
