// SANI-02/03 — sanitary application totals: UA composition, volume/cost
// aggregation, display formatting for ResumoAplicacaoDialog. See
// 06-UI-SPEC.md § Screen Inventory items 2 and 5 for the exact rendering
// rules `formatVolumeMl`/`formatUa` serve.
import 'package:campo_gestor/features/sanitario/data/sanitary_calculations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitary application totals (SANI-02/03)', () {
    test('totalUaForCategories sums each category through kUaWeights', () {
      expect(totalUaForCategories(['vaca', 'vaca', 'terneiro']), 2.5);
    });

    test(
        'totalUaForCategories defaults an unrecognised category to 0.0 '
        'instead of throwing', () {
      expect(totalUaForCategories(['categoria-inexistente']), 0.0);
    });

    test('totalUaForCategories of an empty iterable returns 0.0', () {
      expect(totalUaForCategories(const []), 0.0);
    });

    test('totalVolumeMl(42.5, 1.0, 400) returns 17000.0', () {
      expect(totalVolumeMl(42.5, 1.0, 400), 17000.0);
    });

    test('totalCost(42.5, 8.5, 400) returns 144500.0', () {
      expect(totalCost(42.5, 8.5, 400), 144500.0);
    });

    test(
        'totalCost(42.5, null, 400) returns null — a dose without a known '
        'price never yields a number (D-11)', () {
      expect(totalCost(42.5, null, 400), isNull);
    });

    test('formatUa always emits one decimal place with a comma separator',
        () {
      expect(formatUa(42.5), '42,5');
      expect(formatUa(0), '0,0');
      expect(formatUa(1), '1,0');
    });

    test('formatVolumeMl stays in the mL branch below 1000', () {
      expect(formatVolumeMl(800), '800 mL');
      expect(formatVolumeMl(999), '999 mL');
    });

    test('formatVolumeMl switches to the L branch at exactly 1000', () {
      expect(formatVolumeMl(1000), '1,0 L');
      expect(formatVolumeMl(1200), '1,2 L');
      expect(formatVolumeMl(17000), '17,0 L');
    });
  });

  // 06-04 appends a "reversal visibility and ordering (SANI-04)" group here
  // once the SanitaryApplication model exists. Not stubbed now — an empty
  // group would report as passing coverage that does not exist (D-40).
}
