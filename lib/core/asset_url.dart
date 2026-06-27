import 'constants.dart';

/// Resolve a backend asset path to a fetchable URL.
///
/// The backend stores avatars / gallery / shop logos as relative paths like
/// `/uploads/avatars/<hash>.jpg`. CachedNetworkImage needs an absolute URL,
/// so prepend the API base. Already-absolute http(s) URLs pass through
/// untouched (admin can store external CDN paths).
///
/// Returns an empty string for null / empty so callers can branch on it
/// with the usual `.isNotEmpty` check without an additional null guard.
String assetUrl(String? path) {
  if (path == null || path.isEmpty) return '';
  if (path.startsWith('http://') || path.startsWith('https://')) return path;
  if (path.startsWith('/')) return '${AppConfig.apiUrl}$path';
  return '${AppConfig.apiUrl}/$path';
}
