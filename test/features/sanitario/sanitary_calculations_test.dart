// SANI-02/03 — sanitary application totals: UA composition, volume/cost
// aggregation, display formatting for ResumoAplicacaoDialog. See
// 06-UI-SPEC.md § Screen Inventory items 2 and 5 for the exact rendering
// rules `formatVolumeMl`/`formatUa` serve.
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_calculations.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal [SanitaryApplication] fixture — every field has a constant
/// default except the few named params a given test case cares about, so
/// each case below reads as one line.
SanitaryApplication _fixture({
  String id = 'app-1',
  DateTime? appliedAt,
  DateTime? createdAt,
  String? reversesApplicationId,
}) {
  return SanitaryApplication(
    id: id,
    propertyId: 'prop-1',
    lotId: 'lot-1',
    lotName: 'Lote 1',
    doseId: 'dose-1',
    doseName: 'Dose 1',
    dosagePerKg: 1.0,
    dosagePerUa: 400.0,
    appliedAt: appliedAt ?? DateTime(2026, 1, 1),
    appliedBy: 'user-1',
    animalCount: 1,
    totalUa: 1.0,
    totalVolume: 400.0,
    skippedCount: 0,
    reversesApplicationId: reversesApplicationId,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

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

  group('reversal visibility and ordering (SANI-04)', () {
    test(
        'visibleApplications(showReversed: false) hides both a reversed '
        'original and its reversal row', () {
      final normal = _fixture(id: 'a');
      final original = _fixture(id: 'b');
      final reversal = _fixture(id: 'c', reversesApplicationId: 'b');
      final rows = [normal, original, reversal];

      final visible = visibleApplications(rows, showReversed: false);

      expect(visible.map((r) => r.id).toList(), ['a']);
    });

    test(
        'visibleApplications(showReversed: true) returns every row, '
        'including the reversed original and its reversal', () {
      final normal = _fixture(id: 'a');
      final original = _fixture(id: 'b');
      final reversal = _fixture(id: 'c', reversesApplicationId: 'b');
      final rows = [normal, original, reversal];

      final all = visibleApplications(rows, showReversed: true);

      expect(all.length, 3);
    });

    test(
        'a list of only normal applications is unchanged by either flag '
        'setting', () {
      final rows = [_fixture(id: 'a'), _fixture(id: 'b')];

      expect(visibleApplications(rows, showReversed: false).length, 2);
      expect(visibleApplications(rows, showReversed: true).length, 2);
    });

    test('sortByAppliedAtDesc puts the newest application date first', () {
      final older = _fixture(id: 'a', appliedAt: DateTime(2026, 1, 1));
      final newer = _fixture(id: 'b', appliedAt: DateTime(2026, 2, 1));

      final sorted = sortByAppliedAtDesc([older, newer]);

      expect(sorted.map((r) => r.id).toList(), ['b', 'a']);
    });

    test(
        'two rows sharing an application date fall back to creation time '
        'descending', () {
      final earlyCreated = _fixture(
        id: 'a',
        appliedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1, 8),
      );
      final lateCreated = _fixture(
        id: 'b',
        appliedAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1, 10),
      );

      final sorted = sortByAppliedAtDesc([earlyCreated, lateCreated]);

      expect(sorted.map((r) => r.id).toList(), ['b', 'a']);
    });

    test('sorting an empty list returns an empty list', () {
      expect(sortByAppliedAtDesc(const []), isEmpty);
    });
  });
}
