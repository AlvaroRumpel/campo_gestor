// REPR-02 — IatfAnimalSelectionScreen widget tests (05-UI-SPEC.md E3,
// ROADMAP SC-2). Covers both halves of SC-2: only vacas/novilhas are ever
// offered (D-09), and an animal already in another active IATF stays visible
// with its reason rather than being silently filtered out (D-07).
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/presentation/iatf_animal_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeIatfRepo extends IatfRepository {
  _FakeIatfRepo({this.shouldThrow = false}) : super(SupabaseService());

  final bool shouldThrow;
  String? capturedIatfBatchId;
  List<String>? capturedAnimalIds;

  @override
  Future<void> addAnimalsToIatf({
    required String iatfBatchId,
    required List<String> animalIds,
  }) async {
    if (shouldThrow) throw Exception('boom');
    capturedIatfBatchId = iatfBatchId;
    capturedAnimalIds = animalIds;
  }
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

Animal _animal({
  required String id,
  required String lotId,
  required String category,
  required int number,
}) =>
    Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: lotId,
      category: category,
      number: number,
      createdAt: DateTime(2025, 1, 1),
    );

Lot _lot(String id, String name) => Lot(
      id: id,
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      name: name,
      createdAt: DateTime(2025, 1, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required List<EligibleAnimal> eligible,
  required List<Lot> lots,
  IatfRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      iatfRepositoryProvider.overrideWithValue(repo ?? _FakeIatfRepo()),
      eligibleAnimalsForIatfProvider.overrideWith((ref, id) async => eligible),
      loteListByPropertyProvider.overrideWith((ref) async => lots),
      iatfActiveMembershipsProvider.overrideWith((ref, id) async => const []),
      iatfMembershipsProvider.overrideWith((ref, id) async => const []),
      iatfListByPropertyProvider.overrideWith((ref) async => const []),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: IatfAnimalSelectionScreen(
        iatfId: 'iatf-1',
        iatfName: 'IATF Primavera',
      ),
    ),
  );
}

/// Opens the "LOTE BASE" glass tile's bottom-sheet picker and taps [lotName].
/// The tile shows 'Selecionar lote' until a lot is picked, so the first tap
/// is unambiguous in every test (each test selects at most once).
Future<void> _selectLot(WidgetTester tester, String lotName) async {
  await tester.tap(find.text('Selecionar lote'));
  await tester.pumpAndSettle();
  await tester.tap(find.text(lotName).last);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('IatfAnimalSelectionScreen (REPR-02, 05-UI-SPEC E3)', () {
    testWidgets('choosing a base lot pre-checks every eligible animal of it',
        (tester) async {
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 1)),
        EligibleAnimal(animal: _animal(id: 'a2', lotId: 'lot-a', category: 'novilha', number: 2)),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')]),
      );
      await tester.pumpAndSettle();

      await _selectLot(tester, 'Lote A');

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles, hasLength(2));
      expect(tiles.every((t) => t.value == true), isTrue);
    });

    testWidgets(
        'a touro and a terneiro in the same lot are absent from the rendered list',
        (tester) async {
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 1)),
        EligibleAnimal(animal: _animal(id: 'a2', lotId: 'lot-a', category: 'touro', number: 2)),
        EligibleAnimal(animal: _animal(id: 'a3', lotId: 'lot-a', category: 'terneiro', number: 3)),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')]),
      );
      await tester.pumpAndSettle();

      await _selectLot(tester, 'Lote A');

      expect(find.textContaining('Touro'), findsNothing);
      expect(find.textContaining('Terneiro'), findsNothing);
      expect(find.byType(CheckboxListTile), findsOneWidget);
    });

    testWidgets(
        'a blocked animal renders a disabled row whose text contains the blocking IATF name',
        (tester) async {
      final eligible = [
        EligibleAnimal(
          animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 5),
          blockedByIatfName: 'IATF Outono',
        ),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')]),
      );
      await tester.pumpAndSettle();

      await _selectLot(tester, 'Lote A');

      final rowFinder = find.textContaining('já está no IATF Outono');
      expect(rowFinder, findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(
        find.ancestor(
          of: rowFinder,
          matching: find.byType(CheckboxListTile),
        ),
      );
      expect(tile.enabled, isFalse);
    });

    testWidgets('tapping a blocked row does not change the selection count',
        (tester) async {
      final eligible = [
        EligibleAnimal(
          animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 5),
          blockedByIatfName: 'IATF Outono',
        ),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')]),
      );
      await tester.pumpAndSettle();

      await _selectLot(tester, 'Lote A');
      expect(find.text('Selecione ao menos 1 animal'), findsOneWidget);

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('Selecione ao menos 1 animal'), findsOneWidget);
    });

    testWidgets(
        'confirm button is disabled at zero selections, enabled once one is checked',
        (tester) async {
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 1)),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')]),
      );
      await tester.pumpAndSettle();
      await _selectLot(tester, 'Lote A');

      // Pre-checked by choosing the lot (D-06) — button should already be enabled.
      var btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Adicionar ao IATF'),
      );
      expect(btn.onPressed, isNotNull);

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Adicionar ao IATF'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('confirming calls addAnimalsToIatf exactly once with the checked ids',
        (tester) async {
      final repo = _FakeIatfRepo();
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 1)),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')], repo: repo),
      );
      await tester.pumpAndSettle();
      await _selectLot(tester, 'Lote A');

      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar ao IATF'));
      await tester.pumpAndSettle();

      expect(repo.capturedIatfBatchId, 'iatf-1');
      expect(repo.capturedAnimalIds, ['a1']);
      expect(find.byType(IatfAnimalSelectionScreen), findsNothing);
    });

    testWidgets('a repository throw keeps the screen mounted and the selection staged',
        (tester) async {
      final repo = _FakeIatfRepo(shouldThrow: true);
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-a', category: 'vaca', number: 1)),
      ];
      await tester.pumpWidget(
        _buildScreen(eligible: eligible, lots: [_lot('lot-a', 'Lote A')], repo: repo),
      );
      await tester.pumpAndSettle();
      await _selectLot(tester, 'Lote A');

      await tester.tap(find.widgetWithText(FilledButton, 'Adicionar ao IATF'));
      await tester.pumpAndSettle();

      expect(find.byType(IatfAnimalSelectionScreen), findsOneWidget);
      expect(find.text('Erro ao adicionar animais. Tente novamente.'), findsOneWidget);
      final tile = tester.widget<CheckboxListTile>(find.byType(CheckboxListTile).first);
      expect(tile.value, isTrue);
    });

    testWidgets(
        'empty-lot case renders the inline message while the avulsos search stays usable',
        (tester) async {
      final eligible = [
        EligibleAnimal(animal: _animal(id: 'a1', lotId: 'lot-b', category: 'vaca', number: 1)),
      ];
      await tester.pumpWidget(
        _buildScreen(
          eligible: eligible,
          lots: [_lot('lot-a', 'Lote Vazio'), _lot('lot-b', 'Lote B')],
        ),
      );
      await tester.pumpAndSettle();

      await _selectLot(tester, 'Lote Vazio');

      expect(find.text('Nenhuma vaca ou novilha neste lote.'), findsOneWidget);
      expect(find.byType(SearchBar), findsOneWidget);
    });
  });
}
