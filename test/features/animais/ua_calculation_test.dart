// PROP-05 — UA total = sum(kUaWeights[a.category]) for all active animals.
// Wave 0 stubs. Implementations land in Plan 03 (calcTotalUa).
// Reference table from REQUIREMENTS.md Business Rules:
// vaca=1.0, novilha=0.75, terneiro=0.5, terneira=0.5, touro=1.5, boi=1.5, novilho=0.75
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('UA calculation (PROP-05)', () {
    test('calcTotalUa returns 0.0 for empty list',
        () {}, skip: 'pending Wave 1 implementation');
    test('calcTotalUa sums per-category weights — 10 vacas + 8 terneiros + 1 touro = 15.5',
        () {}, skip: 'pending Wave 1 implementation');
    test('calcTotalUa returns 0.0 contribution for unknown category',
        () {}, skip: 'pending Wave 1 implementation');
    test('kUaWeights contains all 7 categories with exact decimal values',
        () {}, skip: 'pending Wave 1 implementation');
  });
}
