import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/animais/presentation/animais_screen.dart';
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
/// keepAlive: router persists for the app's lifetime; reconstruction would
/// reset navigation history. Auth state changes refresh the router via
/// [GoRouterRefreshStream] which wraps Supabase's `onAuthStateChange` with the
/// mandatory `onError` handler (Pitfall 2 — token refresh on bad network).
final routerProvider = Provider<GoRouter>((ref) {
  final authStream = Supabase.instance.client.auth.onAuthStateChange;

  final router = GoRouter(
    navigatorKey: _rootKey,
    initialLocation: AppRoutes.dashboard,
    debugLogDiagnostics: false,
    refreshListenable: GoRouterRefreshStream(authStream),
    redirect: (context, state) {
      // Phase 0: permissive — always allow. Phase 1 enforces auth.
      return null;
    },
    routes: [
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
            // failures. Real error handling lives at the auth layer in Phase 1.
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
