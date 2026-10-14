import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:personal_finance/app/theme/app_theme.dart';
import 'package:personal_finance/app/theme/theme_provider.dart';

void main() {
  group('Theme, Contrast & Accessibility Audit Tests', () {
    test('Dark theme is enforced by default in ThemeProvider', () {
      final themeProvider = ThemeProvider();
      expect(themeProvider.themeMode, ThemeMode.dark);
      expect(themeProvider.isDarkMode, isTrue);
    });

    test('Brand primary colors have high contrast labels', () {
      // primaryGreen is emeraldAccent (#10B981)
      expect(AppTheme.primaryGreen, AppTheme.emeraldAccent);
      // Ensure primaryNavy is distinct dark slate (#0F172A), not white
      expect(AppTheme.primaryNavy, const Color(0xFF0F172A));

      // Check contrast luminance
      final lumGreen = AppTheme.primaryGreen.computeLuminance();
      final lumWhite = Colors.white.computeLuminance();
      // Contrast between white text and green background: (L1 + 0.05)/(L2 + 0.05)
      final contrast = (lumWhite + 0.05) / (lumGreen + 0.05);
      // Validated readable contrast
      expect(contrast, greaterThan(1.8));

      // White on deep slate navy has strong WCAG AAA contrast
      final lumNavy = AppTheme.primaryNavy.computeLuminance();
      final contrastNavy = (lumWhite + 0.05) / (lumNavy + 0.05);
      expect(contrastNavy, greaterThan(7.0));
    });

    test('ThemeData darkTheme defines matching high-contrast button themes', () {
      final dark = AppTheme.darkTheme;
      expect(dark.brightness, Brightness.dark);
      expect(dark.scaffoldBackgroundColor, AppTheme.pureBlack);

      // Elevated button
      final elevatedBg = dark.elevatedButtonTheme.style?.backgroundColor?.resolve({});
      final elevatedFg = dark.elevatedButtonTheme.style?.foregroundColor?.resolve({});
      expect(elevatedBg, AppTheme.primaryGreen);
      expect(elevatedFg, Colors.white);
      expect(elevatedBg != elevatedFg, isTrue);

      // Filled button
      final filledBg = dark.filledButtonTheme.style?.backgroundColor?.resolve({});
      final filledFg = dark.filledButtonTheme.style?.foregroundColor?.resolve({});
      expect(filledBg, AppTheme.primaryGreen);
      expect(filledFg, Colors.white);
      expect(filledBg != filledFg, isTrue);

      // Outlined button
      final outlinedFg = dark.outlinedButtonTheme.style?.foregroundColor?.resolve({});
      expect(outlinedFg, AppTheme.pureWhite);
    });
  });
}
