import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Design system tokens and Theme definitions
/// Apple-inspired Premium Black & White Dark Aesthetic:
/// Pure black (#000000), subtle charcoal levels (#080808, #111111, #181818, #101010),
/// crisp white (#FFFFFF), refined secondary grays (#B3B3B3, #777777),
/// precision monochrome borders (#292929, #202020), with selective semantic status indicators
/// and preserved vibrant category/bank icon artwork.
class AppTheme {
  // 1. Core Apple-Inspired Monochrome Palette
  static const Color pureBlack = Color(
    0xFF000000,
  ); // Main background: pure black
  static const Color secondaryBlack = Color(
    0xFF080808,
  ); // Subtle section separation
  static const Color cardCharcoal = Color(
    0xFF111111,
  ); // Standard cards & containers
  static const Color elevatedCharcoal = Color(
    0xFF181818,
  ); // Elevated cards & floating panels
  static const Color inputCharcoal = Color(
    0xFF101010,
  ); // Inputs, search fields, filters

  // 2. Monochromatic Text & Accents
  static const Color pureWhite = Color(
    0xFFFFFFFF,
  ); // Primary text, headings, balances
  static const Color secondaryGray = Color(
    0xFFB3B3B3,
  ); // Subtitles, labels, descriptions
  static const Color tertiaryGray = Color(
    0xFF777777,
  ); // Inactive labels, hints, placeholders
  static const Color disabledGray = Color(
    0xFF454545,
  ); // Disabled controls, inactive tracks

  // 3. Precision Borders & Dividers
  static const Color borderPrimary = Color(
    0xFF292929,
  ); // Card outlines, input borders
  static const Color borderSecondary = Color(
    0xFF202020,
  ); // Internal dividers & subtle edges
  static const Color borderTertiary = Color(
    0xFF383838,
  ); // Outlined buttons, switch tracks

  // 4. Aliases for Clean Backwards Compatibility
  static const Color primaryBackground = pureBlack;
  static const Color secondaryBackground = secondaryBlack;
  static const Color elevatedCardBackground = cardCharcoal;
  static const Color glassSurface = cardCharcoal;
  static const Color glassSurfaceLight = elevatedCharcoal;

  // Primary accent is pure white for a crisp monochrome identity
  static const Color primaryAccent = pureWhite;
  static const Color secondaryAccent = secondaryGray;
  static const Color highlightMint = pureWhite;
  static const Color glowTeal = Colors.transparent;

  // Brand Accents & Semantic Financial Status Indicators
  static const Color primaryGreen =
      emeraldAccent; // Teal/emerald brand accent (#10B981)
  static const Color incomeGreen = Color(
    0xFF34D399,
  ); // Semantic income indicator
  static const Color expenseRed = Color(
    0xFFF87171,
  ); // Semantic expense/alert indicator
  static const Color transferBlue = Color(
    0xFF38BDF8,
  ); // Semantic transfer indicator
  static const Color accentAmber = Color(
    0xFFFBBF24,
  ); // Semantic warning indicator
  static const Color accentPurple = Color(0xFFA78BFA);
  static const Color accentTeal = Color(0xFF14B8A6);
  static const Color accentBlue = Color(0xFF38BDF8);
  static const Color accentCoral = Color(0xFFFB7185);
  static const Color accentIndigo = Color(0xFF818CF8);
  static const Color emeraldAccent = Color(0xFF10B981);
  static const Color emeraldLight = Color(0xFF202020);
  static const Color emeraldDarkContainer = Color(0xFF181818);

  // Backward Compatibility Navy Aliases
  static const Color primaryNavy = Color(
    0xFF0F172A,
  ); // Deep slate navy for secondary dark actions
  static const Color deepNavy = pureBlack;
  static const Color navyCardDark = cardCharcoal;
  static const Color navyElevatedDark = elevatedCharcoal;

