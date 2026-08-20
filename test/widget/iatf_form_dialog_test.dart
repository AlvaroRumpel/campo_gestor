// REPR-01 — IatfFormDialog widget tests (05-UI-SPEC.md E2).
// Covers: blank-form validation, date-order validation, bull validation,
// the external-semen reveal, both valid-submission bull paths, and a
// repository failure leaving the dialog open.
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_model.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:campo_gestor/features/reproducao/presentation/iatf_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake in-memory IatfRepository — no mocktail chain needed.
// ---------------------------------------------------------------------------
class _FakeIatfRepository implements IatfRepository {
  _FakeIatfRepository({this.shouldThrow = false});

  final bool shouldThrow;
  int createCallCount = 0;
  Map<String, dynamic>? lastCreateArgs;

  @override
  Future<IatfBatch> createIatf({
    required String propertyId,
    required String name,
    required DateTime implantationDate,
    required DateTime inseminationDate,
    String? inseminationTime,
    String? bullAnimalId,
    String? bullName,
    String? observation,
  }) async {
    createCallCount++;
    lastCreateArgs = {
      'propertyId': propertyId,
      'name': name,
      'bullAnimalId': bullAnimalId,
      'bullName': bullName,
    };
    if (shouldThrow) throw Exception('boom');
    return IatfBatch(
      id: 'new-iatf-id',
      propertyId: propertyId,
      name: name,
      implantationDate: implantationDate,
      inseminationDate: inseminationDate,
      bullAnimalId: bullAnimalId,
      bullName: bullName,
      observation: observation,
      active: true,
      createdAt: DateTime.now(),
    );
  }

  @override
  Future<List<IatfBatch>> fetchIatfBatchesByProperty(String propertyId) async =>
      [];

  @override
  Future<IatfBatch?> fetchIatf(String id) async => null;

  @override
  Future<List<IatfMembershipView>> fetchMemberships(
    String iatfBatchId, {
    bool activeOnly = false,
  }) async =>
      [];

  @override
  Future<List<DgRecord>> fetchDgRecords(String iatfBatchId) async => [];

  @override
  Future<List<IatfSummary>> fetchIatfSummaries(String propertyId) async => [];

  @override
  Future<List<ReproductiveHistoryEntry>> fetchReproductiveHistory(
    String animalId,
  ) async =>
      [];

  @override
  Future<List<EligibleAnimal>> fetchEligibleAnimalsForIatf({
    required String propertyId,
    required String iatfBatchId,
  }) async =>
      [];

  @override
  Future<void> addAnimalsToIatf({
    required String iatfBatchId,
    required List<String> animalIds,
  }) async {}

  @override
  Future<void> removeAnimalFromIatf({
    required String iatfBatchId,
    required String animalId,
  }) async {}

  @override
  Future<void> saveDgRecords({
    required String iatfBatchId,
    required List<Map<String, dynamic>> records,
  }) async {}

  @override
  Future<void> closeIatf(String iatfBatchId) async {}

