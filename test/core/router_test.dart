// TODO(plan-04): unskip when lib/core/router/router.dart lands
//
// Validates SC-4: GoRouter has 5 top-level routes (dashboard, piquetes,
// animais, reproducao, sanitario) and uses path-based URL strategy
// (no `#` in the URL on web).

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'GoRouter has 5 top-level routes (dashboard, piquetes, animais, reproducao, sanitario)',
    () {
      // Will exercise routerProvider once Plan 04 creates lib/core/router/router.dart.
      // Expected: routerProvider exposes a GoRouter with exactly 5 top-level
      // routes whose paths are /dashboard, /piquetes, /animais, /reproducao,
      // /sanitario (StatefulShellRoute branches).
    },
    skip: 'Wave 0 placeholder — unskip when production file lands',
  );

  test(
    'URL strategy is path-based (no # in URL)',
    () {
      // Will assert usePathUrlStrategy() effect once main.dart wires it.
      // Expected: on web, routes appear as /dashboard not /#/dashboard.
    },
    skip: 'Wave 0 placeholder — unskip when production file lands',
  );
}
