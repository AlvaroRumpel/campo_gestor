// REPR-01, REPR-04 — AtfDetailScreen widget tests (05-UI-SPEC.md E4, E10).
// Covers every AtfDetailScreen state named in the spec: loading, error,
// populated, partial, bull link (D-05), zero-DG (never "0%"), partial DG,
// and the neutral Ativo/Encerrado status badge (D-03).
import 'dart:async';

import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/presentation/atf_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

// ---------------------------------------------------------------------------
// Fake repository (05-06 — composition remove flow)
// ---------------------------------------------------------------------------

class _FakeAtfRepo extends AtfRepository {
  _FakeAtfRepo({this.shouldThrow = false}) : super(SupabaseService());

  final bool shouldThrow;
  int removeCallCount = 0;
  String? capturedAnimalId;

  // 05-08 — DG batch save capture. AtfRepository has no update/delete method
  // for dg_records at all (insert-only RPC, 05-01/05-03), so "no update or
  // delete call" is guaranteed by the API shape, not something this fake
  // needs to additionally track.
  List<Map<String, dynamic>>? capturedDgRecords;

  @override
  Future<void> removeAnimalFromAtf({
    required String atfBatchId,
    required String animalId,
  }) async {
    removeCallCount++;
    if (shouldThrow) throw Exception('boom');
    capturedAnimalId = animalId;
  }

  @override
  Future<void> saveDgRecords({
    required String atfBatchId,
    required List<Map<String, dynamic>> records,
  }) async {
    if (shouldThrow) throw Exception('boom');
    capturedDgRecords = records;
  }
}

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vet = PropertyMembership(property: _prop, role: 'veterinarian');
const _reader = PropertyMembership(property: _prop, role: 'reader');

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

AtfBatch _atf({
  String id = 'atf-1',
  String name = 'ATF Primavera',
  String? bullAnimalId,
  String? bullName,
  String? observation,
  bool active = true,
}) =>
    AtfBatch(
      id: id,
      propertyId: 'prop-1',
      name: name,
      implantationDate: DateTime(2026, 9, 12),
      inseminationDate: DateTime(2026, 9, 22),
      bullAnimalId: bullAnimalId,
      bullName: bullName,
      observation: observation,
      active: active,
      createdAt: DateTime(2026, 9, 12),
    );

AtfMembershipView _membership(
  String animalId, {
  int number = 1,
  bool active = true,
  bool animalDeleted = false,
}) =>
    AtfMembershipView(
      membershipId: 'm-$animalId',
      atfBatchId: 'atf-1',
      animalId: animalId,
      active: active,
      animalNumber: number,
      animalCategory: 'vaca',
      animalDeleted: animalDeleted,
    );

/// Drives the real `showDatePicker` via its input-mode toggle (Material 3
/// icon `Icons.edit_outlined`), typing [ddmmyyyy] rather than tapping a
/// calendar day — avoids depending on "today"'s position in the grid.
/// Mirrors the identical helper in atf_form_dialog_test.dart.
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

DgRecord _dg(
  String animalId,
  String result, {
  DateTime? examDate,
  DateTime? createdAt,
  String? id,
}) =>
    DgRecord(
      id: id ?? 'dg-$animalId',
      propertyId: 'prop-1',
      atfBatchId: 'atf-1',
      animalId: animalId,
      result: result,
      examDate: examDate ?? DateTime(2026, 10, 1),
      createdAt: createdAt ?? DateTime(2026, 10, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required AsyncValue<AtfBatch?> atf,
  List<AtfMembershipView> activeMemberships = const [],
  // 05-08 — the DG section reads the UNFILTERED membership list
  // (atfMembershipsProvider). Defaults to activeMemberships so plan-05-04/06
  // tests (which only ever set one list) keep behaving identically; DG tests
  // that need a closed-ATF full roster (D-16) pass this explicitly.
  List<AtfMembershipView>? allMemberships,
  List<DgRecord> dgRecords = const [],
  PropertyMembership membership = _vet,
  AtfRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      atfByIdProvider.overrideWith((ref, id) {
        return atf.when(
          data: (v) => Future.value(v),
          loading: () => Completer<AtfBatch?>().future,
          error: (e, st) => Future.error(e, st),
        );
      }),
      atfActiveMembershipsProvider
          .overrideWith((ref, id) async => activeMemberships),
      atfMembershipsProvider
          .overrideWith((ref, id) async => allMemberships ?? activeMemberships),
      dgRecordsByAtfProvider.overrideWith((ref, id) async => dgRecords),
      atfListByPropertyProvider.overrideWith((ref) async => const []),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      atfRepositoryProvider.overrideWithValue(repo ?? _FakeAtfRepo()),
    ],
    child: const MaterialApp(
      // 05-08 — full Global* delegates + pt-BR supportedLocales, matching
      // atf_form_dialog_test.dart's pattern: _DgSection's session-date and
      // per-row date pickers pass locale: Locale('pt', 'BR') explicitly,
      // which requires it present in supportedLocales.
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [Locale('pt', 'BR')],
      home: AtfDetailScreen(atfId: 'atf-1'),
    ),
  );
}

