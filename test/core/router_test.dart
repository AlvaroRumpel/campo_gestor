import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/router.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/membros/presentation/membros_screen.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/propriedades/presentation/propriedades_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppRoutes contains 6 top-level paths', () {
    expect(AppRoutes.all.length, 6);
    expect(AppRoutes.all, contains('/dashboard'));
    expect(AppRoutes.all, contains('/piquetes'));
    expect(AppRoutes.all, contains('/animais'));
    expect(AppRoutes.all, contains('/reproducao'));
    expect(AppRoutes.all, contains('/sanitario'));
    expect(AppRoutes.all, contains('/gastos'));
  });

  group('AppRoutes.membrosById / membros (Phase 10, MEMB-02 root-level route)', () {
    test('membrosById template and membros(id) helper', () {
      expect(AppRoutes.membrosById, '/propriedades/:propertyId/membros');
      expect(AppRoutes.membros('abc-123'), '/propriedades/abc-123/membros');
    });

    test('membrosById does not leak into AppRoutes.all', () {
      expect(AppRoutes.all, isNot(contains(AppRoutes.membrosById)));
      expect(AppRoutes.all.length, 6);
    });

    // Two-segment root-level route must coexist with /propriedades without
    // swallowing it — mirrors the gastosById/gastos coexistence test above.
    GoRouter buildRouter(String location) => GoRouter(
          initialLocation: location,
          routes: [
            GoRoute(
              path: AppRoutes.propriedades,
              builder: (ctx, _) => const PropriedadesScreen(),
            ),
            GoRoute(
              path: AppRoutes.membrosById,
              builder: (ctx, state) => MembrosScreen(
                propertyId: state.pathParameters['propertyId']!,
              ),
            ),
          ],
        );

    Widget buildApp(GoRouter router) => ProviderScope(
          overrides: [
            propertyListProvider.overrideWith((ref) async => []),
            archivedPropertyListProvider.overrideWith((ref) async => []),
            memberPropertiesProvider.overrideWith((ref) async => []),
          ],
          child: MaterialApp.router(routerConfig: router),
        );

    testWidgets(
        '/propriedades/abc-123/membros renders MembrosScreen with propertyId from the path',
        (tester) async {
      await tester.pumpWidget(buildApp(buildRouter('/propriedades/abc-123/membros')));
      await tester.pump();

      final screen = tester.widget<MembrosScreen>(find.byType(MembrosScreen));
      expect(screen.propertyId, 'abc-123');
    });

    testWidgets('/propriedades still renders PropriedadesScreen (not swallowed by the detail route)',
        (tester) async {
      await tester.pumpWidget(buildApp(buildRouter('/propriedades')));
      await tester.pump();

      expect(find.byType(PropriedadesScreen), findsOneWidget);
      expect(find.byType(MembrosScreen), findsNothing);
    });
  });

  test('AppRoutes.iatfById / iatfDetail (Phase 5, D-02 root-level route)', () {
    expect(AppRoutes.iatfById, '/iatf/:iatfId');
    expect(AppRoutes.iatfDetail('abc'), '/iatf/abc');
    // The new detail route must NOT leak into the shell-branch-only list.
    expect(AppRoutes.all.length, 6);
  });

  test(
      'AppRoutes.gastosById (/gastos/:paddockId) coexists with the '
      '6a shell branch AppRoutes.gastos (/gastos)', () {
    expect(AppRoutes.gastosById, '/gastos/:paddockId');
    expect(AppRoutes.gastos, '/gastos');
  });

  // Note: full router instantiation requires a live Supabase.instance, which
  // requires Supabase.initialize(). That is exercised in the integration smoke
  // test where main() runs end-to-end. _RouterRefreshNotifier is private and
  // tested indirectly via the integration smoke test.

  group('safeReturnTo (T-g9j-08: open-redirect guard)', () {
    test('accepts an internal path', () {
      expect(safeReturnTo('/piquetes'), '/piquetes');
    });

    test('falls back to /dashboard when from is null', () {
      expect(safeReturnTo(null), AppRoutes.dashboard);
    });

    test('falls back to /dashboard for an auth route', () {
      expect(safeReturnTo('/login'), AppRoutes.dashboard);
    });

    test('falls back to /dashboard for /sem-acesso', () {
      expect(safeReturnTo('/sem-acesso'), AppRoutes.dashboard);
    });

    test('falls back to /dashboard for an absolute external URL', () {
      expect(safeReturnTo('https://evil.tld'), AppRoutes.dashboard);
    });

    test('falls back to /dashboard for a protocol-relative URL', () {
      expect(safeReturnTo('//evil.tld'), AppRoutes.dashboard);
    });
  });
}
