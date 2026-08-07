// SANI-02/03 — AplicacaoFormDialog widget tests (06-UI-SPEC.md E4).
// Covers: locked vs. pickable lote branch, dose dropdown population, the
// E4 backstop (zero active doses renders a disabled dropdown with an
// explanatory hint rather than a silently-empty openable menu), and the
// valid-submission navigation to SanitaryAnimalSelectionScreen.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:campo_gestor/features/sanitario/data/dose_repository.dart';
import 'package:campo_gestor/features/sanitario/presentation/aplicacao_form_dialog.dart';
import 'package:campo_gestor/features/sanitario/presentation/sanitary_animal_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake in-memory LoteRepository — only fetchLotsWithCountByProperty is used
// by AplicacaoFormDialog's unlocked-lote branch.
// ---------------------------------------------------------------------------
class _FakeLoteRepository extends LoteRepository {
  _FakeLoteRepository(this._lots) : super(SupabaseService());
  final List<LotWithPaddockCount> _lots;

  @override
  Future<List<LotWithPaddockCount>> fetchLotsWithCountByProperty(
    String propertyId,
  ) async =>
      _lots;
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');

Dose _dose({
  String id = 'dose-1',
  String name = 'Ivomec Gold',
  String? activeIngredient,
}) =>
    Dose(
      id: id,
      propertyId: 'prop-1',
      name: name,
      activeIngredient: activeIngredient,
      dosagePerKg: 1.0,
      createdAt: DateTime(2026, 1, 1),
    );

Lot _lot(String id, String name) => Lot(
      id: id,
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      name: name,
      createdAt: DateTime(2026, 1, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildApp({
  String? lotId,
  Lot? lockedLot,
  List<Dose> doses = const [],
  List<LotWithPaddockCount> lotsWithCount = const [],
}) {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      doseListByPropertyProvider.overrideWith((ref) async => doses),
      loteRepositoryProvider.overrideWithValue(
        _FakeLoteRepository(lotsWithCount),
      ),
      // The last test navigates into SanitaryAnimalSelectionScreen, which
      // watches this provider — stubbed here so every test stays isolated
      // from any real Supabase client.
      animalListByLotProvider.overrideWith((ref, id) async => const []),
      if (lotId != null)
        loteByIdProvider.overrideWith((ref, id) async => lockedLot),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showDialog<void>(
              context: ctx,
              builder: (_) => AplicacaoFormDialog(lotId: lotId),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AplicacaoFormDialog (SANI-02/03, 06-UI-SPEC E4)', () {
    testWidgets(
        'locked lote (lotId supplied): renders the lot name as plain text, no dropdown for it',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          lotId: 'lot-a',
          lockedLot: _lot('lot-a', 'Lote A'),
          doses: [_dose()],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Lote A'), findsOneWidget);
      // Only the dose dropdown remains — the lote branch built plain text.
      expect(find.byType(DropdownButtonFormField<String>), findsOneWidget);
    });

    testWidgets(
        'unlocked lote (no lotId): dropdown lists only lots with at least one active animal',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          doses: [_dose()],
          lotsWithCount: [
            LotWithPaddockCount(
              lot: _lot('lot-a', 'Lote A'),
              paddockName: 'Piquete 1',
              activeAnimalCount: 3,
            ),
            LotWithPaddockCount(
              lot: _lot('lot-b', 'Lote Vazio'),
              paddockName: 'Piquete 1',
              activeAnimalCount: 0,
            ),
          ],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(DropdownButtonFormField<String>).first);
      await tester.pumpAndSettle();

      expect(find.text('Lote A'), findsWidgets);
      expect(find.text('Lote Vazio'), findsNothing);
    });

    testWidgets(
        'E4 backstop: zero active doses renders the dose dropdown disabled with the empty-list hint, never a silently-empty openable menu',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          lotId: 'lot-a',
          lockedLot: _lot('lot-a', 'Lote A'),
          doses: const [],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final doseDropdown = tester.widget<DropdownButtonFormField<String>>(
        find.byType(DropdownButtonFormField<String>),
      );
      expect(doseDropdown.onChanged, isNull);
      expect(
        find.text('Nenhuma dose cadastrada — cadastre uma dose primeiro'),
        findsOneWidget,
      );

      // Continuar must stay disabled — there is no valid dose to select.
      final continueBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(continueBtn.onPressed, isNull);
    });

    testWidgets(
        'valid selection: choosing a dose enables Continuar, which pushes SanitaryAnimalSelectionScreen',
        (tester) async {
      await tester.pumpWidget(
        _buildApp(
          lotId: 'lot-a',
          lockedLot: _lot('lot-a', 'Lote A'),
          doses: [_dose(name: 'Ivomec Gold')],
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      var continueBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(continueBtn.onPressed, isNull);

      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Ivomec Gold').last);
      await tester.pumpAndSettle();

      continueBtn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(continueBtn.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Continuar'));
      await tester.pumpAndSettle();

      expect(find.byType(AplicacaoFormDialog), findsNothing);
      expect(find.byType(SanitaryAnimalSelectionScreen), findsOneWidget);
    });
  });
}
