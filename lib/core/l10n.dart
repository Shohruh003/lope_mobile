import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'constants.dart';

/// Lightweight in-app i18n. The web app ships the same four locales as JSON
/// files; we read those exact files from /assets/i18n and look up keys via
/// dot paths like `common.save` or `barberLink.title`. This keeps the mobile
/// strings identical to the web ones with zero re-translation effort.
class L10n {
  L10n(this.locale, this._table);

  final String locale;
  final Map<String, dynamic> _table;

  /// Look up a dotted key like `common.save`. Returns the raw string if found,
  /// or the key itself as a fallback so missing translations are visible
  /// during dev instead of crashing.
  String t(String key, [Map<String, String>? vars]) {
    final segments = key.split('.');
    dynamic node = _table;
    for (final s in segments) {
      if (node is Map<String, dynamic> && node.containsKey(s)) {
        node = node[s];
      } else {
        return key;
      }
    }
    var out = node is String ? node : key;
    if (vars != null) {
      vars.forEach((k, v) => out = out.replaceAll('{{$k}}', v));
    }
    return out;
  }

  /// Look up a dotted key whose value is a JSON array of strings (e.g.
  /// month or weekday names). Returns the strings in order, or an empty
  /// list if the key isn't found / isn't an array — callers can fall
  /// back to a hardcoded list when the result is empty.
  List<String> tList(String key) {
    final segments = key.split('.');
    dynamic node = _table;
    for (final s in segments) {
      if (node is Map<String, dynamic> && node.containsKey(s)) {
        node = node[s];
      } else {
        return const [];
      }
    }
    if (node is List) {
      return node.map((e) => e.toString()).toList(growable: false);
    }
    return const [];
  }

  static Future<L10n> load(String locale) async {
    final raw = await rootBundle.loadString('assets/i18n/$locale.json');
    return L10n(locale, jsonDecode(raw) as Map<String, dynamic>);
  }
}

/// Locale preference is stored in SharedPreferences so the choice survives
/// app restarts. The initial value comes from defaultLanguage until the user
/// picks one.
class LocaleNotifier extends AsyncNotifier<L10n> {
  static const _prefsKey = 'app_locale';

  @override
  Future<L10n> build() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_prefsKey);
    final locale = (saved != null && AppConfig.supportedLanguages.contains(saved))
        ? saved
        : AppConfig.defaultLanguage;
    return L10n.load(locale);
  }

  /// Switch the active locale at runtime. The whole UI rebuilds because the
  /// provider is watched at the root of the widget tree.
  Future<void> setLocale(String locale) async {
    if (!AppConfig.supportedLanguages.contains(locale)) return;
    state = const AsyncValue.loading();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefsKey, locale);
    state = AsyncValue.data(await L10n.load(locale));
  }
}

final localeProvider = AsyncNotifierProvider<LocaleNotifier, L10n>(LocaleNotifier.new);
