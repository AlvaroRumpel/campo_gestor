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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository (05-06 — composition remove flow)
// ---------------------------------------------------------------------------

class _FakeAtfRepo extends AtfRepository {
  _FakeAtfRepo({this.shouldThrow = false}) : super(SupabaseService());

  final bool shouldThrow;
  int removeCallCount = 0;
  String? capturedAnimalId;

  @override
  Future<void> removeAnimalFromAtf({
    required String atfBatchId,
    required String animalId,
  }) async {
    removeCallCount++;
    if (shouldThrow) throw Exception('boom');
    capturedAnimalId = animalId;
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

AtfMembershipView _membership(String animalId, {int number = 1}) =>
    AtfMembershipView(
      membershipId: 'm-$animalId',
      atfBatchId: 'atf-1',
      animalId: animalId,
      active: true,
      animalNumber: number,
      animalCategory: 'vaca',
    );

DgRecord _dg(String animalId, String result) => DgRecord(
      id: 'dg-$animalId',
      propertyId: 'prop-1',
      atfBatchId: 'atf-1',
      animalId: animalId,
      result: result,
      examDate: DateTime(2026, 10, 1),
      createdAt: DateTime(2026, 10, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required AsyncValue<AtfBatch?> atf,
  List<AtfMembershipView> activeMemberships = const [],
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
      atfMembershipsProvider.overrideWith((ref, id) async => activeMemberships),
      dgRecordsByAtfProvider.overrideWith((ref, id) async => dgRecords),
      atfListByPropertyProvider.overrideWith((ref) async => const []),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      atfRepositoryProvider.overrideWithValue(repo ?? _FakeAtfRepo()),
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: AtfDetailScreen(atfId: 'atf-1'),
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
      expect(find.byType(IconButton), findsOneWidget);
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

      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Remover'));
      await tester.pumpAndSettle();

      expect(repo.removeCallCount, 1);
      expect(repo.capturedAnimalId, 'a1');
    });
  });
}
