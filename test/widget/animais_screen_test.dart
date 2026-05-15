// ANIM-05, ANIM-06 — AnimaisScreen: search by number + filter by category/lot/paddock.
// Wave 0 stubs. Implementation lands in Plan 06 (AnimaisScreen).
// Decisions enforced: D-18 (filters), D-19 (tile format), D-20 (debounce 300ms), D-21 (toggle archived).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AnimaisScreen — Search (ANIM-05)', () {
    testWidgets('SearchBar with hint "Buscar por número..." filters list in-memory after 300ms debounce',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('typing "4" matches animals whose number contains "4" (e.g. #4, #14, #42)',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('clear button (X) appears when search field is non-empty',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
  });
  group('AnimaisScreen — Filters (ANIM-06)', () {
    testWidgets('renders FilterChips: Todas | Vaca | Novilha | Terneiro | Terneira | Touro | Boi | Novilho',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('selecting "Vaca" chip filters list to category == "vaca"',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('Lote dropdown with "Todos os lotes" default filters by lot_id when set',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('Piquete dropdown with "Todos os piquetes" default filters by paddock_id when set',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('SummaryBar shows "X animais · Y,Y UA total" updating with filters',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('"Mostrar arquivados" toggle reveals archived animals with reason badge',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
    testWidgets('list tile primary line format: "#42 · Vaca"; secondary line: "<Lote> · <Piquete>"',
        // skip: pending Plan 06 implementation
        (tester) async {}, skip: true);
  });
}
