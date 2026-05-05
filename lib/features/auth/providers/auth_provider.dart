import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/supabase_providers.dart';

/// Reactive view of the current Supabase auth state.
///
/// Subscribes to `GoTrueClient.onAuthStateChange` and exposes the latest
/// [AuthState] (or null if no session). The router watches this provider
/// via [GoRouterRefreshStream] (already wired in Phase 0) plus an explicit
/// `ref.read` in the redirect closure.
///
/// Pitfall guard (RESEARCH.md Pitfall 1): consumers MUST check
/// `asyncValue.isLoading` before deciding on redirects to avoid bouncing
/// the user to /login on cold start while the initial build() resolves.
class AuthNotifier extends AsyncNotifier<AuthState?> {
  StreamSubscription<AuthState>? _sub;

  @override
  Future<AuthState?> build() async {
    final service = ref.watch(supabaseServiceProvider);

    _sub?.cancel();
    _sub = service.auth.onAuthStateChange.listen(
      (data) {
        // Update state on each auth event (signedIn, signedOut, passwordRecovery, etc.)
        state = AsyncData(data);
      },
      onError: (Object err, StackTrace st) {
        // Network errors during refresh — keep last known state, don't crash.
      },
    );
    ref.onDispose(() => _sub?.cancel());

    final session = service.auth.currentSession;
    if (session == null) return null;
    return AuthState(AuthChangeEvent.initialSession, session);
  }
}

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AuthState?>(AuthNotifier.new);
