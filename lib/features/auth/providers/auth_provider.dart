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
        if (err is AuthException) {
          // Session is gone — force unauthenticated state so the router
          // redirects to /login. Non-AuthException errors (socket, etc.) keep
          // the last known state; the router will retry on the next auth event.
          state = const AsyncData(null);
        }
        // Non-auth errors (e.g. SocketException on refresh): keep last known
        // state — the user may still be online and the session may recover.
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