  // Typography Tokens
  static const Color primaryText = pureWhite;
  static const Color secondaryText = secondaryGray;
  static const Color mutedText = tertiaryGray;
  static const Color borderGlass = borderPrimary;
  static const Color borderSubtle = borderSecondary;

  // Light Mode Tokens (Clean high-contrast pairing)
  static const Color bgLight = Color(0xFFF8F9FA);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceSubtleLight = Color(0xFFF1F3F5);
  static const Color textDark = Color(0xFF111111);
  static const Color textSecondaryLight = Color(0xFF666666);
  static const Color borderLight = Color(0xFFE5E7EB);

  // Dark Mode Tokens
  static const Color bgDark = pureBlack;
  static const Color surfaceDark = cardCharcoal;
  static const Color surfaceSubtleDark = secondaryBlack;
  static const Color textLight = pureWhite;
  static const Color textSecondaryDark = secondaryGray;
  static const Color borderDark = borderPrimary;

  /// Pure Minimalist Monochrome Gradients (Black to Charcoal only)
  static const LinearGradient glassCardGradient = LinearGradient(
    colors: [Color(0xFF161616), Color(0xFF0F0F0F)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Wallet Hero Balance Card Gradient (Deep refined charcoal to black)
  static const LinearGradient walletHeroGradient = LinearGradient(
    colors: [Color(0xFF181818), Color(0xFF111111), Color(0xFF080808)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  /// Floating Capsule Navigation Gradient (Solid dark charcoal/black)
  static const LinearGradient floatingCapsuleGradient = LinearGradient(
    colors: [Color(0xFF141414), Color(0xFF0A0A0A)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: const ColorScheme.light(
        primary: textDark,
        onPrimary: Colors.white,
        primaryContainer: surfaceSubtleLight,
        onPrimaryContainer: textDark,
        secondary: Color(0xFF444444),
        onSecondary: Colors.white,
        secondaryContainer: surfaceSubtleLight,
        onSecondaryContainer: textDark,
        surface: surfaceLight,
        onSurface: textDark,
        error: expenseRed,
        onError: Colors.white,
      ),
      scaffoldBackgroundColor: bgLight,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
          statusBarBrightness: Brightness.light,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.dark,
        ),
        titleTextStyle: TextStyle(
          color: textDark,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: textDark),
      ),
      cardTheme: CardThemeData(
        color: surfaceLight,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderLight, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceSubtleLight,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderLight, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: textDark, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: expenseRed, width: 1),
        ),
        hintStyle: const TextStyle(color: textSecondaryLight, fontSize: 14),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfaceLight,
        selectedItemColor: textDark,
        unselectedItemColor: textSecondaryLight,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: const ColorScheme.dark(
        primary: pureWhite,
        onPrimary: pureBlack,
        primaryContainer: elevatedCharcoal,
        onPrimaryContainer: pureWhite,
        secondary: secondaryGray,
        onSecondary: pureBlack,
        surface: cardCharcoal,
        onSurface: pureWhite,
        error: expenseRed,
        onError: pureWhite,
      ),
      scaffoldBackgroundColor: pureBlack,
      fontFamily: 'Roboto',
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
          systemNavigationBarColor: Colors.transparent,
          systemNavigationBarIconBrightness: Brightness.light,
        ),
        titleTextStyle: TextStyle(
          color: pureWhite,
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.3,
        ),
        iconTheme: IconThemeData(color: pureWhite),
      ),
      cardTheme: CardThemeData(
        color: cardCharcoal,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: borderPrimary, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: borderSecondary,
        thickness: 1,
        space: 1,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputCharcoal,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: borderPrimary, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: pureWhite, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: expenseRed, width: 1),
        ),
        hintStyle: const TextStyle(color: tertiaryGray, fontSize: 14),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primaryGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: pureWhite,
          side: const BorderSide(color: borderTertiary, width: 1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: primaryGreen),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: secondaryBlack,
        selectedItemColor: pureWhite,
        unselectedItemColor: tertiaryGray,
        selectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 12,
        ),
        unselectedLabelStyle: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 12,
        ),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
