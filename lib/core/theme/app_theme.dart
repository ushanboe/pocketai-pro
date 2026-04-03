// Step 1: Inventory
// This file DEFINES: AppTheme class with static darkTheme ThemeData getter
// It uses: google_fonts package for Inter and JetBrains Mono fonts
// No imports from other project files needed — pure theme definition
//
// Step 2: Connections
// This file is imported by main.dart and potentially other screens
// It exports AppTheme.darkTheme which is used as the app's theme
// No navigation needed in this file
//
// Step 3: User Journey Trace
// This is a pure theme file — no user interaction, just ThemeData configuration
// All colors, typography, input decoration, bottom nav, slider, card themes must be defined
//
// Step 4: Layout Sanity
// No widgets here — pure ThemeData configuration
// Must use ColorScheme.dark() factory (NOT deprecated background/onBackground)
// Must use CardThemeData not CardTheme
// Must use surfaceContainerHighest not surfaceVariant
// Colors from spec:
//   primary: 0xFF3B82F6 (blue)
//   secondary: 0xFF8B5CF6 (purple)
//   surface: 0xFF0F172A (dark navy)
//   surfaceContainer: 0xFF1E293B (slightly lighter navy)
//   onSurface: 0xFFFFFFFF (white)
//   onSurfaceVariant: 0xFF94A3B8 (muted blue-gray)
//   outline: 0xFF334155
//   error: 0xFFEF4444
//   success: 0xFF22C55E

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF3B82F6);
  static const Color _secondary = Color(0xFF8B5CF6);
  static const Color _surface = Color(0xFF0F172A);
  static const Color _surfaceContainer = Color(0xFF1E293B);
  static const Color _onSurface = Color(0xFFFFFFFF);
  static const Color _onSurfaceVariant = Color(0xFF94A3B8);
  static const Color _outline = Color(0xFF334155);
  static const Color _error = Color(0xFFEF4444);
  static const Color _success = Color(0xFF22C55E);
  static const Color _unselectedItem = Color(0xFF64748B);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      secondary: _secondary,
      surface: _surface,
      onSurface: _onSurface,
      onSecondary: _onSurface,
      error: _error,
      onError: _onSurface,
      outline: _outline,
      onPrimary: _onSurface,
      surfaceContainerHighest: _surfaceContainer,
      onSurfaceVariant: _onSurfaceVariant,
    );

    final baseTextTheme = GoogleFonts.interTextTheme(
      ThemeData.dark().textTheme,
    );

    final textTheme = baseTextTheme.copyWith(
      displayLarge: GoogleFonts.inter(
        fontSize: 32,
        fontWeight: FontWeight.bold,
        color: _onSurface,
      ),
      displayMedium: GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.bold,
        color: _onSurface,
      ),
      displaySmall: GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.bold,
        color: _onSurface,
      ),
      headlineLarge: GoogleFonts.inter(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      headlineMedium: GoogleFonts.inter(
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      headlineSmall: GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: _onSurface,
      ),
      titleMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _onSurface,
      ),
      titleSmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.normal,
        color: _onSurface,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.normal,
        color: _onSurface,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.normal,
        color: _onSurfaceVariant,
      ),
      labelLarge: GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: _onSurface,
      ),
      labelMedium: GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: _onSurfaceVariant,
      ),
      labelSmall: GoogleFonts.inter(
        fontSize: 10,
        fontWeight: FontWeight.w400,
        color: _onSurfaceVariant,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _surface,
      cardColor: _surfaceContainer,
      textTheme: textTheme,
      appBarTheme: AppBarTheme(
        backgroundColor: _surface,
        elevation: 0,
        scrolledUnderElevation: 0,
        iconTheme: const IconThemeData(color: _onSurface),
        actionsIconTheme: const IconThemeData(color: _onSurface),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        centerTitle: false,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surfaceContainer,
        selectedItemColor: _primary,
        unselectedItemColor: _unselectedItem,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        selectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
        unselectedLabelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: _primary,
        thumbColor: _primary,
        inactiveTrackColor: _outline,
        overlayColor: Color(0x293B82F6),
        valueIndicatorColor: _primary,
        valueIndicatorTextStyle: TextStyle(
          color: _onSurface,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surfaceContainer,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: _error, width: 2),
        ),
        hintStyle: const TextStyle(color: _unselectedItem),
        labelStyle: const TextStyle(color: _onSurfaceVariant),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
      ),
      cardTheme: CardThemeData(
        color: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _outline, width: 0.5),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 4),
      ),
      dividerTheme: const DividerThemeData(
        color: _outline,
        thickness: 0.5,
        space: 0,
      ),
      iconTheme: const IconThemeData(
        color: _onSurface,
        size: 24,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: _onSurface,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _primary,
          side: const BorderSide(color: _primary),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          textStyle: GoogleFonts.inter(
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return _unselectedItem;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.3);
          }
          return _outline;
        }),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return Colors.transparent;
        }),
        checkColor: WidgetStateProperty.all(_onSurface),
        side: const BorderSide(color: _outline, width: 1.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(4),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: _surfaceContainer,
        selectedColor: _primary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: _onSurface,
        ),
        side: const BorderSide(color: _outline, width: 0.5),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      ),
      drawerTheme: const DrawerThemeData(
        backgroundColor: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topRight: Radius.circular(0),
            bottomRight: Radius.circular(0),
          ),
        ),
      ),
      listTileTheme: ListTileThemeData(
        tileColor: Colors.transparent,
        selectedTileColor: _primary.withValues(alpha: 0.1),
        iconColor: _onSurfaceVariant,
        textColor: _onSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _surfaceContainer,
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _onSurface,
        ),
        actionTextColor: _primary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: _surfaceContainer,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: GoogleFonts.inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: _onSurface,
        ),
        contentTextStyle: GoogleFonts.inter(
          fontSize: 14,
          color: _onSurfaceVariant,
        ),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
        linearTrackColor: _outline,
        circularTrackColor: _outline,
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: _onSurface,
        elevation: 4,
        shape: CircleBorder(),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _surfaceContainer,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _outline, width: 0.5),
        ),
        textStyle: GoogleFonts.inter(
          fontSize: 12,
          color: _onSurface,
        ),
      ),
    );
  }

  /// Static color constants for use throughout the app
  static const Color primaryColor = _primary;
  static const Color secondaryColor = _secondary;
  static const Color surfaceColor = _surface;
  static const Color surfaceContainerColor = _surfaceContainer;
  static const Color onSurfaceColor = _onSurface;
  static const Color onSurfaceVariantColor = _onSurfaceVariant;
  static const Color outlineColor = _outline;
  static const Color errorColor = _error;
  static const Color successColor = _success;
  static const Color unselectedColor = _unselectedItem;

  /// Returns a TextStyle using JetBrains Mono for code blocks
  static TextStyle codeTextStyle({
    double fontSize = 13,
    Color color = _onSurface,
  }) {
    return GoogleFonts.jetBrainsMono(
      fontSize: fontSize,
      color: color,
      fontWeight: FontWeight.normal,
    );
  }

  /// Returns a TextStyle using Inter for regular text
  static TextStyle interTextStyle({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = _onSurface,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
    );
  }
}