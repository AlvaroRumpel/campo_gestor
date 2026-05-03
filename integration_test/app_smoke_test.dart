import 'package:campo_gestor/main.dart' as app;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('App boots and renders the default route without crashing',
      (tester) async {
    // Run the real main(): this initializes Supabase using the dart-define
    // values passed at the command line. The test command MUST include:
    //   --dart-define=SUPABASE_URL=http://127.0.0.1:54321
    //   --dart-define=SUPABASE_ANON_KEY=<local anon key>
    // Local Supabase must be running (`supabase start`).
    await app.main();
    await tester.pumpAndSettle(const Duration(seconds: 3));

    // Either NavigationRail or NavigationBar must render (depending on
    // viewport — integration test usually defaults to the device size).
    final hasRail = find.byType(NavigationRail).evaluate().isNotEmpty;
    final hasBar = find.byType(NavigationBar).evaluate().isNotEmpty;
    expect(hasRail || hasBar, isTrue,
        reason: 'AppShell did not render either navigation widget');

    // The default route is /dashboard, which renders the placeholder text.
    expect(find.text('Dashboard'), findsAtLeastNWidgets(1));
  });
}
