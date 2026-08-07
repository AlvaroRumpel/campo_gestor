// SANI-01 — dose registration math: mL/kg → mL/UA, R$/kg → R$/UA, currency
// formatting. See 06-RESEARCH.md § Code Examples §3 for the server-side
// formulas these Dart helpers mirror, and 06-UI-SPEC.md for the exact
// rendering rules DoseFormDialog's live preview field depends on.
import 'package:campo_gestor/features/sanitario/data/sanitary_calculations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('dose calculations (SANI-01)', () {
    test('dosagePerUa(1.0, 400) returns 400.0 — the D-12 default kgPerUa',
        () {
      expect(dosagePerUa(1.0, 400), 400.0);
    });

    test('dosagePerUa(0.5, 450) returns 225.0', () {
      expect(dosagePerUa(0.5, 450), 225.0);
    });

    test('costPerUa(8.5, 400) returns 3400.0', () {
      expect(costPerUa(8.5, 400), 3400.0);
    });

    test(
        'costPerUa(null, 400) returns null — a missing cost is never '
        'converted into a knowable price (D-11)', () {
      expect(costPerUa(null, 400), isNull);
    });

    test(
        'formatCurrencyBrl(3400) starts with the BRL symbol and contains '
        'the grouped/decimal digits', () {
      final result = formatCurrencyBrl(3400);
      expect(result, startsWith('R\$'));
      expect(result, contains('3.400,00'));
    });

    test('formatCurrencyBrl(8.5) contains the cents-formatted digits', () {
      expect(formatCurrencyBrl(8.5), contains('8,50'));
    });
  });
}
