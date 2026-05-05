import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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

  /// Reset email lands here. Must match supabase/config.toml
  /// `additional_redirect_urls`. http://127.0.0.1:3000 is the dev URL
  /// served by `flutter run -d edge`.
  static const String resetRedirect =
      'http://127.0.0.1:3000/reset-password';

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) =>
      _service.auth.signUp(email: email, password: password);

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
