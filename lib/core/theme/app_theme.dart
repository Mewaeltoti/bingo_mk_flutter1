import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppColors {
  // Brand Colors — 
  static const Color primary    = Color(0xFF1A237E); // Deep Royal Blue
  static const Color secondary  = Color(0xFFD4AF37); // Ambassador Gold
  static const Color accent     = Color(0xFF42A5F5); // Sky Blue accent

  // Light mode surfaces
  static const Color background     = Color(0xFFF5F5F5);
  static const Color card           = Color(0xFFFFFFFF);
  static const Color textPrimary    = Color(0xFF0D1117);
  static const Color textSecondary  = Color(0xFF6B7280);
  static const Color border         = Color(0xFFE0E0E0);

  // Dark mode surfaces
  static const Color darkBackground   = Color(0xFF050D1A);
  static const Color darkCard         = Color(0xFF0D1B2A);
  static const Color darkBorder       = Color(0xFF1C2E40);
  static const Color darkTextPrimary  = Colors.white;
  static const Color darkTextSecondary = Color(0xFFB0BEC5);

  // Semantic
  static const Color success = Color(0xFF2A9D8F);
  static const Color danger  = Color(0xFFE63946);
  static const Color warning = Color(0xFFF59E0B);

  static const LinearGradient headerGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primary, Color(0xFF283593)],
  );

  static const LinearGradient splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF050D1A), Color(0xFF0D1B2A), Color(0xFF050D1A)],
  );
}

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: GoogleFonts.outfit().fontFamily,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.card,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.textPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.dark,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.card,
      selectedItemColor: AppColors.primary,
      unselectedItemColor: Colors.black54,
    ),
    textTheme: GoogleFonts.outfitTextTheme().copyWith(
      bodyLarge:  const TextStyle(color: AppColors.textPrimary,   fontSize: 16),
      bodyMedium: const TextStyle(color: AppColors.textSecondary, fontSize: 14),
    ),
    cardTheme: CardThemeData(
      color: AppColors.card,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    dividerColor: AppColors.border,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.darkBackground,
    fontFamily: GoogleFonts.outfit().fontFamily,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primary,
      secondary: AppColors.secondary,
      surface: AppColors.darkCard,
      error: AppColors.danger,
      onPrimary: Colors.white,
      onSurface: AppColors.darkTextPrimary,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.transparent,
      elevation: 0,
      centerTitle: true,
      systemOverlayStyle: SystemUiOverlayStyle.light,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.darkCard,
      selectedItemColor: AppColors.secondary,
      unselectedItemColor: Colors.white60,
    ),
    cardTheme: CardThemeData(
      color: AppColors.darkCard,
      elevation: 8,
      shadowColor: Colors.black45,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
    textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme).copyWith(
      bodyLarge:  const TextStyle(color: AppColors.darkTextPrimary,   fontSize: 16),
      bodyMedium: const TextStyle(color: AppColors.darkTextSecondary, fontSize: 14),
    ),
    dividerColor: AppColors.darkBorder,
  );
}