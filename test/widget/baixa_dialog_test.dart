// ANIM-04 — BaixaDialog: motivo (Venda/Morte/Descarte) + data.
// Wave 0 stubs. Implementation lands in Plan 06 (BaixaDialog).
// Decisions enforced: D-17 (3 reasons mapped to enum 'sale'|'death'|'discard').
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BaixaDialog (ANIM-04)', () {
    testWidgets('renders title "Confirmar baixa do animal #<N>?"',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('renders 3 motivo options labeled "Venda", "Morte", "Descarte"',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('renders Data da baixa field with date picker, defaulting to today (DD/MM/AAAA)',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('confirm button labeled "Confirmar baixa", uses colorScheme.error background',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('rejects submit when motivo not selected',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
  });
}
