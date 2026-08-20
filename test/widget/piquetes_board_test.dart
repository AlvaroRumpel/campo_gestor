// Task 3, quick task 260813-v19 — quadro (kanban) desktop da aba Piquetes.
// Harness/fixtures copiados de lotes_desktop_test.dart (260813-ugd):
// mesmo ProviderScope de overrides, mesmo GoRouter stub, mesmos
// _pumpDesktop/_pumpMobile.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/lotes/presentation/lote_detail_panel.dart';
import 'package:campo_gestor/features/lotes/presentation/lotes_table_view.dart';
import 'package:campo_gestor/features/lotes/presentation/mover_lote_dialog.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/piquetes/presentation/piquetes_board_view.dart';
import 'package:campo_gestor/features/piquetes/presentation/piquetes_screen.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
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
const _readonlyMembership =
    PropertyMembership(property: _prop, role: 'proprietario');

final _pad1 = Paddock(
  id: 'pad-1',
  propertyId: 'prop-1',
  name: 'Piquete 1',
  areaHa: 8.5,
  uaCapacity: 12,
  createdAt: DateTime(2026, 1, 1),
);

final _pad2 = Paddock(
  id: 'pad-2',
  propertyId: 'prop-1',
  name: 'Piquete 2',
  areaHa: 5.0,
  uaCapacity: 6,
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

Widget _buildScreen({bool canEdit = true}) {
  return ProviderScope(
    overrides: [
      paddockListProvider.overrideWith((ref) async => [_pad1, _pad2]),
      loteWithPaddockListByPropertyProvider.overrideWith((ref) async => _lots),
      animalListByPropertyProvider.overrideWith((ref) async => _animals),
      paddockMonthExpenseTotalProvider.overrideWith((ref, id) async => 0.0),
      sanitaryApplicationListByPropertyProvider.overrideWith((ref) async => const []),
      animalReproStatusByPropertyProvider
          .overrideWith((ref) async => const <String, AnimalReproStatus>{}),
      // Single membership -> CurrentPropertyNotifier auto-selects it (D-04-01).
      memberPropertiesProvider.overrideWith(
        (ref) async => [canEdit ? _vetMembership : _readonlyMembership],
      ),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pumpDesktop(WidgetTester tester, {bool canEdit = true}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen(canEdit: canEdit));
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
  group('PiquetesScreen — quadro (kanban) desktop da aba Piquetes (260813-v19)',
      () {
    testWidgets(
        '1440x900: PiquetesBoardView renders with a column per paddock and a '
        'drag handle per lot', (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(PiquetesBoardView), findsOneWidget);
      expect(find.text('Piquete 1'), findsOneWidget);
      expect(find.text('Piquete 2'), findsOneWidget);
      expect(find.byIcon(Icons.drag_indicator), findsNWidgets(2));
    });

    testWidgets(
        'tapping a lot card (no drag) shows LoteDetailPanel; the board stays',
        (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(LoteDetailPanel), findsNothing);

      await tester.tap(find.text('Lote A'));
      await tester.pumpAndSettle();

      expect(find.byType(LoteDetailPanel), findsOneWidget);
      expect(find.byType(PiquetesBoardView), findsOneWidget);
    });

    testWidgets(
        'dragging a card into another column shows the drop-zone preview and '
        'opens MoverLoteDialog pre-selected on drop', (tester) async {
      await _pumpDesktop(tester);

      final gesture =
          await tester.startGesture(tester.getCenter(find.text('Lote A')));
      await gesture.moveBy(const Offset(0, 24));
      await tester.pump();

      await gesture.moveTo(
        tester.getCenter(find.byKey(const ValueKey('board-drop-pad-2'))),
      );
      await tester.pump();

      expect(find.textContaining('fica'), findsWidgets);

      await gesture.up();
      await tester.pumpAndSettle();

      expect(find.byType(MoverLoteDialog), findsOneWidget);
      expect(find.text('Confirmar movimentação'), findsOneWidget);
    });

    testWidgets(
        'without edit permission: no Draggable, board still renders read-only',
        (tester) async {
      await _pumpDesktop(tester, canEdit: false);

      expect(find.byType(Draggable<LotWithPaddockCount>), findsNothing);
      expect(find.byType(PiquetesBoardView), findsOneWidget);
    });

    testWidgets(
        '800x600: no PiquetesBoardView, mobile list intact', (tester) async {
      await _pumpMobile(tester);

      expect(find.byType(PiquetesBoardView), findsNothing);
      expect(find.text('hectares'), findsWidgets);
    });

    testWidgets(
        'shared header segmented: tapping "Lotes" from the board switches to '
        'LotesTableView', (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(PiquetesBoardView), findsOneWidget);

      await tester.tap(find.widgetWithText(InkWell, 'Lotes'));
      await tester.pumpAndSettle();

      expect(find.byType(LotesTableView), findsOneWidget);
      expect(find.byType(PiquetesBoardView), findsNothing);
    });
  });
}
