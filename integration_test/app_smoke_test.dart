// TODO(plan-05): unskip when lib/main.dart is finalized
//
// Validates SC-1 end-to-end: the app boots in a real Flutter web target
// without crashing. Run with:
//   flutter test integration_test/app_smoke_test.dart -d edge \
//     --dart-define=SUPABASE_URL=http://localhost:54321 \
//     --dart-define=SUPABASE_ANON_KEY=<local-anon-key>

// import 'package:integration_test/integration_test.dart';
// (uncomment in Plan 03 once integration_test is added to dev_dependencies)

import 'package:flutter_test/flutter_test.dart';

void main() {
  // IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  // (uncomment in Plan 03 once integration_test is added to dev_dependencies)

  testWidgets(
    'App boots without crashing',
    (WidgetTester tester) async {
      // Will pump CampoGestorApp() once Plan 05 finalizes lib/main.dart.
      // Expected: tester.pumpWidget completes; tester.pumpAndSettle returns
      // without timeout; no exceptions thrown during the first frame.
    },
    skip: true, // Wave 0 placeholder — unskip when production file lands (plan-05)
  );
}
