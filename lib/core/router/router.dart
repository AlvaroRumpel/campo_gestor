import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../features/animais/presentation/animal_detail_screen.dart';
import '../../features/animais/presentation/animais_screen.dart';
import '../../features/auth/data/property_repository.dart';
import '../../features/propriedades/presentation/propriedades_screen.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/no_access_screen.dart';
import '../../features/auth/presentation/reset_password_screen.dart';
import '../../features/auth/presentation/signup_screen.dart';
import '../../features/auth/providers/auth_provider.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/gastos/presentation/gastos_screen.dart';
import '../../features/piquetes/presentation/paddock_detail_screen.dart';
import '../../features/lotes/presentation/lote_detail_screen.dart';
import '../../features/piquetes/presentation/piquetes_screen.dart';
import '../../features/reproducao/presentation/atf_detail_screen.dart';
import '../../features/reproducao/presentation/reproducao_screen.dart';
import '../../features/sanitario/presentation/aplicacao_detail_screen.dart';
import '../../features/sanitario/presentation/sanitario_screen.dart';
import '../providers/current_property_provider.dart';
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
    refreshListenable: _RouterRefreshNotifier(authStream, ref),
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

      // Pitfall 2: passwordRecovery wins over signedIn.
      if (isPasswordRecovery && loc != AppRoutes.resetPassword) {
        return AppRoutes.resetPassword;
      }

      // Not logged in: only auth routes are reachable.
      if (!isLoggedIn) {
        return onAuthRoute ? null : AppRoutes.login;
      }

      // Logged in. Check membership.
      final members = ref.read(memberPropertiesProvider);
      if (members.isLoading) return null;
      final membersList = members.asData?.value;

      // Empty memberships (D-03): route to /sem-acesso.
      // Exception: /propriedades is reachable — vet can create their first property there.
      if (membersList != null && membersList.isEmpty) {
        if (loc == AppRoutes.noAccess || loc == AppRoutes.propriedades) {
          return null;
        }
        return AppRoutes.noAccess;
      }

      // Has memberships on /login or /signup: bounce to dashboard.
      if (loc == AppRoutes.login || loc == AppRoutes.signup) {
        return AppRoutes.dashboard;
      }

      // Has memberships but sitting on /sem-acesso (post re-membership): bounce.
      if (loc == AppRoutes.noAccess &&
          membersList != null &&
          membersList.isNotEmpty) {
        return AppRoutes.dashboard;
      }

      // Pitfall 3: currentPropertyProvider is async — hold until it resolves so
      // shell screens never receive a null active property on cold start.
      // All screens inside the shell MUST still handle the loading/null case
      // via .when() or .isLoading checks; this guard only covers the redirect.
      final currentProp = ref.read(currentPropertyProvider);
      if (currentProp.isLoading) return null;

      return null;
    },
    routes: [
      // Auth routes (root-level, outside the AppShell)
      GoRoute(path: AppRoutes.login, builder: (ctx, _) => const LoginScreen()),
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
      // Management routes (Phase 2) — outside the AppShell
      GoRoute(
        path: AppRoutes.propriedades,
        builder: (ctx, _) => const PropriedadesScreen(),
      ),
      // Phase 3 detail routes — root-level, outside any shell branch (D-03)
      GoRoute(
        path: AppRoutes.loteById,
        builder: (ctx, state) =>
            LoteDetailScreen(loteId: state.pathParameters['loteId']!),
      ),
      // Phase 5 detail route — root-level, outside any shell branch (D-02):
      // reproductive-history rows on the animal ficha (D-14) link directly
      // to an ATF, mirroring loteById above.
      GoRoute(
        path: AppRoutes.atfById,
        builder: (ctx, state) =>
            AtfDetailScreen(atfId: state.pathParameters['atfId']!),
      ),
      // Phase 6 detail route — root-level, outside any shell branch (D-19):
      // reachable from three list origins (global aplicações list, lote
      // history section, animal ficha), mirroring loteById/atfById above.
      GoRoute(
        path: AppRoutes.aplicacaoById,
        builder: (ctx, state) =>
            AplicacaoDetailScreen(applicationId: state.pathParameters['id']!),
      ),
      // Phase 7 detail route — root-level, outside any shell branch (D-08):
      // the expense list for one paddock, reached from
      // PaddockDetailScreen's summary card and by deep link, mirroring
      // loteById/atfById/aplicacaoById above.
      GoRoute(
        path: AppRoutes.gastosById,
        builder: (ctx, state) =>
            GastosScreen(paddockId: state.pathParameters['paddockId']!),
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
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (ctx, state) => PaddockDetailScreen(
                      paddockId: state.pathParameters['id']!,
                    ),
                  ),
                ],
              ),
            ],
          ),
          StatefulShellBranch(
            navigatorKey: _shellAnimaisKey,
            routes: [
              GoRoute(
                path: AppRoutes.animais,
                builder: (ctx, _) => const AnimaisScreen(),
                routes: [
                  GoRoute(
                    path: AppRoutes.animalById, // ':id'
                    builder: (ctx, state) => AnimalDetailScreen(
                      animalId: state.pathParameters['id']!,
                    ),
                  ),
                ],
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

/// Combines auth stream + [memberPropertiesProvider] into one [Listenable].
///
/// GoRouter only re-evaluates redirect when its refreshListenable fires.
/// Wiring only the auth stream misses the case where the user is already
/// logged in but memberPropertiesProvider transitions loading→data after
/// the auth event — without this the router would stay stuck on /login.
class _RouterRefreshNotifier extends ChangeNotifier {
  _RouterRefreshNotifier(Stream<dynamic> authStream, Ref ref) {
    notifyListeners();
    _authSub = authStream.asBroadcastStream().listen(
      (_) => notifyListeners(),
      onError: (_) {},
    );
    ref.listen<AsyncValue<List<PropertyMembership>>>(
      memberPropertiesProvider,
      (_, _) => notifyListeners(),
    );
  }

  late final StreamSubscription<dynamic> _authSub;

  @override
  void dispose() {
    _authSub.cancel();
    super.dispose();
  }
}
