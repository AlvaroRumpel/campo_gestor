/// Compile-time configuration injected via `--dart-define`.
///
/// Usage (local dev):
///   flutter run --dart-define=APP_ORIGIN=http://127.0.0.1:3000
///
/// Usage (production build):
///   flutter build web \
///     --dart-define=SUPABASE_URL=https://xxx.supabase.co \
///     --dart-define=SUPABASE_ANON_KEY=<key> \
///     --dart-define=APP_ORIGIN=https://app.campogestor.com.br
///
/// Never hard-code production URLs or secrets in source files.
class AppConfig {
  const AppConfig._();

  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

  /// Origin used to build auth redirect URLs (e.g. password-reset link).
  /// Defaults to the local Flutter web dev server. Override in CI/production
  /// via --dart-define=APP_ORIGIN=https://your-domain.
  static const appOrigin = String.fromEnvironment(
    'APP_ORIGIN',
    defaultValue: 'http://127.0.0.1:3000', // local dev only
  );
}
