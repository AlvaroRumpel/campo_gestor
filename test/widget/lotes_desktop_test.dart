// Task 3, quick task 260813-ugd — PiquetesScreen aba Lotes desktop
// master-detail (>=Breakpoints.rail): LotesTableView + LoteDetailPanel,
// caminho mobile intacto. Harness `setSurfaceSize` de
// reproducao_desktop_test.dart; fixtures de piquetes_screen_test.dart.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/lotes/presentation/lote_detail_panel.dart';
import 'package:campo_gestor/features/lotes/presentation/lotes_list_view.dart';
import 'package:campo_gestor/features/lotes/presentation/lotes_table_view.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/piquetes/presentation/piquetes_screen.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fake data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');

final _paddock = Paddock(
  id: 'pad-1',
  propertyId: 'prop-1',
  name: 'Piquete 1',
  areaHa: 8.5,
  uaCapacity: 12,
  createdAt: DateTime(2026, 1, 1),
);

final _lotA = Lot(
  id: 'lot-a',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote A',
  createdAt: DateTime(2026, 1, 1),
);

final _lotB = Lot(
  id: 'lot-b',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote B',
  createdAt: DateTime(2026, 1, 1),
);

final _lots = <LotWithPaddockCount>[
  LotWithPaddockCount(lot: _lotA, paddockName: 'Piquete 1', activeAnimalCount: 2),
  LotWithPaddockCount(lot: _lotB, paddockName: 'Piquete 1', activeAnimalCount: 1),
];

Animal _animal(String id, {required String lotId, required String category}) =>
    Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: lotId,
      category: category,
      number: int.parse(id),
      createdAt: DateTime(2026, 1, 1),
    );

// Lote A: 2 vacas = 2,0 UA. Lote B: 1 terneiro = 0,5 UA — A ordena antes de B
// no sort padrão (UA desc).
final _animals = <AnimalWithContext>[
  AnimalWithContext(
    animal: _animal('1', lotId: 'lot-a', category: 'vaca'),
    lotName: 'Lote A',
    paddockId: 'pad-1',
    paddockName: 'Piquete 1',
  ),
  AnimalWithContext(
    animal: _animal('2', lotId: 'lot-a', category: 'vaca'),
    lotName: 'Lote A',
    paddockId: 'pad-1',
    paddockName: 'Piquete 1',
  ),
  AnimalWithContext(
    animal: _animal('3', lotId: 'lot-b', category: 'terneiro'),
    lotName: 'Lote B',
    paddockId: 'pad-1',
    paddockName: 'Piquete 1',
  ),
];

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const PiquetesScreen(),
        ),
        GoRoute(
          path: AppRoutes.loteById,
          builder: (context, state) =>
              Scaffold(body: Text('lote-${state.pathParameters['loteId']}')),
        ),
        GoRoute(
          path: AppRoutes.animais,
          builder: (context, state) => const Scaffold(body: Text('animais-stub')),
        ),
      ],
    );

Widget _buildScreen() {
  return ProviderScope(
    overrides: [
      paddockListProvider.overrideWith((ref) async => [_paddock]),
      loteWithPaddockListByPropertyProvider.overrideWith((ref) async => _lots),
      animalListByPropertyProvider.overrideWith((ref) async => _animals),
      paddockMonthExpenseTotalProvider.overrideWith((ref, id) async => 0.0),
      sanitaryApplicationListByPropertyProvider.overrideWith((ref) async => const []),
      animalReproStatusByPropertyProvider
          .overrideWith((ref) async => const <String, AnimalReproStatus>{}),
      // Single membership -> CurrentPropertyNotifier auto-selects it (D-04-01).
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pumpDesktop(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen());
  await tester.pumpAndSettle();
}

Future<void> _pumpMobile(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(_buildScreen());
  await tester.pumpAndSettle();
}

Future<void> _switchToLotes(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(InkWell, 'Lotes'));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('PiquetesScreen — aba Lotes mestre-detalhe desktop (260813-ugd)', () {
    testWidgets(
        '1440x900 aba Lotes: LotesTableView renders, not LotesListView/'
        'LoteDetailPanel, with the aggregated mono subtitle', (tester) async {
      await _pumpDesktop(tester);
      await _switchToLotes(tester);

      expect(find.byType(LotesTableView), findsOneWidget);
      expect(find.byType(LotesListView), findsNothing);
      expect(find.byType(LoteDetailPanel), findsNothing);
      expect(find.textContaining('UA/ha'), findsOneWidget);
    });

    testWidgets('sorts rows by UA desc by default (Lote A before Lote B)',
        (tester) async {
      await _pumpDesktop(tester);
      await _switchToLotes(tester);

      final aPos = tester.getTopLeft(find.text('Lote A'));
      final bPos = tester.getTopLeft(find.text('Lote B'));
      expect(aPos.dy, lessThan(bPos.dy));
    });

    testWidgets(
        'tapping a lot row shows LoteDetailPanel; the table stays present',
        (tester) async {
      await _pumpDesktop(tester);
      await _switchToLotes(tester);

      expect(find.byType(LoteDetailPanel), findsNothing);

      await tester.tap(find.text('Lote A'));
      await tester.pumpAndSettle();

      expect(find.byType(LoteDetailPanel), findsOneWidget);
      expect(find.byType(LotesTableView), findsOneWidget);
    });

    testWidgets(
        'panel shows Aplicação/Mover lote actions and the "ver na lista" link',
        (tester) async {
      await _pumpDesktop(tester);
      await _switchToLotes(tester);

      await tester.tap(find.text('Lote A'));
      await tester.pumpAndSettle();

      expect(find.widgetWithText(FilledButton, 'Aplicação'), findsOneWidget);
      expect(find.widgetWithText(OutlinedButton, 'Mover lote'), findsOneWidget);
      expect(find.text('Ver os 2 na lista de animais'), findsOneWidget);
    });

    testWidgets(
        '800x600 aba Lotes: no LotesTableView/LoteDetailPanel, LotesListView '
        'present — mobile path intact', (tester) async {
      await _pumpMobile(tester);
      await _switchToLotes(tester);

      expect(find.byType(LotesTableView), findsNothing);
      expect(find.byType(LoteDetailPanel), findsNothing);
      expect(find.byType(LotesListView), findsOneWidget);
    });
  });
}