// ---------------------------------------------------------------------------
// Router harness (05-11, G-05-1-nav) — back button needs a real GoRouter in
// the tree to exercise the canPop()/pop() vs go(reproducao) fallback.
// ---------------------------------------------------------------------------

Widget _buildRoutedScreen({required AsyncValue<AtfBatch?> atf}) {
  final router = GoRouter(
    initialLocation: '/atf/atf-1',
    routes: [
      GoRoute(
        path: '/atf/:atfId',
        builder: (context, state) =>
            AtfDetailScreen(atfId: state.pathParameters['atfId']!),
      ),
      GoRoute(
        path: '/reproducao',
        builder: (context, state) =>
            const Scaffold(body: Text('reproducao-list')),
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      atfByIdProvider.overrideWith((ref, id) {
        return atf.when(
          data: (v) => Future.value(v),
          loading: () => Completer<AtfBatch?>().future,
          error: (e, st) => Future.error(e, st),
        );
      }),
      atfActiveMembershipsProvider.overrideWith((ref, id) async => const []),
      atfMembershipsProvider.overrideWith((ref, id) async => const []),
      dgRecordsByAtfProvider.overrideWith((ref, id) async => const []),
      atfListByPropertyProvider.overrideWith((ref) async => const []),
      memberPropertiesProvider.overrideWith((ref) async => const [_vet]),
      atfRepositoryProvider.overrideWithValue(_FakeAtfRepo()),
    ],
    child: MaterialApp.router(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      routerConfig: router,
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AtfDetailScreen (REPR-01, REPR-04, 05-UI-SPEC E4/E10)', () {
    testWidgets('loading: renders a CircularProgressIndicator', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(atf: const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.byType(AtfHeaderCard), findsNothing);
    });

    testWidgets(
        'error: renders the generic load-failure copy and no AtfHeaderCard',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.error(Exception('boom'), StackTrace.empty),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
        findsOneWidget,
      );
      expect(find.byType(AtfHeaderCard), findsNothing);
    });

    testWidgets('populated: renders name, both dates, and the bull name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(bullName: 'Trovão')),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATF Primavera'), findsWidgets);
      expect(find.text('12/09/2026'), findsOneWidget);
      expect(find.text('22/09/2026'), findsOneWidget);
      expect(find.text('Trovão'), findsOneWidget);
    });

    testWidgets(
        'partial: an ATF with null observation renders no Observação label',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Observação'), findsNothing);
    });

    testWidgets(
        'bull link: bullAnimalId set renders a tappable InkWell for the touro row',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(bullAnimalId: 'animal-9', bullName: 'Trovão')),
        ),
      );
      await tester.pumpAndSettle();

      // Scoped to AtfHeaderCard (05-06): _CompositionSection's own buttons
      // (OutlinedButton) also use InkWell internally, so an unscoped search
      // would collide with sibling widgets unrelated to the bull row.
      expect(
        find.descendant(
          of: find.byType(AtfHeaderCard),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'bull link: only bullName set renders plain text, no tappable',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf(bullName: 'Sêmen externo X'))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sêmen externo X'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AtfHeaderCard),
          matching: find.byType(InkWell),
        ),
        findsNothing,
      );
    });

    testWidgets(
        'bull link: legacy row (bullAnimalId set, bullName null) never renders the raw uuid (WR-01)',
        (tester) async {
      const legacyUuid = '11111111-2222-3333-4444-555555555555';
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(bullAnimalId: legacyUuid)),
        ),
      );
      await tester.pumpAndSettle();

      // Load-bearing: the uuid must never reach the widget tree as text.
      // Reverting the production `atf.bullName ?? 'Ver touro'` change (i.e.
      // going back to `atf.bullName ?? atf.bullAnimalId!`) must turn this red.
      expect(find.text(legacyUuid), findsNothing);
      expect(find.text('Ver touro'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(AtfHeaderCard),
          matching: find.byType(InkWell),
        ),
        findsOneWidget,
      );
    });

    testWidgets(
        'zero DG: renders "— · aguardando DG" and no widget containing "0%"',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1'), _membership('a2', number: 2)],
          dgRecords: const [],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('— · aguardando DG'), findsOneWidget);
      expect(find.textContaining('0%'), findsNothing);
    });

    testWidgets(
        'partial DG: 50 composed animals, 31 pregnant, renders 62% prenhez',
        (tester) async {
      final memberships = [
        for (var i = 0; i < 50; i++) _membership('a$i', number: i + 1),
      ];
      final records = [
        for (var i = 0; i < 31; i++) _dg('a$i', 'pregnant'),
        for (var i = 31; i < 50; i++) _dg('a$i', 'not_pregnant'),
      ];
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: memberships,
          dgRecords: records,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('62% prenhez'), findsOneWidget);
    });

    testWidgets('status badge: inactive ATF renders Encerrado', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf(active: false))),
      );
      await tester.pumpAndSettle();

      expect(find.text('Encerrado'), findsOneWidget);
      expect(find.text('Ativo'), findsNothing);
    });

    testWidgets('status badge: active ATF renders Ativo', (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Ativo'), findsOneWidget);
      expect(find.text('Encerrado'), findsNothing);
    });
  });

  group('_CompositionSection (REPR-02, 05-UI-SPEC E5, D-08)', () {
    testWidgets('three active memberships render three rows and a header count of three',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [
            _membership('a1'),
            _membership('a2', number: 2),
            _membership('a3', number: 3),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('(3 animais)'), findsOneWidget);
      expect(find.byType(ListTile), findsNWidgets(3));
    });

    testWidgets(
        'an animal with no DG renders a remove IconButton; one with a DG renders none',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1'), _membership('a2', number: 2)],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      // Only a2 (no DG) gets a remove affordance — a1 (has a DG) gets none.
      // Scoped by tooltip (05-08): the DG section now also renders
      // IconButtons (session date, per-row date/observation), so an
      // unscoped byType(IconButton) search is no longer unambiguous.
      expect(find.byTooltip('Remover do ATF'), findsOneWidget);
    });

    testWidgets('"+ Animais" is absent for a non-veterinarian override', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          membership: _reader,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Animais'), findsNothing);
    });

    testWidgets('"+ Animais" is absent for a closed ATF', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(active: false)),
          activeMemberships: [_membership('a1')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Animais'), findsNothing);
    });

    testWidgets('a zero-membership ATF renders "Nenhum animal neste ATF."', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum animal neste ATF.'), findsOneWidget);
    });

    testWidgets('confirming the remove dialog calls removeAnimalFromAtf once', (
      tester,
    ) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // Scoped by tooltip (05-08): see note above — no longer the only
      // IconButton in the tree once the DG section renders alongside it.
      await tester.tap(find.byTooltip('Remover do ATF'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(repo.removeCallCount, 1);
      expect(repo.capturedAnimalId, 'a1');
    });
  });

  group('_DgSection (REPR-03, REPR-04, 05-UI-SPEC E6, D-10..D-16)', () {
    testWidgets(
        'one row renders per membership including an inactive one, each with three chips',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          allMemberships: [
            _membership('a1'),
            _membership('a2', number: 2, active: false),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(6));
    });

    testWidgets(
        'G-05-2: a membership whose animal was archived by a baixa renders '
        'no row, while a normal member still renders its 3 chips',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          allMemberships: [
            _membership('a1'),
            _membership(
              'a2',
              number: 2,
              active: false,
              animalDeleted: true,
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Reverting the `rows` filter in _DgSectionState.build makes this 6.
      expect(find.byType(ChoiceChip), findsNWidgets(3));
    });

    testWidgets(
        'G-05-2: "Registrar DG" is hidden entirely when every membership is '
        'an archived animal', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: const [],
          allMemberships: [
            _membership('a1', active: false, animalDeleted: true),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar DG'), findsNothing);
    });

    testWidgets(
        'the save button is disabled with zero changes and becomes enabled after one chip is tapped',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
        ),
      );
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      expect(
        tester.widget<FilledButton>(saveButtonFinder).onPressed,
        isNull,
      );

      await tester.tap(find.widgetWithText(ChoiceChip, 'Prenha').first);
      await tester.pumpAndSettle();

      expect(
        tester.widget<FilledButton>(saveButtonFinder).onPressed,
        isNotNull,
      );
    });

    testWidgets(
        'tapping a different chip on an animal with an existing DG stages exactly one changed row',
        (tester) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // 05-09: this scenario (composition fully DG'd) now also renders the
      // encerramento banner above the DG section, pushing the chip below
      // the fixed test viewport — same off-screen-tap brittleness the
      // 05-08 summary already documented for sibling-widget growth.
      final chipFinder = find.widgetWithText(ChoiceChip, 'Não-prenha').first;
      await tester.ensureVisible(chipFinder);
      await tester.pumpAndSettle();
      await tester.tap(chipFinder);
      await tester.pumpAndSettle();
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(1));
      expect(repo.capturedDgRecords!.single['animal_id'], 'a1');
      expect(repo.capturedDgRecords!.single['result'], 'not_pregnant');
    });

    testWidgets(
        'exam_date defaults to the session date, and a per-animal override lands only in that entry',
        (tester) async {
      final repo = _FakeAtfRepo();
      // Local date, no `.toUtc()` — must mirror AtfRepository's `_dateOnlyFmt`
      // (WR-03). Converting to UTC first shifts the calendar day for any
      // UTC-behind offset, so this assertion used to fail after 21:00 in
      // America/Sao_Paulo while the app was behaving correctly.
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [
            _membership('a1'),
            _membership('a2', number: 2),
          ],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final chip0 = find.widgetWithText(ChoiceChip, 'Prenha').at(0);
      await tester.ensureVisible(chip0);
      await tester.pumpAndSettle();
      await tester.tap(chip0);
      await tester.pumpAndSettle();
      final chip1 = find.widgetWithText(ChoiceChip, 'Prenha').at(1);
      await tester.ensureVisible(chip1);
      await tester.pumpAndSettle();
      await tester.tap(chip1);
      await tester.pumpAndSettle();

      final eventIcon = find.byIcon(Icons.event).at(1);
      await tester.ensureVisible(eventIcon);
      await tester.pumpAndSettle();
      await _setDateViaInput(
        tester,
        eventIcon,
        '15/03/2026',
      );

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(2));
      final byAnimal = {
        for (final r in repo.capturedDgRecords!) r['animal_id'] as String: r,
      };
      expect(byAnimal['a1']!['exam_date'], today);
      expect(byAnimal['a2']!['exam_date'], '2026-03-15');
    });

    testWidgets('a row with an observation entered carries it in the payload',
        (tester) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Duvidosa').first);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Adicionar observação').first);
      await tester.pumpAndSettle();
      final obsFieldFinder = find.widgetWithText(TextFormField, 'Observação');
      await tester.ensureVisible(obsFieldFinder);
      await tester.pumpAndSettle();
      await tester.enterText(obsFieldFinder, 'Repetir exame em 30 dias');
      await tester.pumpAndSettle();
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(1));
      expect(
        repo.capturedDgRecords!.single['observation'],
        'Repetir exame em 30 dias',
      );
    });

    testWidgets(
        'CR-01: typing an observation on a row whose chip is never touched '
        'still saves that row, carrying the existing DG result forward',
        (tester) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // No chip tap at all — only the observation field is touched. Before
      // the CR-01 fix, _changedAnimalIds() never saw this row, so the save
      // button stayed disabled and the observation was unreachable.
      // 05-09: composition fully DG'd renders the encerramento banner above
      // the DG section, pushing it off the fixed test viewport.
      final obsIconFinder = find.byTooltip('Adicionar observação').first;
      await tester.ensureVisible(obsIconFinder);
      await tester.pumpAndSettle();
      await tester.tap(obsIconFinder);
      await tester.pumpAndSettle();
      final obsFieldFinder = find.widgetWithText(TextFormField, 'Observação');
      await tester.ensureVisible(obsFieldFinder);
      await tester.pumpAndSettle();
      await tester.enterText(obsFieldFinder, 'Reconfirmado em campo');
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      expect(
        tester.widget<FilledButton>(saveButtonFinder).onPressed,
        isNotNull,
      );
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(1));
      expect(repo.capturedDgRecords!.single['animal_id'], 'a1');
      // The already-persisted result must be carried forward since the
      // chip's staged value was never set for this row.
      expect(repo.capturedDgRecords!.single['result'], 'pregnant');
      expect(
        repo.capturedDgRecords!.single['observation'],
        'Reconfirmado em campo',
      );
    });

    testWidgets(
        'G-05-4: DG chip preselection follows examDate, not insertion order',
        (tester) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [
            // Inserted first (earlier createdAt), but greater examDate.
            _dg(
              'a1',
              'pregnant',
              id: 'dg-a1-1',
              examDate: DateTime(2026, 11, 15),
              createdAt: DateTime(2026, 11, 15),
            ),
            // Inserted later (greater createdAt), but earlier examDate.
            _dg(
              'a1',
              'not_pregnant',
              id: 'dg-a1-2',
              examDate: DateTime(2026, 11, 10),
              createdAt: DateTime(2026, 11, 20),
            ),
          ],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      final prenhaChip =
          find.widgetWithText(ChoiceChip, 'Prenha').first;
      final naoPrenhaChip =
          find.widgetWithText(ChoiceChip, 'Não-prenha').first;
      await tester.ensureVisible(prenhaChip);
      await tester.pumpAndSettle();

      expect(tester.widget<ChoiceChip>(prenhaChip).selected, isTrue);
      expect(tester.widget<ChoiceChip>(naoPrenhaChip).selected, isFalse);
    });

    testWidgets(
        'G-05-4: with no chip touched, an observation-only save carries '
        'forward the greater-examDate result', (tester) async {
      final repo = _FakeAtfRepo();
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [
            _dg(
              'a1',
              'pregnant',
              id: 'dg-a1-1',
              examDate: DateTime(2026, 11, 15),
              createdAt: DateTime(2026, 11, 15),
            ),
            _dg(
              'a1',
              'not_pregnant',
              id: 'dg-a1-2',
              examDate: DateTime(2026, 11, 10),
              createdAt: DateTime(2026, 11, 20),
            ),
          ],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      // 05-09: composition fully DG'd renders the encerramento banner above
      // the DG section, pushing it off the fixed test viewport.
      final obsIconFinder = find.byTooltip('Adicionar observação').first;
      await tester.ensureVisible(obsIconFinder);
      await tester.pumpAndSettle();
      await tester.tap(obsIconFinder);
      await tester.pumpAndSettle();
      final obsFieldFinder = find.widgetWithText(TextFormField, 'Observação');
      await tester.ensureVisible(obsFieldFinder);
      await tester.pumpAndSettle();
      await tester.enterText(obsFieldFinder, 'Confirmado');
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords!.single['result'], 'pregnant');
    });

    testWidgets(
        'a failing saveDgRecords leaves the staged chip selection intact',
        (tester) async {
      final repo = _FakeAtfRepo(shouldThrow: true);
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ChoiceChip, 'Duvidosa').first);
      await tester.pumpAndSettle();
      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(
        find.text('Erro ao salvar DGs. Tente novamente.'),
        findsOneWidget,
      );
      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Duvidosa').first)
            .selected,
        isTrue,
      );
    });

    testWidgets('the section is hidden for an ATF with zero active memberships',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar DG'), findsNothing);
    });

    testWidgets(
        'the DG chips are tappable for a CLOSED ATF while "+ Animais" stays absent (D-16)',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(active: false)),
          allMemberships: [_membership('a1', active: false)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Registrar DG'), findsOneWidget);
      expect(find.text('Animais'), findsNothing);

      await tester.tap(find.widgetWithText(ChoiceChip, 'Prenha').first);
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<ChoiceChip>(find.widgetWithText(ChoiceChip, 'Prenha').first)
            .selected,
        isTrue,
      );
    });

    testWidgets('"Salvar DGs" is absent for a non-veterinarian override', (
      tester,
    ) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          membership: _reader,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Salvar DGs'), findsNothing);
    });

    testWidgets(
        'E6 backstop: a 200-animal ATF builds, and the payload carries only the 3 changed rows',
        (tester) async {
      final repo = _FakeAtfRepo();
      final memberships = [
        for (var i = 0; i < 200; i++) _membership('a$i', number: i + 1),
      ];
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          // Composition stays small on purpose: it uses its own nested
          // shrinkWrap ListView (05-06), and a 200-row composition list
          // ahead of _DgSection in the outer page ListView would push the
          // DG section past the sliver's default lazy-build cache window in
          // this fixed-size test viewport (no real scroll occurs under
          // pumpAndSettle). allMemberships carries the 200 rows that
          // exercise the E6 DG-list backstop specifically.
          activeMemberships: memberships.take(3).toList(),
          allMemberships: memberships,
          repo: repo,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ChoiceChip), findsNWidgets(600));

      for (var i = 0; i < 3; i++) {
        final chip = find.widgetWithText(ChoiceChip, 'Prenha').at(i);
        await tester.ensureVisible(chip);
        await tester.pumpAndSettle();
        await tester.tap(chip);
      }
      await tester.pumpAndSettle();

      final saveButtonFinder = find.widgetWithText(FilledButton, 'Salvar DGs');
      await tester.ensureVisible(saveButtonFinder);
      await tester.pumpAndSettle();
      await tester.tap(saveButtonFinder);
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(3));
    });
  });

  group('encerramento (REPR-03, REPR-04, 05-UI-SPEC E4/section 3, D-15, D-16)', () {
    testWidgets(
        'the banner renders when the composition is non-empty and every animal has a DG',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todos os animais têm DG registrado.'), findsOneWidget);
    });

    testWidgets('the banner does not render when even one animal is pending',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1'), _membership('a2', number: 2)],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);
    });

    testWidgets(
        'the banner does not render for a non-veterinarian override, nor for a closed ATF',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
          membership: _reader,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);

      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(active: false)),
          activeMemberships: [_membership('a1')],
          allMemberships: [_membership('a1', active: false)],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);
    });

    testWidgets(
        'G-05-3: the banner does not render when composition churn leaves '
        'the historical DG total at the composition count but none of the '
        'CURRENT members are covered', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1'), _membership('a2', number: 2)],
          // Both DG records belong to animals no longer in the composition —
          // under the old gate (summarizeDg(...).pending) the historical
          // total reaches 2, matching compositionCount, and the banner
          // appeared. This is the churn case the user hit on ATF 4.
          dgRecords: [_dg('gone1', 'pregnant'), _dg('gone2', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);
    });

    testWidgets(
        'G-05-3: the AppBar encerrar dialog reports the same churn-case '
        'pending count as the banner, never a contradicting zero',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1'), _membership('a2', number: 2)],
          dgRecords: [_dg('gone1', 'pregnant'), _dg('gone2', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Encerrar ATF'));
      await tester.pumpAndSettle();

      expect(
        find.text('Ainda há 2 animais sem DG registrado.'),
        findsOneWidget,
      );
    });

    testWidgets("tapping the banner's dismiss icon hides it for the session",
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Todos os animais têm DG registrado.'), findsOneWidget);
      await tester.tap(find.byTooltip('Dispensar aviso'));
      await tester.pumpAndSettle();

      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);
    });

    testWidgets(
        'the AppBar encerrar action is absent for a closed ATF and for a non-veterinarian override',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(active: false)),
          allMemberships: [_membership('a1', active: false)],
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Encerrar ATF'), findsNothing);

      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf()),
          activeMemberships: [_membership('a1')],
          membership: _reader,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byTooltip('Encerrar ATF'), findsNothing);
    });

    testWidgets(
        'for a closed ATF: "+ Animais", the remove icons, the banner, and the '
        'AppBar encerrar action are all absent, while the DG chips stay '
        'present and interactive (D-16)', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.data(_atf(active: false)),
          activeMemberships: [_membership('a1')],
          allMemberships: [_membership('a1', active: false)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Animais'), findsNothing);
      expect(find.byTooltip('Remover do ATF'), findsNothing);
      expect(find.text('Todos os animais têm DG registrado.'), findsNothing);
      expect(find.byTooltip('Encerrar ATF'), findsNothing);

      expect(find.text('Registrar DG'), findsOneWidget);
      final chip = find.widgetWithText(ChoiceChip, 'Prenha').first;
      await tester.ensureVisible(chip);
      await tester.pumpAndSettle();
      await tester.tap(chip);
      await tester.pumpAndSettle();

      expect(tester.widget<ChoiceChip>(chip).selected, isTrue);
    });
  });

  group('back control (G-05-1-nav)', () {
    testWidgets('loading state renders a BackButton', (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: const AsyncValue.loading()),
      );
      await tester.pump();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('error state renders a BackButton', (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atf: AsyncValue.error(Exception('boom'), StackTrace.empty),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('null-ATF state renders a BackButton', (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: const AsyncValue.data(null)),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets('loaded-data state renders a BackButton', (tester) async {
      await tester.pumpWidget(
        _buildScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      expect(find.byType(BackButton), findsOneWidget);
    });

    testWidgets(
        'tapping the back control with no navigation history lands on /reproducao',
        (tester) async {
      await tester.pumpWidget(
        _buildRoutedScreen(atf: AsyncValue.data(_atf())),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();

      expect(find.text('reproducao-list'), findsOneWidget);
    });
  });
}
