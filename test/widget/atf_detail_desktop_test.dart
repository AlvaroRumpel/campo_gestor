// Quick task 260813-tos — AtfDetailScreen desktop table (>=1024px):
// AtfDgTableView with inline DG registration + batch selection, mobile path
// (_AtfDgBody) untouched. Fakes/overrides are local to this file (not
// imported from atf_detail_screen_test.dart, per the plan) — mirrors that
// file's fake-repo pattern plus animais_desktop_test.dart's
// setSurfaceSize harness.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/presentation/atf_detail_screen.dart';
import 'package:campo_gestor/features/reproducao/presentation/atf_dg_table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository
// ---------------------------------------------------------------------------

class _FakeAtfRepo extends AtfRepository {
  _FakeAtfRepo() : super(SupabaseService());

  List<Map<String, dynamic>>? capturedDgRecords;

  @override
  Future<void> saveDgRecords({
    required String atfBatchId,
    required List<Map<String, dynamic>> records,
  }) async {
    capturedDgRecords = records;
  }

  @override
  Future<void> removeAnimalFromAtf({
    required String atfBatchId,
    required String animalId,
  }) async {}
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vet = PropertyMembership(property: _prop, role: 'veterinarian');
const _reader = PropertyMembership(property: _prop, role: 'reader');

AtfBatch _atf({bool active = true}) => AtfBatch(
      id: 'atf-1',
      propertyId: 'prop-1',
      name: 'ATF Primavera',
      implantationDate: DateTime(2026, 9, 12),
      inseminationDate: DateTime(2026, 9, 22),
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
      animalDeleted: false,
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
// Widget builder + surface-size harness
// ---------------------------------------------------------------------------

Widget _buildScreen({
  required AtfBatch atf,
  List<AtfMembershipView> memberships = const [],
  List<DgRecord> dgRecords = const [],
  PropertyMembership membership = _vet,
  AtfRepository? repo,
}) {
  return ProviderScope(
    overrides: [
      atfByIdProvider.overrideWith((ref, id) async => atf),
      atfActiveMembershipsProvider
          .overrideWith((ref, id) async => memberships),
      atfMembershipsProvider.overrideWith((ref, id) async => memberships),
      dgRecordsByAtfProvider.overrideWith((ref, id) async => dgRecords),
      atfListByPropertyProvider.overrideWith((ref) async => const []),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
      atfRepositoryProvider.overrideWithValue(repo ?? _FakeAtfRepo()),
      // Lote/raça join source (assunção 7) — empty is fine for these
      // tests, rows fall back to "—".
      animalListByPropertyProvider.overrideWith((ref) async => const []),
    ],
    child: MaterialApp(
      home: AtfDetailScreen(atfId: atf.id),
    ),
  );
}

Future<void> _pumpDesktop(WidgetTester tester, Widget widget) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

Future<void> _pumpMobile(WidgetTester tester, Widget widget) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(widget);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AtfDetailScreen — desktop table (quick task 260813-tos)', () {
    testWidgets(
        '1440x900 renderiza AtfDgTableView e não renderiza AtfHeaderCard',
        (tester) async {
      await _pumpDesktop(
        tester,
        _buildScreen(atf: _atf(), memberships: [_membership('a1')]),
      );

      expect(find.byType(AtfDgTableView), findsOneWidget);
      expect(find.byType(AtfHeaderCard), findsNothing);
    });

    testWidgets(
        '800x600 renderiza AtfHeaderCard e nenhum AtfDgTableView — fluxo de hoje intacto',
        (tester) async {
      await _pumpMobile(
        tester,
        _buildScreen(atf: _atf(), memberships: [_membership('a1')]),
      );

      expect(find.byType(AtfHeaderCard), findsOneWidget);
      expect(find.byType(AtfDgTableView), findsNothing);
    });

    testWidgets(
        'Desktop: clicar "Prenhe" na linha de um animal sem DG chama saveDgRecords '
        'uma vez, com um registro, animal_id correto e result pregnant',
        (tester) async {
      final repo = _FakeAtfRepo();
      await _pumpDesktop(
        tester,
        _buildScreen(
          atf: _atf(),
          memberships: [_membership('a1')],
          repo: repo,
        ),
      );

      await tester.tap(find.text('Prenhe'));
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(1));
      expect(repo.capturedDgRecords!.single['animal_id'], 'a1');
      expect(repo.capturedDgRecords!.single['result'], 'pregnant');
    });

    testWidgets(
        'Desktop: marcar os checkboxes de dois animais mostra "2 selecionadas" e '
        '"Marcar vazia" envia UM payload com os dois animal_id e result not_pregnant',
        (tester) async {
      final repo = _FakeAtfRepo();
      await _pumpDesktop(
        tester,
        _buildScreen(
          atf: _atf(),
          memberships: [_membership('a1'), _membership('a2', number: 2)],
          repo: repo,
        ),
      );

      // Checkbox order: index 0 = "select all" header, 1/2 = row checkboxes
      // (a1, a2) — matches the table build order (header before rows).
      final checkboxes = find.byType(Checkbox);
      await tester.tap(checkboxes.at(1));
      await tester.pump();
      await tester.tap(checkboxes.at(2));
      await tester.pump();

      expect(find.text('2 selecionadas'), findsOneWidget);

      await tester.tap(find.text('Marcar vazia'));
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, hasLength(2));
      final ids =
          repo.capturedDgRecords!.map((r) => r['animal_id'] as String).toSet();
      expect(ids, {'a1', 'a2'});
      expect(
        repo.capturedDgRecords!.every((r) => r['result'] == 'not_pregnant'),
        isTrue,
      );
    });

    testWidgets(
        'Desktop: numa linha cujo DG mais recente já é pregnant, clicar "Prenhe" '
        'não chama saveDgRecords (no-op de re-registro, assunção 8)',
        (tester) async {
      final repo = _FakeAtfRepo();
      await _pumpDesktop(
        tester,
        _buildScreen(
          atf: _atf(),
          memberships: [_membership('a1')],
          dgRecords: [_dg('a1', 'pregnant')],
          repo: repo,
        ),
      );

      await tester.tap(find.text('Prenhe'));
      await tester.pumpAndSettle();

      expect(repo.capturedDgRecords, isNull);
    });

    testWidgets(
        'Desktop com papel reader: nenhum Checkbox e nenhum botão de resultado na tabela',
        (tester) async {
      await _pumpDesktop(
        tester,
        _buildScreen(
          atf: _atf(),
          memberships: [_membership('a1')],
          membership: _reader,
        ),
      );

      expect(find.byType(Checkbox), findsNothing);
      expect(find.text('Prenhe'), findsNothing);
      expect(find.text('Vazia'), findsNothing);
    });
  });
}
