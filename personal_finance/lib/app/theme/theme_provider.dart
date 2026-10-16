import 'package:flutter/material.dart';
import 'package:sqflite/sqflite.dart';
import 'package:personal_finance/core/database/database_helper.dart';

class ThemeProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.dark;

  ThemeMode get themeMode => _themeMode;

  bool get isDarkMode {
    return _themeMode != ThemeMode.light;
  }

  Future<void> loadTheme() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final List<Map<String, dynamic>> res = await db.query(
        'app_settings',
        where: 'key = ?',
        whereArgs: ['theme_mode'],
      );
      if (res.isNotEmpty) {
        final val = res.first['value'] as String?;
        if (val == 'light') {
          _themeMode = ThemeMode.light;
        } else {
          // Default to dark theme
          _themeMode = ThemeMode.dark;
        }
        notifyListeners();
      } else {
        _themeMode = ThemeMode.dark;
      }
    } catch (e) {
      debugPrint('Error loading theme: $e');
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();

    try {
      final db = await DatabaseHelper.instance.database;
      String strVal = 'system';
      if (mode == ThemeMode.light) strVal = 'light';
      if (mode == ThemeMode.dark) strVal = 'dark';

      await db.insert('app_settings', {
        'key': 'theme_mode',
        'value': strVal,
      }, conflictAlgorithm: ConflictAlgorithm.replace);
    } catch (e) {
      debugPrint('Error saving theme: $e');
    }
  }
}
