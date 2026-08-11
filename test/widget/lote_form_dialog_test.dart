// PROP-04 — LoteFormDialog: batch composition validation.
// Wave 0 stubs turned GREEN in Plan 04.
// Decisions enforced: D-10 (7 categorias), D-11 (nome required + total>0), D-12 (paddock readonly).
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/lotes/presentation/lote_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake in-memory LoteRepository — no mocktail chain needed.
// ---------------------------------------------------------------------------
class _FakeLoteRepository implements LoteRepository {
  Map<String, int>? lastCategoryQuantities;

  @override
  Future<List<Lot>> fetchLotsByPaddock(String paddockId) async => [];

  @override
  Future<Lot?> fetchLot(String id) async => null;

  @override
  Future<Lot> createLotWithAnimals({
    required String propertyId,
    required String paddockId,
    required String name,
    required Map<String, int> categoryQuantities,
    required Map<String, String?> categoryBreeds,
    int? startNumber,
  }) async {
    lastCategoryQuantities = categoryQuantities;
    return Lot(
      id: 'fake-lot-id',
      propertyId: propertyId,
      paddockId: paddockId,
      name: name,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<Lot> updateLotName({required String id, required String name}) async {
    return Lot(
      id: id,
      propertyId: 'p',
      paddockId: 'pad',
      name: name,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<void> softDeleteLot(String id) async {}

  @override
  Future<List<LotWithPaddockCount>> fetchLotsWithCountByProperty(
    String propertyId,
  ) async =>
      [];

  @override
  Future<void> moveLot({
    required String lotId,
    required String newPaddockId,
  }) async {}

  @override
  Future<LotWithPaddockName?> fetchLotWithPaddockName(String id) async =>
      null;
}

// ---------------------------------------------------------------------------
// Helper: mount LoteFormDialog via a button that opens it via showDialog
// ---------------------------------------------------------------------------
Widget _buildApp({Lot? existing, required _FakeLoteRepository repo}) {
  return ProviderScope(
    overrides: [
      loteRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog<bool>(
              context: ctx,
              builder: (_) => LoteFormDialog(
                paddockId: 'p1',
                propertyId: 'P1',
                existing: existing,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group('LoteFormDialog (PROP-04)', () {
    testWidgets(
        'renders 7 category counter rows: Vacas, Novilhas, Terneiros, Terneiras, Touros, Bois, Novilhos',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Vacas'), findsOneWidget);
      expect(find.text('Novilhas'), findsOneWidget);
      expect(find.text('Terneiros'), findsOneWidget);
      expect(find.text('Terneiras'), findsOneWidget);
      expect(find.text('Touros'), findsOneWidget);
      expect(find.text('Bois'), findsOneWidget);
      expect(find.text('Novilhos'), findsOneWidget);
    });

    testWidgets(
        'rejects submit when name is empty (shows "Nome do lote é obrigatório")',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar lote'));
      await tester.pumpAndSettle();

      expect(find.text('Nome do lote é obrigatório'), findsOneWidget);
    });

    testWidgets(
        'rejects submit when sum of all category quantities == 0 (shows "Informe ao menos 1 animal para criar o lote")',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do lote *'),
        'Lote A',
      );
      await tester.tap(find.text('Criar lote'));
      await tester.pumpAndSettle();

      expect(
        find.text('Informe ao menos 1 animal para criar o lote'),
        findsOneWidget,
      );
    });

    testWidgets(
        'shows optional "Iniciar do número" field with hint "Ex: 101 (deixe vazio para auto)"',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ex: 101 (deixe vazio para auto)'),
        findsOneWidget,
      );
    });

    testWidgets('shows raça dropdown per category row (search-select, optional)',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // One DropdownButtonFormField<String?> per category row = 7 minimum
      expect(
        find.byType(DropdownButtonFormField<String?>),
        findsAtLeastNWidgets(7),
      );
    });

    testWidgets(
        'typing a two-digit quantity into a category field passes that exact count to createLotWithAnimals (F-04-03)',
        (tester) async {
      final repo = _FakeLoteRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do lote *'),
        'Lote A',
      );
      await tester.enterText(find.byKey(const ValueKey('qty_field_vaca')), '20');
      await tester.tap(find.text('Criar lote'));
      await tester.pumpAndSettle();

      expect(repo.lastCategoryQuantities?['vaca'], 20);
    });

    testWidgets(
        'after typing a quantity, tapping increment shows the value plus one (F-04-03)',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(find.byKey(const ValueKey('qty_field_vaca')), '20');
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('qty_inc_vaca')));
      await tester.pump();

      final field =
          tester.widget<TextField>(find.byKey(const ValueKey('qty_field_vaca')));
      expect(field.controller!.text, '21');
    });

    testWidgets(
        'clearing the quantity field leaves the count at zero and shows the "at least 1 animal" SnackBar on submit (F-04-03)',
        (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeLoteRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do lote *'),
        'Lote A',
      );
      await tester.enterText(find.byKey(const ValueKey('qty_field_vaca')), '5');
      await tester.pump();
      await tester.enterText(find.byKey(const ValueKey('qty_field_vaca')), '');
      await tester.pump();
      await tester.tap(find.text('Criar lote'));
      await tester.pumpAndSettle();

      expect(
        find.text('Informe ao menos 1 animal para criar o lote'),
        findsOneWidget,
      );
    });
  });
}
