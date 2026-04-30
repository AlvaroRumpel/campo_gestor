/// Read Supabase env vars provided via `--dart-define`.
///
/// Per D-08 (CONTEXT.md), secrets enter through dart-define + .vscode/launch.json.
/// No .env files, no hardcoded keys.
abstract final class Env {
  static const String supabaseUrl =
      String.fromEnvironment('SUPABASE_URL', defaultValue: '');

  static const String supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: '');

  /// Throws [StateError] when either env var is empty.
  /// Call once in main() BEFORE Supabase.initialize.
  static void requireOrThrow() {
    if (supabaseUrl.isEmpty || supabaseAnonKey.isEmpty) {
      throw StateError(
        'SUPABASE_URL e SUPABASE_ANON_KEY são obrigatórios. '
        'Use --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=... '
        '(see .vscode/launch.json.example).',
      );
    }
  }
}
