// ANIM-03, D-08, D-09, SC-2, SC-3, D-04 — AnimalReproductiveHistorySection
// isolated widget tests. Widget under test is
// AnimalReproductiveHistorySection mounted directly (not the whole ficha) —
// mirrors sanitary_history_section_test.dart's approach (08-03), possible
// only because 08-02 extracted the section into its own public widget. See
// 08-PATTERNS.md §DG row expansion and §360px-width widget test harness.
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/presentation/animal_reproductive_history_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _animalId = 'animal-1';

/// Same short `dd/MM` formatter the row uses for insemination/implantation
/// dates — used here to build the expected text for those assertions.
final _shortFmt = DateFormat('dd/MM', 'pt_BR');

/// Same full `dd/MM/yyyy` formatter the DG sub-row uses for exam dates.
final _examFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

const _longObservation =
    'Confirmado por palpação retal com evidência clara de vesícula '
    'amniótica e batimento cardíaco fetal perceptível, animal calmo e '
    'colaborativo durante todo o procedimento, sem intercorrências.';

final _dg1 = DgRecord(
  id: 'dg-1',
  propertyId: 'prop-1',
  atfBatchId: 'atf-3dg',
  animalId: _animalId,
  result: DgResult.pregnant.dbValue,
  examDate: DateTime(2026, 3, 10),
  observation: _longObservation,
  createdAt: DateTime(2026, 3, 10),
);
final _dg2 = DgRecord(
  id: 'dg-2',
  propertyId: 'prop-1',
  atfBatchId: 'atf-3dg',
  animalId: _animalId,
  result: DgResult.doubtful.dbValue,
  examDate: DateTime(2026, 2, 5),
  createdAt: DateTime(2026, 2, 5),
);
final _dg3 = DgRecord(
  id: 'dg-3',
  propertyId: 'prop-1',
  atfBatchId: 'atf-3dg',
  animalId: _animalId,
  result: DgResult.notPregnant.dbValue,
  examDate: DateTime(2026, 1, 2),
  createdAt: DateTime(2026, 1, 2),
);
final _dgSingle = DgRecord(
  id: 'dg-single',
  propertyId: 'prop-1',
  atfBatchId: 'atf-1dg',
  animalId: _animalId,
  result: DgResult.pregnant.dbValue,
  examDate: DateTime(2026, 5, 1),
  createdAt: DateTime(2026, 5, 1),
);

/// 3 DGs — gains the expand affordance (D-08); has a bull (D-09).
final _entryThreeDgs = ReproductiveHistoryEntry(
  atfBatchId: 'atf-3dg',
  atfName: 'ATF Três DGs',
  inseminationDate: DateTime(2026, 1, 1),
  atfActive: true,
  lastDgResult: DgResult.pregnant,
  lastDgDate: DateTime(2026, 3, 10),
  dgRecords: [_dg1, _dg2, _dg3],
  bullName: 'Touro 123',
  implantationDate: DateTime(2025, 12, 20),
);

/// 1 DG — no expand affordance; bull left null to cover the optional branch.
final _entryOneDg = ReproductiveHistoryEntry(
  atfBatchId: 'atf-1dg',
  atfName: 'ATF Um DG',
  inseminationDate: DateTime(2026, 4, 1),
  atfActive: true,
  lastDgResult: DgResult.pregnant,
  lastDgDate: DateTime(2026, 5, 1),
  dgRecords: [_dgSingle],
  implantationDate: DateTime(2026, 3, 25),
);

/// 0 DGs — no expand affordance.
final _entryZeroDgs = ReproductiveHistoryEntry(
  atfBatchId: 'atf-0dg',
  atfName: 'ATF Zero DG',
  inseminationDate: DateTime(2026, 6, 1),
  atfActive: true,
  lastDgResult: null,
  lastDgDate: null,
  dgRecords: const [],
  implantationDate: DateTime(2026, 5, 25),
);

// ---------------------------------------------------------------------------
// Widget builders
// ---------------------------------------------------------------------------
//
// retry is always disabled: Riverpod 3.x's ProviderContainer.defaultRetry
// (~200ms backoff) would otherwise race the manual "Tentar novamente" tap
// and any induced-error assertion (08-03-SUMMARY.md's caveat).

Widget _buildSection({
  required Future<List<ReproductiveHistoryEntry>> Function(String animalId)
  historyBuilder,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      reproductiveHistoryByAnimalProvider.overrideWith(
        (ref, id) => historyBuilder(id),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: AnimalReproductiveHistorySection(animalId: _animalId),
      ),
    ),
  );
}

