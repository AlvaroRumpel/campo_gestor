// SANI-02/03 — RegistrarAplicacaoScreen widget tests (spec 4.10 single
// screen — replaces the old AplicacaoFormDialog + SanitaryAnimalSelectionScreen
// + ResumoAplicacaoDialog 3-step-flow tests, preserving their behavioral
// assertions).
// Covers: default-all seeding with archived animals invisible (D-22), live
// totals updates on deselection, the zero-selected disabled CTA, discard
// confirm only after a real deselection, the always-on immutability warning,
// the zero-doses backstop, lot-picker eligibility (only lots with active
// animals), and the D-34 duplicate gate with its forced checkbox.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:campo_gestor/features/sanitario/data/dose_repository.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:campo_gestor/features/sanitario/presentation/registrar_aplicacao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fakes
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

class _FakeSanitaryApplicationRepository
    extends SanitaryApplicationRepository {
  _FakeSanitaryApplicationRepository({this.duplicateId})
      : super(SupabaseService());

  final String? duplicateId;
  int registerCalls = 0;
  List<String>? lastAnimalIds;

  @override
  Future<String?> findRecentIdenticalApplication({
    required String lotId,
    required String doseId,
    required DateTime appliedAt,
  }) async =>
      duplicateId;

  @override
  Future<SanitaryApplication> registerApplication({
    required String lotId,
    required String doseId,
    required DateTime appliedAt,
    required List<String> animalIds,
    String? notes,
  }) async {
    registerCalls++;
    lastAnimalIds = animalIds;
    return _application();
  }
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');

Animal _animal({
  required String id,
  required int number,
  String category = 'vaca',
  String? breed,
  DateTime? deletedAt,
}) =>
    Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: 'lot-a',
      category: category,
      number: number,
      breed: breed,
      createdAt: DateTime(2026, 1, 1),
      deletedAt: deletedAt,
    );

Dose _dose({double? costPerKg}) => Dose(
      id: 'dose-1',
      propertyId: 'prop-1',
      name: 'Ivomec Gold',
      dosagePerKg: 1.0,
      costPerKg: costPerKg,
      createdAt: DateTime(2026, 1, 1),
    );

Lot _lot(String id, String name) => Lot(
      id: id,
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      name: name,
      createdAt: DateTime(2026, 1, 1),
    );

SanitaryApplication _application() => SanitaryApplication(
      id: 'app-1',
      propertyId: 'prop-1',
      lotId: 'lot-a',
      lotName: 'Lote A',
      paddockId: 'pad-1',
      paddockName: 'Piquete 1',
      doseId: 'dose-1',
      doseName: 'Ivomec Gold',
      dosagePerKg: 1.0,
      dosagePerUa: 400,
      appliedAt: DateTime(2026, 8, 6),
      appliedBy: 'user-1',
      animalCount: 2,
      totalUa: 2.0,
      totalVolume: 800,
      skippedCount: 0,
      createdAt: DateTime(2026, 8, 6),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  String? initialLotId = 'lot-a',
  List<Animal> animals = const [],
  List<Dose> doses = const [],
  List<LotWithPaddockCount> lotsWithCount = const [],
  _FakeSanitaryApplicationRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      propertyListProvider.overrideWith((ref) async => const []),
      animalListByLotProvider.overrideWith((ref, id) async => animals),
      loteByIdProvider.overrideWith((ref, id) async => _lot('lot-a', 'Lote A')),
      doseListByPropertyProvider.overrideWith((ref) async => doses),
      loteRepositoryProvider.overrideWithValue(
        _FakeLoteRepository(lotsWithCount),
      ),
      sanitaryApplicationRepositoryProvider.overrideWithValue(
        repo ?? _FakeSanitaryApplicationRepository(),
      ),
    ],
    child: MaterialApp(
      home: RegistrarAplicacaoScreen(initialLotId: initialLotId),
    ),
  );
}

/// Selects the sample dose through the Dose glass tile picker.
Future<void> _selectDose(WidgetTester tester) async {
  await tester.tap(find.text('Selecionar'));
  await tester.pumpAndSettle();
  await tester.tap(find.text('Ivomec Gold').last);
  await tester.pumpAndSettle();
}

