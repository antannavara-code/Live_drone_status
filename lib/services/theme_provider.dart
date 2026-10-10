import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeModeProvider extends ValueNotifier<bool> {
  ThemeModeProvider._() : super(true);

  static final ThemeModeProvider instance = ThemeModeProvider._();

  static const String _prefsKey = 'theme_dark';

  bool get isDark => value;

  static Future<void> load() async {
    final prefs = await SharedPreferences.getInstance();
    instance.value = prefs.getBool(_prefsKey) ?? true;
  }

  Future<void> toggle() async {
    value = !value;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_prefsKey, value);
  }
}

class AppColors {
  AppColors._();

  static bool get _isDark => ThemeModeProvider.instance.isDark;

  static Color on(Color dark, Color light) => _isDark ? dark : light;

  static Color get scaffold => on(const Color(0xFF071018), const Color(0xFFF2F5FA));
  static Color get scaffoldAlt =>
      on(const Color(0xFF0A0F1E), const Color(0xFFE9EDF3));
  static Color get panel => on(const Color(0xFF0F1B27), const Color(0xFFFFFFFF));
  static Color get panelAlt =>
      on(const Color(0xFF151B2B), const Color(0xFFFFFFFF));
  static Color get surface =>
      on(const Color(0xFF132638), const Color(0xFFE2E8F0));
  static Color get surfaceAlt =>
      on(const Color(0xFF0F2633), const Color(0xFFDCE3EC));
  static Color get tileActive =>
      on(const Color(0xFF132638), const Color(0xFFD9E4F0));
  static Color get tileInactive =>
      on(const Color(0xFF0F1D2A), const Color(0xFFEDF1F6));
  static Color get videoBg => on(const Color(0xFF101C28), const Color(0xFF0F172A));
  static Color get sidebar =>
      on(const Color(0xFF0B1520), const Color(0xFFE3EAF2));

  static Color get border => on(const Color(0xFF1F2937), const Color(0xFFD8DEE8));
  static Color get borderSubtle =>
      _isDark ? Colors.white10 : const Color(0xFFDCE2EB);

  static Color get textPrimary => on(Colors.white, const Color(0xFF0F172A));
  static Color get textSecondary => on(Colors.white70, const Color(0xFF334155));
  static Color get textMuted => on(Colors.white54, const Color(0xFF475569));
  static Color get textFaint => on(Colors.white38, const Color(0xFF94A3B8));
  static Color get textOnAccent => on(const Color(0xFF061018), Colors.white);

  static Color get primary => const Color(0xFF1D9E75);
  static Color get primaryBright => const Color(0xFF4CE0B3);
  static Color get warning => const Color(0xFFF59E0B);
  static Color get warningBright => const Color(0xFFFFB84D);
  static Color get danger => const Color(0xFFE53935);
  static Color get dangerBright => const Color(0xFFFF5A6B);
  static Color get info => const Color(0xFF00BCD4);
  static Color get infoBright => const Color(0xFF4DD0E1);
  static Color get blue => const Color(0xFF6EA8FE);
  static Color get blueBright => const Color(0xFF4da6ff);
  static Color get purple => const Color(0xFFC084FC);
}
