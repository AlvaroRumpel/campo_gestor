import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/config/app_config.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';

/// Repository for authentication operations.
///
/// Per CLAUDE.md "What NOT to Use" and Phase 0 Repository pattern: features
/// NEVER import `package:supabase_flutter` directly into widgets. All GoTrue
/// calls flow through this class via [authRepositoryProvider].
class AuthRepository {
  AuthRepository(this._service);
  final SupabaseService _service;

  /// Reset email redirect URL, built from the injected [AppConfig.appOrigin].
  ///
  /// Must be listed in supabase/config.toml `additional_redirect_urls` (local)
  /// and in the production Supabase project's allowed redirect URLs.
  /// Inject the origin at build time:
  ///   flutter run --dart-define=APP_ORIGIN=http://127.0.0.1:3000
  ///   flutter build web --dart-define=APP_ORIGIN=https://app.campogestor.com.br
  static String get resetRedirect =>
      '${AppConfig.appOrigin}/reset-password';

  /// Signup confirmation email links back to the bare [AppConfig.appOrigin]
  /// (unlike [resetRedirect], no extra path segment is appended).
  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _service.auth.signUp(
        email: email,
        password: password,
        emailRedirectTo: AppConfig.appOrigin,
      );

  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) =>
      _service.auth.signInWithPassword(email: email, password: password);

  Future<void> signOut() => _service.auth.signOut();

  Future<void> resetPasswordForEmail(String email) =>
      _service.auth.resetPasswordForEmail(email, redirectTo: resetRedirect);

  Future<UserResponse> updatePassword(String newPassword) =>
      _service.auth.updateUser(UserAttributes(password: newPassword));
}

final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(ref.watch(supabaseServiceProvider)),
);
