// TODO(plan-05): unskip when lib/core/widgets/app_shell.dart lands
//
// Validates SC-1 widget verification: AppShell renders NavigationRail at
// width 1024 (web/desktop) and NavigationBar at width 360 (mobile).
// Breakpoint is 600px per D-03 / Material 3 default.

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders NavigationRail at width 1024',
    (WidgetTester tester) async {
      // Will pump AppShell wrapped in a MaterialApp at width 1024 once Plan 05
      // creates lib/core/widgets/app_shell.dart.
      // Expected: find.byType(NavigationRail) finds exactly one widget;
      // find.byType(NavigationBar) finds zero widgets.
    },
    skip: true, // Wave 0 placeholder — unskip when production file lands (plan-05)
  );

  testWidgets(
    'renders NavigationBar at width 360',
    (WidgetTester tester) async {
      // Will pump AppShell wrapped in a MaterialApp at width 360.
      // Expected: find.byType(NavigationBar) finds exactly one widget;
      // find.byType(NavigationRail) finds zero widgets.
    },
    skip: true, // Wave 0 placeholder — unskip when production file lands (plan-05)
  );
}
