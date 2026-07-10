import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent theme-mode preference (system / light / dark). Stored in
/// SharedPreferences so it survives app restarts. MaterialApp.router
/// reads this and dispatches between the two ThemeData instances built
/// in app/theme.dart.
///
/// NOTE — most of the app's colours are hard-coded via `AppColors.*`
/// today, so light mode currently only affects framework widgets
/// (buttons, dialogs, text fields at the Material level). Full palette
/// theming is a follow-up refactor; the toggle is wired now so the
/// preference at least persists and the switch UI exists.
class ThemeModeNotifier extends AsyncNotifier<ThemeMode> {
  static const _prefsKey = 'app_theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    return _decode(saved);
  }

  Future<void> setMode(ThemeMode mode) async {
    state = AsyncValue.data(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, _encode(mode));
  }

  static String _encode(ThemeMode m) => switch (m) {
        ThemeMode.light => 'light',
        ThemeMode.dark => 'dark',
        ThemeMode.system => 'system',
      };

  static ThemeMode _decode(String? raw) => switch (raw) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}

final themeModeProvider =
    AsyncNotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);
