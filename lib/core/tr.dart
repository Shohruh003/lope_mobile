import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'l10n.dart';

/// Tiny helper: `tr(ref, 'mobile.common.save', 'Saqlash')` looks up the i18n
/// key against the active locale and falls back to the hard-coded Uzbek
/// string if the key (or the JSON file) hasn't shipped a translation yet.
/// This means the app stays usable while the JSON files are being filled in
/// across all 4 locales — no "barberLink.title" strings leaking into the UI.
String tr(WidgetRef ref, String key, String fallback, [Map<String, String>? vars]) {
  final l10n = ref.watch(localeProvider).asData?.value;
  if (l10n == null) return _interpolate(fallback, vars);
  final v = l10n.t(key, vars);
  if (v == key) return _interpolate(fallback, vars);
  return v;
}

String _interpolate(String s, Map<String, String>? vars) {
  if (vars == null || vars.isEmpty) return s;
  var out = s;
  vars.forEach((k, v) => out = out.replaceAll('{{$k}}', v));
  return out;
}

/// Array-valued lookup. Returns the JSON array at `key`, or `fallback`
/// when the active locale doesn't ship one (e.g. while the JSON files
/// are being filled in). Used for month/weekday names where a single
/// string isn't expressive enough.
List<String> trList(WidgetRef ref, String key, List<String> fallback) {
  final l10n = ref.watch(localeProvider).asData?.value;
  if (l10n == null) return fallback;
  final v = l10n.tList(key);
  if (v.isEmpty) return fallback;
  return v;
}
