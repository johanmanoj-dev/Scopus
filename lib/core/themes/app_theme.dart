import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Dark Academic Color Palette
  static const Color background = Color(0xFF000000); // Pure Black
  static const Color surface = Color(0xFF121212); // Dark Grey
  static const Color surfaceVariant = Color(0xFF1E1E1E); // Lighter for contrast
  
  static const Color primary = Color(0xFF8B0000); // Muted Crimson
  static const Color primaryVariant = Color(0xFFC3073F); // Brighter Crimson for hover/active
  static const Color secondary = Color(0xFFB8860B); // Dark Gold
  static const Color accent = Color(0xFF2E4A3D); // Deep Green
  
  static const Color textPrimary = Color(0xFFF0EBE1); // Parchment White
  static const Color textSecondary = Color(0xFFA0A0A0); // Muted Grey
  
  static ThemeData get darkAcademicTheme {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
        surfaceContainerHighest: surfaceVariant,
        onSurface: textPrimary,
      ),
      textTheme: TextTheme(
        // Headings (Modern Sans-Serif to match mockup)
        displayLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.bold, color: textPrimary),
        displayMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.bold, color: textPrimary),
        headlineLarge: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary),
        headlineMedium: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        titleLarge: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.w600, color: textPrimary),
        
        // Body (Sans-Serif)
        bodyLarge: GoogleFonts.inter(fontSize: 16, color: textPrimary),
        bodyMedium: GoogleFonts.inter(fontSize: 14, color: textPrimary),
        bodySmall: GoogleFonts.inter(fontSize: 12, color: textSecondary),
        labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFF333333),
        thickness: 1,
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        selectedTileColor: primary.withValues(alpha: 0.15),
        selectedColor: primaryVariant,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      iconTheme: const IconThemeData(
        color: textSecondary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbVisibility: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return true;
          }
          return false;
        }),
        thickness: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged)) {
            return 8.0;
          }
          return 4.0;
        }),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.dragged)) {
            return textSecondary.withValues(alpha: 0.8);
          }
          if (states.contains(WidgetState.hovered)) {
            return textSecondary.withValues(alpha: 0.5);
          }
          return textSecondary.withValues(alpha: 0.3);
        }),
      ),
    );
  }
}
