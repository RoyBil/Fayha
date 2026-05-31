import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  static const primary = Color(0xFF6B1F2E);
  static const primaryDark = Color(0xFF4A1520);
  static const primaryLight = Color(0xFF8A2A3C);

  static const accent = Color(0xFFC9A14A);
  static const accentDark = Color(0xFFA88336);
  static const accentLight = Color(0xFFE0BC6A);

  static const secondary = Color(0xFF2A4D3A);
  static const secondaryDark = Color(0xFF1B3326);

  static const dark = Color(0xFF1A1210);
  static const charcoal = Color(0xFF2A1F1A);
  static const gray = Color(0xFF5C4F48);
  static const lightGray = Color(0xFFB8AEA7);

  static const cream = Color(0xFFFAF6F0);
  static const offWhite = Color(0xFFF4EDE2);
}

class AppTheme {
  static ThemeData get light {
    final base = ThemeData.light(useMaterial3: true);

    final headingFont = GoogleFonts.cormorantGaramondTextTheme();
    final bodyFont = GoogleFonts.interTextTheme();

    final textTheme = base.textTheme.copyWith(
      displayLarge: headingFont.displayLarge?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      displayMedium: headingFont.displayMedium?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      displaySmall: headingFont.displaySmall?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      headlineLarge: headingFont.headlineLarge?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      headlineMedium: headingFont.headlineMedium?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      headlineSmall: headingFont.headlineSmall?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      titleLarge: headingFont.titleLarge?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      titleMedium: bodyFont.titleMedium?.copyWith(
        color: AppColors.dark,
        fontWeight: FontWeight.w600,
      ),
      titleSmall: bodyFont.titleSmall?.copyWith(
        color: AppColors.charcoal,
        fontWeight: FontWeight.w600,
      ),
      bodyLarge: bodyFont.bodyLarge?.copyWith(color: AppColors.charcoal),
      bodyMedium: bodyFont.bodyMedium?.copyWith(color: AppColors.charcoal),
      bodySmall: bodyFont.bodySmall?.copyWith(color: AppColors.gray),
      labelLarge: bodyFont.labelLarge?.copyWith(
        color: AppColors.primary,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
      ),
      labelMedium: bodyFont.labelMedium?.copyWith(
        color: AppColors.gray,
        letterSpacing: 0.6,
      ),
      labelSmall: bodyFont.labelSmall?.copyWith(
        color: AppColors.accentDark,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w600,
      ),
    );

    return base.copyWith(
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: AppColors.cream,
        secondary: AppColors.accent,
        onSecondary: AppColors.dark,
        tertiary: AppColors.secondary,
        onTertiary: AppColors.cream,
        surface: AppColors.cream,
        onSurface: AppColors.dark,
        error: Color(0xFFB23A48),
        onError: AppColors.cream,
      ),
      scaffoldBackgroundColor: AppColors.cream,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.cream,
        foregroundColor: AppColors.dark,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: GoogleFonts.cormorantGaramond(
          color: AppColors.dark,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        iconTheme: const IconThemeData(color: AppColors.primary),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.cream,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.gray,
        showUnselectedLabels: true,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
      cardTheme: CardThemeData(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: AppColors.offWhite, width: 1),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.cream,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.2),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: GoogleFonts.inter(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.offWhite),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.offWhite),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: AppColors.gray),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.offWhite,
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.offWhite,
        labelStyle: GoogleFonts.inter(
          color: AppColors.primaryDark,
          fontWeight: FontWeight.w500,
        ),
        side: BorderSide.none,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
