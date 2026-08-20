// Task 3, quick task 260813-r4s — ReproducaoScreen desktop master-detail
// (>=Breakpoints.rail): ReproducaoTableView + IatfDetailPanel, mobile path
// untouched. Follows animais_desktop_test.dart's setSurfaceSize harness and
// reproducao_screen_test.dart's fake-data/router pattern.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_model.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:campo_gestor/features/reproducao/presentation/iatf_detail_panel.dart';
import 'package:campo_gestor/features/reproducao/presentation/reproducao_screen.dart';
import 'package:campo_gestor/features/reproducao/presentation/reproducao_table_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fake data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');

IatfBatch _atf({
  String id = 'iatf-1',
  String name = 'IATF Primavera',
  bool active = true,
}) =>
    IatfBatch(
      id: id,
      propertyId: 'prop-1',
      name: name,
      implantationDate: DateTime(2026, 9, 12),
      inseminationDate: DateTime(2026, 9, 22),
      active: active,
      createdAt: DateTime(2026, 9, 12),
    );

IatfSummary _summary({
  required IatfBatch iatf,
  int animalCount = 0,
  DgSummary dgSummary = const DgSummary(pregnant: 0, total: 0, pending: 0),
}) =>
    IatfSummary(iatf: iatf, animalCount: animalCount, dgSummary: dgSummary);

final _fakeIatfs = <IatfSummary>[
  _summary(
    iatf: _atf(),
    animalCount: 3,
    dgSummary: const DgSummary(pregnant: 1, total: 2, pending: 1),
  ),
];

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

// A fresh GoRouter per pump — a shared top-level instance would keep the
// location from a prior test's navigation (Continuar DGs -> /iatf/:id) alive
// across the next `_buildScreen`, since GoRouter itself isn't recreated by
// a new ProviderScope/MaterialApp.router.
GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(
            path: '/', builder: (context, state) => const ReproducaoScreen()),
        GoRoute(
          path: AppRoutes.iatfById,
          builder: (context, state) =>
              Scaffold(body: Text('iatf-${state.pathParameters['iatfId']}')),
        ),
      ],
    );

Widget _buildScreen({List<IatfSummary>? atfs}) {
  return ProviderScope(
    overrides: [
      iatfListByPropertyProvider.overrideWith((ref) async => atfs ?? _fakeIatfs),
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      iatfActiveMembershipsProvider.overrideWith((ref, id) async => const []),
      dgRecordsByIatfProvider.overrideWith((ref, id) async => const []),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pumpDesktop(WidgetTester tester, {List<IatfSummary>? atfs}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen(atfs: atfs));
  await tester.pumpAndSettle();
}

Future<void> _pumpMobile(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(_buildScreen());
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReproducaoScreen — mestre-detalhe desktop (Task 3, 260813-r4s)', () {
    testWidgets(
        '1440x900: renders ReproducaoTableView, not IatfDetailPanel, with the real-count subtitle',
        (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(ReproducaoTableView), findsOneWidget);
      expect(find.byType(IatfDetailPanel), findsNothing);
      expect(find.textContaining('DG pendente'), findsWidgets);
    });

    testWidgets(
        'tapping the IATF name in a row shows IatfDetailPanel; the table stays present',
        (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(IatfDetailPanel), findsNothing);

      await tester.tap(find.text('IATF Primavera').first);
      await tester.pump();

      expect(find.byType(IatfDetailPanel), findsOneWidget);
      expect(find.byType(ReproducaoTableView), findsOneWidget);
    });

    testWidgets(
        'with the panel open, tapping "Continuar DGs (N)" navigates to the existing IATF detail route',
        (tester) async {
      await _pumpDesktop(tester);

      await tester.tap(find.text('IATF Primavera').first);
      await tester.pump();
      expect(find.byType(IatfDetailPanel), findsOneWidget);

      await tester.tap(find.text('Continuar DGs (1)'));
      await tester.pumpAndSettle();

      expect(find.text('iatf-iatf-1'), findsOneWidget);
    });

    testWidgets(
        '800x600: no ReproducaoTableView/IatfDetailPanel, FAB present, IATF name on a card — mobile path',
        (tester) async {
      await _pumpMobile(tester);

      expect(find.byType(ReproducaoTableView), findsNothing);
      expect(find.byType(IatfDetailPanel), findsNothing);
      expect(find.byType(FloatingActionButton), findsOneWidget);
      expect(find.text('IATF Primavera'), findsOneWidget);
    });
  });
}
