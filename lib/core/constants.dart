/// Runtime constants. API URL deliberately hard-coded — we ship one binary per
/// store and don't expose dev backends in production. If a staging build is
/// needed later, switch with --dart-define=API_URL=... at build time and read
/// it via const String.fromEnvironment.
class AppConfig {
  AppConfig._();

  /// Backend root. Matches the production NestJS server behind api.barberbook.uz.
  static const String apiUrl = 'https://api.barberbook.uz';

  /// Storage keys
  static const String tokenKey = 'auth_token';
  static const String refreshTokenKey = 'auth_refresh_token';
  static const String userKey = 'auth_user';

  /// Supported locales — same set as the web (Lotin, Kirill, Russian, English).
  static const List<String> supportedLanguages = ['uz', 'uz_cyr', 'ru', 'en'];
  static const String defaultLanguage = 'uz';
}
