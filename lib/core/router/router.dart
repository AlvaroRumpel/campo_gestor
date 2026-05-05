import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/animais/presentation/animais_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/no_access_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/piquetes/presentation/piquetes_screen.dart';
import '../../features/reproducao/presentation/reproducao_screen.dart';
import '../../features/sanitario/presentation/sanitario_screen.dart';
import '../widgets/app_shell.dart';
import 'routes.dart';

final _rootKey = GlobalKey<NavigatorState>(debugLabel: 'root');
final _shellDashboardKey = GlobalKey<NavigatorState>(debugLabel: 'dashboard');
final _shellPiquetesKey = GlobalKey<NavigatorState>(debugLabel: 'piquetes');
final _shellAnimaisKey = GlobalKey<NavigatorState>(debugLabel: 'animais');
final _shellReproducaoKey = GlobalKey<NavigatorState>(debugLabel: 'reproducao');
final _shellSanitarioKey = GlobalKey<NavigatorState>(debugLabel: 'sanitario');

/// Provider exposing the singleton GoRouter for the app.
///
/// Phase 1 changes:
/// - Adds /login /signup /reset-password /sem-acesso routes (root-level, NOT shell).
/// - Replaces the permissive redirect with an auth guard that observes
///   [authNotifierProvider]. Pitfall 1: returns null while AsyncValue.isLoading
///   to avoid bouncing users on cold start. Pitfall 2: passwordRecovery is
///   checked BEFORE isLoggedIn so the user lands on /reset-password.
final routerProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      final authAsync = ref.read(authNotifierProvider);

      // Pitfall 1: don't redirect while initial auth resolution is pending.
      if (authAsync.isLoading) return null;

      final authState = authAsync.asData?.value;
      final session = authState?.session;
      final isLoggedIn = session != null;
      final isPasswordRecovery =
          authState?.event == AuthChangeEvent.passwordRecovery;

      final loc = state.matchedLocation;
      final onAuthRoute = AppRoutes.authRoutes.contains(loc);

      // Pitfall 2: passwordRecovery wins over signedIn. Send the user to
      // the new-password form even if they technically have a session.
      if (isPasswordRecovery && loc != AppRoutes.resetPassword) {
        return AppRoutes.resetPassword;
      }

      // Not logged in: only auth routes are reachable.
      if (!isLoggedIn) {
        return onAuthRoute ? null : AppRoutes.login;
      }

      // Logged in but sitting on /login or /signup: bounce to dashboard.
      // Stay on /reset-password (recovery flow may still be in progress) and
      // /sem-acesso (the user has no memberships — Plan 03 will route here).
      if (loc == AppRoutes.login || loc == AppRoutes.signup) {
        return AppRoutes.dashboard;
      }

      return null;
    },
    routes: [
      // Auth routes (root-level, outside the AppShell)
      GoRoute(
        path: AppRoutes.login,
        builder: (ctx, _) => const LoginScreen(),
      ),
      GoRoute(
        path: AppRoutes.signup,
        builder: (ctx, _) => const SignupScreen(),
      ),
      GoRoute(
        path: AppRoutes.resetPassword,
        builder: (ctx, _) => const ResetPasswordScreen(),
      ),
      GoRoute(
        path: AppRoutes.noAccess,
        builder: (ctx, _) => const NoAccessScreen(),
      ),
      // Shell routes (Phase 0)
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            navigatorKey: _shellDashboardKey,
            routes: [
              GoRoute(
                path: AppRoutes.dashboard,
                builder: (ctx, _) => const DashboardScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellPiquetesKey,
            routes: [
              GoRoute(
                path: AppRoutes.piquetes,
                builder: (ctx, _) => const PiquetesScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellAnimaisKey,
            routes: [
              GoRoute(
                path: AppRoutes.animais,
                builder: (ctx, _) => const AnimaisScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellReproducaoKey,
            routes: [
              GoRoute(
                path: AppRoutes.reproducao,
                builder: (ctx, _) => const ReproducaoScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellSanitarioKey,
            routes: [
              GoRoute(
                path: AppRoutes.sanitario,
                builder: (ctx, _) => const SanitarioScreen(),
              ),
            ],
          ),
        ],
      ),
    ],
  );

  ref.onDispose(router.dispose);
  return router;
});

/// Adapter: turns a [Stream] into a [Listenable] that GoRouter can consume.
/// onError is mandatory — Supabase auth stream emits errors on token refresh
/// failure with bad network (RESEARCH.md Pitfall 2).
class GoRouterRefreshStream extends ChangeNotifier {
  GoRouterRefreshStream(Stream<dynamic> stream) {
    notifyListeners();
    _subscription = stream.asBroadcastStream().listen(
          (_) => notifyListeners(),
          onError: (_) {
            // Swallow stream errors to keep router alive across token refresh
            // failures. Real error handling lives at the auth layer.
          },
        );
  }

  late final StreamSubscription<dynamic> _subscription;

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }
}
