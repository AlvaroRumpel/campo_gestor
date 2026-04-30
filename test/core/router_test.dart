import 'dart:async';

import 'package:campo_gestor/core/router/router.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('AppRoutes contains 5 top-level paths', () {
    expect(AppRoutes.all.length, 5);
    expect(AppRoutes.all, contains('/dashboard'));
    expect(AppRoutes.all, contains('/piquetes'));
    expect(AppRoutes.all, contains('/animais'));
    expect(AppRoutes.all, contains('/reproducao'));
    expect(AppRoutes.all, contains('/sanitario'));
  });

  test('GoRouterRefreshStream swallows stream errors (Pitfall 2)', () async {
    final controller = StreamController<dynamic>();
    final listenable = GoRouterRefreshStream(controller.stream);
    addTearDown(listenable.dispose);
    addTearDown(controller.close);

    // Should NOT throw — onError handler swallows the error.
    controller.addError(Exception('simulated network failure'));
    await Future<void>.delayed(const Duration(milliseconds: 10));

    expect(true, isTrue); // arrived without crash
  });

  // Note: full router instantiation requires a live Supabase.instance, which
  // requires Supabase.initialize(). That is exercised in the integration smoke
  // test (Plan 05/06) where main() runs end-to-end. We test routerProvider's
  // wiring there.
}
