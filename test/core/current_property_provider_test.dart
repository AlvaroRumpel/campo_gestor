// TODO(plan-04): unskip when lib/core/providers/current_property_provider.dart lands
//
// Validates SC-3: currentPropertyProvider (Riverpod AsyncNotifier) returns
// null in its initial state. Phase 1 will wire the provider to actual
// Supabase data; Phase 0 only validates the placeholder shape.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'currentPropertyProvider returns null in initial state',
    () {
      // Will read currentPropertyProvider via a ProviderContainer once Plan 04
      // creates lib/core/providers/current_property_provider.dart.
      // Expected: AsyncValue<Property?> with data == null on first read.
    },
    skip: 'Wave 0 placeholder — unskip when production file lands',
  );
}
