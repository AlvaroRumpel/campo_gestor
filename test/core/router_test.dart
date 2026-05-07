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

  // Note: full router instantiation requires a live Supabase.instance, which
  // requires Supabase.initialize(). That is exercised in the integration smoke
  // test where main() runs end-to-end. _RouterRefreshNotifier is private and
  // tested indirectly via the integration smoke test.
}
