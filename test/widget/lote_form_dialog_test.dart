// PROP-04 — LoteFormDialog: batch composition validation.
// Wave 0 stubs. Implementation lands in Plan 04 (LoteFormDialog).
// Decisions enforced: D-10 (7 categorias), D-11 (nome required + total>0), D-12 (paddock readonly).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoteFormDialog (PROP-04)', () {
    testWidgets('renders 7 category counter rows: Vacas, Novilhas, Terneiros, Terneiras, Touros, Bois, Novilhos',
        // skip: pending Plan 04 implementation
        (tester) async {}, skip: true);
    testWidgets('rejects submit when name is empty (shows "Nome do lote é obrigatório")',
        // skip: pending Plan 04 implementation
        (tester) async {}, skip: true);
    testWidgets('rejects submit when sum of all category quantities == 0 (shows "Informe ao menos 1 animal para criar o lote")',
        // skip: pending Plan 04 implementation
        (tester) async {}, skip: true);
    testWidgets('shows optional "Iniciar do número" field with hint "Ex: 101 (deixe vazio para auto)"',
        // skip: pending Plan 04 implementation
        (tester) async {}, skip: true);
    testWidgets('shows raça dropdown per category row (search-select, optional)',
        // skip: pending Plan 04 implementation
        (tester) async {}, skip: true);
  });
}
