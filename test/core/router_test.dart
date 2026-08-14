import 'package:campo_gestor/core/router/router.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

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

  test('AppRoutes.atfById / atfDetail (Phase 5, D-02 root-level route)', () {
    expect(AppRoutes.atfById, '/atf/:atfId');
    expect(AppRoutes.atfDetail('abc'), '/atf/abc');
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