Widget _buildRoutedSection({
  required Future<List<ReproductiveHistoryEntry>> Function(String animalId)
  historyBuilder,
}) {
  final router = GoRouter(
    initialLocation: '/section',
    routes: [
      GoRoute(
        path: '/section',
        builder: (context, state) => const Scaffold(
          body: AnimalReproductiveHistorySection(animalId: _animalId),
        ),
      ),
      GoRoute(
        path: '/atf/:atfId',
        builder: (context, state) =>
            Scaffold(body: Text('atf-detail-${state.pathParameters['atfId']}')),
      ),
    ],
  );
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      reproductiveHistoryByAnimalProvider.overrideWith(
        (ref, id) => historyBuilder(id),
      ),
    ],
    child: MaterialApp.router(routerConfig: router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group(
    'AnimalReproductiveHistorySection — DG expansion (SC-2, SC-3, D-08)',
    () {
      testWidgets('ATF with 3 DGs renders an ExpansionTile', (tester) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsOneWidget);
      });

      testWidgets('ATF with 1 DG or 0 DGs render no ExpansionTile', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(
            historyBuilder: (id) async => [_entryOneDg, _entryZeroDgs],
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(ExpansionTile), findsNothing);
      });

      testWidgets(
        'collapsed: non-latest DG dates are hidden; expanding reveals all three',
        (tester) async {
          await tester.pumpWidget(
            _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
          );
          await tester.pumpAndSettle();

          expect(find.text(_examFmt.format(_dg2.examDate)), findsNothing);
          expect(find.text(_examFmt.format(_dg3.examDate)), findsNothing);

          await tester.tap(find.byIcon(Icons.expand_more));
          await tester.pumpAndSettle();

          expect(find.text(_examFmt.format(_dg1.examDate)), findsOneWidget);
          expect(find.text(_examFmt.format(_dg2.examDate)), findsOneWidget);
          expect(find.text(_examFmt.format(_dg3.examDate)), findsOneWidget);
          expect(find.textContaining(_longObservation), findsOneWidget);
        },
      );

      testWidgets('expanded DG sub-rows are ordered most-recent-first (SC-3)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pumpAndSettle();

        final dg1Y = tester
            .getTopLeft(find.text(_examFmt.format(_dg1.examDate)))
            .dy;
        final dg2Y = tester
            .getTopLeft(find.text(_examFmt.format(_dg2.examDate)))
            .dy;
        final dg3Y = tester
            .getTopLeft(find.text(_examFmt.format(_dg3.examDate)))
            .dy;

        expect(dg1Y, lessThan(dg2Y));
        expect(dg2Y, lessThan(dg3Y));
      });
    },
  );

  group(
    'AnimalReproductiveHistorySection — bull and implantation date (D-09)',
    () {
      testWidgets('summary row contains the bull name when the entry has one', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('touro: Touro 123'), findsOneWidget);
      });

      testWidgets('summary row has no bull chunk when bullName is null', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryOneDg]),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('touro:'), findsNothing);
      });

      testWidgets('summary row contains the formatted implantation date', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryOneDg]),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'implant. ${_shortFmt.format(_entryOneDg.implantationDate)}',
          ),
          findsOneWidget,
        );
      });
    },
  );

  group('AnimalReproductiveHistorySection — navigation vs expansion coexist '
      '(planner assumption 2)', () {
    testWidgets('tapping the ATF name text navigates to the ATF detail route', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildRoutedSection(historyBuilder: (id) async => [_entryThreeDgs]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.textContaining('ATF Três DGs'));
      await tester.pumpAndSettle();

      expect(find.text('atf-detail-atf-3dg'), findsOneWidget);
    });

    testWidgets(
      'tapping the expand chevron reveals sub-rows and does not navigate',
      (tester) async {
        await tester.pumpWidget(
          _buildRoutedSection(historyBuilder: (id) async => [_entryThreeDgs]),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byIcon(Icons.expand_more));
        await tester.pumpAndSettle();

        expect(find.text('atf-detail-atf-3dg'), findsNothing);
        expect(find.text(_examFmt.format(_dg1.examDate)), findsOneWidget);
      },
    );
  });

  group('AnimalReproductiveHistorySection — error and retry (D-04)', () {
    testWidgets(
      'error state renders the error message AND a "Tentar novamente" button',
      (tester) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => throw Exception('boom')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico reprodutivo.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Tentar novamente'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'tapping "Tentar novamente" retries the fetch; rows replace the error on success',
      (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          _buildSection(
            historyBuilder: (id) async {
              callCount++;
              if (callCount == 1) throw Exception('boom');
              return [_entryOneDg];
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico reprodutivo.'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico reprodutivo.'),
          findsNothing,
        );
        expect(find.textContaining('ATF Um DG'), findsOneWidget);
      },
    );

    testWidgets(
      'success state (with data) renders no "Tentar novamente" button',
      (tester) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryOneDg]),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextButton, 'Tentar novamente'),
          findsNothing,
        );
      },
    );
  });

  group(
    'AnimalReproductiveHistorySection — content states (D-19, D-20, D-06)',
    () {
      testWidgets('empty list renders the section empty message', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => const []),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Nenhum ATF registrado para este animal.'),
          findsOneWidget,
        );
      });

      testWidgets(
        'N entries render N rows, with no "Ver todos" control (D-06)',
        (tester) async {
          await tester.pumpWidget(
            _buildSection(
              historyBuilder: (id) async => [
                _entryThreeDgs,
                _entryOneDg,
                _entryZeroDgs,
              ],
            ),
          );
          await tester.pumpAndSettle();

          expect(find.textContaining('ATF Três DGs'), findsOneWidget);
          expect(find.textContaining('ATF Um DG'), findsOneWidget);
          expect(find.textContaining('ATF Zero DG'), findsOneWidget);
          expect(find.textContaining('Ver todo'), findsNothing);
        },
      );

      testWidgets('the section shell itself is never collapsible (D-19)', (
        tester,
      ) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
        );
        await tester.pumpAndSettle();

        expect(
          find.ancestor(
            of: find.text('Histórico Reprodutivo'),
            matching: find.byType(ExpansionTile),
          ),
          findsNothing,
        );
      });
    },
  );

  group('AnimalReproductiveHistorySection — 360px width backstop '
      '(SC-5, overflow/long-text)', () {
    testWidgets('DG observation wraps instead of overflowing at 360px width', (
      tester,
    ) async {
      addTearDown(tester.view.resetPhysicalSize);
      tester.view.physicalSize = const Size(360, 800);
      tester.view.devicePixelRatio = 1.0;

      await tester.pumpWidget(
        _buildSection(historyBuilder: (id) async => [_entryThreeDgs]),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('vesícula amniótica'), findsOneWidget);
    });
  });
}