  @override
  Future<Map<String, AnimalReproStatus>> fetchAnimalReproStatusByProperty(
    String propertyId,
  ) async =>
      {};
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _touro = AnimalWithContext(
  animal: Animal(
    id: 'animal-touro-1',
    propertyId: 'prop-1',
    lotId: 'lot-a',
    category: 'touro',
    number: 12,
    createdAt: DateTime(2025, 1, 1),
  ),
  lotName: 'Lote A',
  paddockId: 'p1',
  paddockName: 'Piquete Norte',
);

/// With-breed fixture (WR-01) — exercises `_bullLabel`'s breed branch.
final _touroComBreed = AnimalWithContext(
  animal: Animal(
    id: 'animal-touro-2',
    propertyId: 'prop-1',
    lotId: 'lot-a',
    category: 'touro',
    number: 13,
    breed: 'Nelore',
    createdAt: DateTime(2025, 1, 1),
  ),
  lotName: 'Lote A',
  paddockId: 'p1',
  paddockName: 'Piquete Norte',
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildApp({
  required _FakeIatfRepository repo,
  List<AnimalWithContext> animals = const [],
}) {
  return ProviderScope(
    overrides: [
      iatfRepositoryProvider.overrideWithValue(repo),
      animalListByPropertyProvider.overrideWith((ref) async => animals),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            // Mirrors the app's own call site (reproducao_screen.dart):
            // sheet-style content hosted via showAdaptiveForm.
            onPressed: () => showAdaptiveForm<String>(
              context: ctx,
              builder: (_) => const IatfFormDialog(propertyId: 'prop-1'),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

/// Drives the real `showDatePicker` via its input-mode toggle (Material 3
/// icon `Icons.edit_outlined`), typing [ddmmyyyy] rather than tapping a
/// calendar day — avoids depending on "today"'s position in the grid.
Future<void> _setDateViaInput(
  WidgetTester tester,
  Finder calendarIcon,
  String ddmmyyyy,
) async {
  await tester.tap(calendarIcon);
  await tester.pumpAndSettle();
  await tester.tap(find.byIcon(Icons.edit_outlined));
  await tester.pumpAndSettle();
  await tester.enterText(find.byType(TextFormField).last, ddmmyyyy);
  await tester.pumpAndSettle();
  await tester.tap(find.text('OK'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('IatfFormDialog (REPR-01, 05-UI-SPEC E2)', () {
    testWidgets(
        'blank form: shows the name-required message and does not call createIatf',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(find.text('Nome do IATF é obrigatório'), findsOneWidget);
      expect(repo.createCallCount, 0);
    });

    testWidgets(
        'insemination before implantation: shows the date-order message',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );

      // Push implantation into the future; insemination stays at "today",
      // which is now before it.
      await _setDateViaInput(
        tester,
        find.byIcon(Icons.calendar_today).at(0),
        '31/12/2030',
      );

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Data de inseminação deve ser igual ou posterior à data de implantação',
        ),
        findsOneWidget,
      );
      expect(repo.createCallCount, 0);
    });

    testWidgets('unselected touro: shows the bull-selection message',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );
      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(
        find.text('Selecione um touro ou informe sêmen externo'),
        findsOneWidget,
      );
      expect(find.text('Nome do IATF é obrigatório'), findsNothing);
      expect(repo.createCallCount, 0);
    });

    testWidgets(
        'selecting the external-semen sentinel reveals the free-text bull field',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(
        find.text('Nome do touro / identificação do sêmen'),
        findsNothing,
      );

      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro / sêmen externo').last);
      await tester.pumpAndSettle();

      expect(
        find.text('Nome do touro / identificação do sêmen'),
        findsOneWidget,
      );
    });

    testWidgets(
        'valid submission with a real touro persists a readable bullName (WR-01)',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo, animals: [_touro]));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#12').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(repo.createCallCount, 1);
      expect(repo.lastCreateArgs?['bullAnimalId'], 'animal-touro-1');
      expect(repo.lastCreateArgs?['bullName'], '#12');
    });

    testWidgets(
        'valid submission with a real touro with breed persists "#num — breed" (WR-01)',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(
        _buildApp(repo: repo, animals: [_touro, _touroComBreed]),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#13 — Nelore').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(repo.createCallCount, 1);
      expect(repo.lastCreateArgs?['bullAnimalId'], 'animal-touro-2');
      expect(repo.lastCreateArgs?['bullName'], '#13 — Nelore');
    });

    testWidgets(
        'valid submission via external semen calls createIatf once with bullName set and bullAnimalId null',
        (tester) async {
      final repo = _FakeIatfRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Outro / sêmen externo').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(
          TextFormField,
          'Nome do touro / identificação do sêmen',
        ),
        'Sêmen X123',
      );

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(repo.createCallCount, 1);
      expect(repo.lastCreateArgs?['bullName'], 'Sêmen X123');
      expect(repo.lastCreateArgs?['bullAnimalId'], isNull);
    });

    testWidgets(
        'repository throw: leaves the dialog open and shows the IATF-creation-failure copy',
        (tester) async {
      final repo = _FakeIatfRepository(shouldThrow: true);
      await tester.pumpWidget(_buildApp(repo: repo, animals: [_touro]));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextFormField, 'Nome do IATF *'),
        'IATF Primavera',
      );
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('#12').last);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Criar IATF'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Não foi possível criar o IATF. Verifique os dados e tente novamente.',
        ),
        findsOneWidget,
      );
      expect(find.byType(IatfFormDialog), findsOneWidget);
    });
  });
}
