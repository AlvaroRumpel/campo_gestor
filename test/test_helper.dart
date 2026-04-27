// Test helper utilities — loaded via dart-define for local Supabase.
//
// Provides default Supabase URL and anon key when running tests without
// passing --dart-define explicitly. Defaults match the local Supabase
// CLI stack (`supabase start`).

String testSupabaseUrl() => const String.fromEnvironment(
      'SUPABASE_URL',
      defaultValue: 'http://localhost:54321',
    );

String testSupabaseAnonKey() => const String.fromEnvironment(
      'SUPABASE_ANON_KEY',
      defaultValue: 'test-anon-key-placeholder',
    );
