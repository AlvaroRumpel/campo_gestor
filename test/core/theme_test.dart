// TODO(plan-04): unskip when lib/core/theme/app_theme.dart lands
//
// Validates that AppTheme.light() returns a Material 3 ThemeData with the
// agrarian seedColor (#4A6741, verde-musgo) per D-12.

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'AppTheme.light() returns ThemeData with useMaterial3=true and seedColor=#4A6741',
    () {
      // Will exercise AppTheme.light() once Plan 04 creates
      // lib/core/theme/app_theme.dart.
      // Expected: theme.useMaterial3 == true and the colorScheme is generated
      // from a seed color of 0xFF4A6741 (agrarian verde-musgo per D-12).
    },
    skip: 'Wave 0 placeholder — unskip when production file lands',
  );
}
