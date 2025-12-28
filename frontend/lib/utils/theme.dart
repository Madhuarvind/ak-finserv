import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Premium Neon Green & Dark Palette
  static const Color primaryColor = Color(0xFFADFF2F); // Neon Green (Lime Green)
  static const Color backgroundColor = Color(0xFF000000); // Pitch Black
  static const Color surfaceColor = Color(0xFF121212); // Deep Grey Card
  static const Color accentColor = Color(0xFF32CD32); // Forest Green for gradients
  static const Color textColor = Color(0xFFFFFFFF); // Pure White
  static const Color secondaryTextColor = Color(0xFFAAAAAA); // Muted Grey
  static const Color errorColor = Color(0xFFFF3131); // Neon Red

  static ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: primaryColor,
    scaffoldBackgroundColor: backgroundColor,
    cardColor: surfaceColor,
    colorScheme: const ColorScheme.dark(
      primary: primaryColor,
      secondary: accentColor,
      surface: surfaceColor,
      background: backgroundColor,
      error: errorColor,
    ),
    textTheme: GoogleFonts.outfitTextTheme().copyWith(
      displayLarge: GoogleFonts.outfit(
        fontSize: 32,
        fontWeight: FontWeight.w900,
        color: textColor,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      bodyLarge: GoogleFonts.outfit(
        fontSize: 18,
        color: textColor,
      ),
      bodyMedium: GoogleFonts.outfit(
        fontSize: 16,
        color: secondaryTextColor,
      ),
    ),
    appBarTheme: AppBarTheme(
      backgroundColor: backgroundColor,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: GoogleFonts.outfit(
        fontSize: 20,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
      iconTheme: const IconThemeData(color: textColor),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primaryColor,
        foregroundColor: Colors.black, // Dark text on light green
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.w800,
        ),
        elevation: 0,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: primaryColor,
        side: const BorderSide(color: primaryColor, width: 2),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 32),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        textStyle: GoogleFonts.outfit(
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surfaceColor,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Color(0xFF2A2A2A), width: 1.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: primaryColor, width: 2),
      ),
      labelStyle: const TextStyle(color: secondaryTextColor),
      hintStyle: const TextStyle(color: Color(0xFF444444)),
      prefixIconColor: secondaryTextColor,
    ),
  );
}
