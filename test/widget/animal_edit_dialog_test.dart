// ANIM-02 — AnimalEditDialog: editable raça / EC 1-5 / observação.
// Wave 0 stubs. Implementation lands in Plan 06 (AnimalEditDialog).
// Decisions enforced: D-14 (raça hardcoded list), D-16 (EC 5 chips).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimalEditDialog (ANIM-02)', () {
    testWidgets('shows Número and Categoria as read-only display fields',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('shows Raça dropdown with hardcoded breed list (Nelore, Angus, Brahman, Gir, ...)',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('shows 5 EC ChoiceChip widgets labeled 1..5 in a Row',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('shows Observação multi-line TextFormField (maxLines: 3)',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('Cancel button labeled "Cancelar"; submit button labeled "Salvar"',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
  });
}