void main() {
  group('RegistrarAplicacaoScreen (SANI-02/03, spec 4.10)', () {
    testWidgets(
        'every active animal arrives pre-checked; an archived animal never appears (D-22)',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1, breed: 'Angus'),
        _animal(id: 'a2', number: 2),
        _animal(id: 'a3', number: 3, deletedAt: DateTime(2026, 1, 2)),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      // Master checkbox + 2 row checkboxes — the archived #3 never renders.
      final checkboxes = tester.widgetList<Checkbox>(find.byType(Checkbox));
      expect(checkboxes, hasLength(3));
      expect(checkboxes.every((c) => c.value == true), isTrue);
      expect(find.text('#3'), findsNothing);
      expect(find.text('2 de 2'), findsOneWidget);
      expect(find.text('selecionados'), findsOneWidget);
      expect(find.text('2,0'), findsOneWidget);
      expect(find.text('UA somadas'), findsOneWidget);
      // Row anatomy: nº mono, categoria · raça, UA por animal.
      expect(find.text('Vaca · Angus'), findsOneWidget);
      expect(find.text('1,0 UA'), findsNWidgets(2));
    });

    testWidgets('unchecking one animal updates the live totals', (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      // Checkbox 0 is the master row; row checkboxes start at 1.
      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      expect(find.text('1 de 2'), findsOneWidget);
      expect(find.text('1,0'), findsOneWidget);
      // Master unchecks once not everyone is selected.
      final master = tester.widget<Checkbox>(find.byType(Checkbox).first);
      expect(master.value, isFalse);
    });

    testWidgets(
        '"Desmarcar" clears every row and disables the CTA; the master checkbox re-selects all',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals, doses: [_dose()]));
      await tester.pumpAndSettle();
      await _selectDose(tester);

      await tester.tap(find.text('Desmarcar'));
      await tester.pumpAndSettle();

      expect(find.text('0 de 2'), findsOneWidget);
      final cta = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar'),
      );
      expect(cta.onPressed, isNull);

      await tester.tap(find.byType(Checkbox).first);
      await tester.pumpAndSettle();
      expect(find.text('2 de 2'), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Registrar 2 animais'),
            )
            .onPressed,
        isNotNull,
      );
    });

    testWidgets('closing with nothing deselected pops directly, no dialog',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animals: [_animal(id: 'a1', number: 1)]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Descartar seleção?'), findsNothing);
      expect(find.byType(RegistrarAplicacaoScreen), findsNothing);
    });

    testWidgets(
        'closing after a deselection shows the discard-confirm dialog; cancelling keeps the deselection intact',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Checkbox).at(1));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Descartar seleção?'), findsOneWidget);
      expect(find.text('A seleção de animais será perdida.'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(RegistrarAplicacaoScreen), findsOneWidget);
      expect(find.text('1 de 2'), findsOneWidget);
    });

    testWidgets(
        'the immutability warning is always present above the CTA (D-23)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animals: [_animal(id: 'a1', number: 1)]),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ImmutabilityNotice), findsOneWidget);
      expect(find.textContaining('estornado'), findsOneWidget);
    });

    testWidgets(
        'zero-doses backstop: the picker explains no dose exists and the CTA stays disabled',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animals: [_animal(id: 'a1', number: 1)], doses: const []),
      );
      await tester.pumpAndSettle();

      // The CTA is disabled while no dose is selected.
      final cta = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar 1 animal'),
      );
      expect(cta.onPressed, isNull);

      await tester.tap(find.text('Selecionar'));
      await tester.pumpAndSettle();
      expect(
        find.text('Nenhuma dose cadastrada — cadastre uma dose primeiro'),
        findsOneWidget,
      );
    });

    testWidgets(
        'lot picker lists only lots with at least one active animal',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          initialLotId: null,
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
      await tester.pumpAndSettle();

      // No lot yet — the list area asks for one.
      expect(find.text('Escolha o lote'), findsOneWidget);

      // The Lote tile is the first "Selecionar".
      await tester.tap(find.text('Selecionar').first);
      await tester.pumpAndSettle();

      expect(find.text('Lote A'), findsWidgets);
      expect(find.text('Lote Vazio'), findsNothing);

      await tester.tap(find.text('Lote A').last);
      await tester.pumpAndSettle();
      expect(find.text('Escolha o lote'), findsNothing);
    });

    testWidgets(
        'duplicate found (D-34): confirm dialog gates the write behind a forced checkbox',
        (tester) async {
      final repo = _FakeSanitaryApplicationRepository(duplicateId: 'dup-1');
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(
        _buildScreen(animals: animals, doses: [_dose()], repo: repo),
      );
      await tester.pumpAndSettle();
      await _selectDose(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar 2 animais'));
      // While the confirm dialog is open, the CTA behind it still shows its
      // saving spinner (an infinite animation), so pumpAndSettle would time
      // out — pump bounded frames instead until the dialog closes.
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(
        find.textContaining('Uma aplicação idêntica'),
        findsOneWidget,
      );
      // Confirm stays disabled until the checkbox is ticked.
      var confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar mesmo assim'),
      );
      expect(confirm.onPressed, isNull);
      expect(repo.registerCalls, 0);

      await tester.tap(find.text('Sim, registrar mesmo assim'));
      await tester.pump();
      confirm = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Registrar mesmo assim'),
      );
      expect(confirm.onPressed, isNotNull);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar mesmo assim'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, 1);
      expect(repo.lastAnimalIds, ['a1', 'a2']);
      expect(find.byType(RegistrarAplicacaoScreen), findsNothing);
    });

    testWidgets('no duplicate: the CTA registers directly and pops',
        (tester) async {
      final repo = _FakeSanitaryApplicationRepository();
      await tester.pumpWidget(
        _buildScreen(
          animals: [_animal(id: 'a1', number: 1)],
          doses: [_dose()],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();
      await _selectDose(tester);

      await tester.tap(find.widgetWithText(FilledButton, 'Registrar 1 animal'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Uma aplicação idêntica'), findsNothing);
      expect(repo.registerCalls, 1);
      expect(find.byType(RegistrarAplicacaoScreen), findsNothing);
    });
  });
}
