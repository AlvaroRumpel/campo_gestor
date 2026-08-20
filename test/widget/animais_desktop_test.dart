// Task 3, quick task 260813-p10 — AnimaisScreen desktop master-detail
// (>=1024px): AnimaisTableView + AnimalDetailPanel, mobile path untouched.
// Follows animais_screen_test.dart's fake-data/router pattern plus
// app_shell_test.dart's setSurfaceSize harness.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animais_screen.dart';
import 'package:campo_gestor/features/animais/presentation/animais_table_view.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_panel.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Fake data
// ---------------------------------------------------------------------------

final _now = DateTime(2025, 1, 1);
final _archived = DateTime(2025, 6, 1);

Animal _animal({
  required String id,
  required int number,
  required String category,
  String lotId = 'lot-a',
  String? baixaReason,
  DateTime? deletedAt,
}) => Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: lotId,
      category: category,
      number: number,
      createdAt: _now,
      baixaReason: baixaReason,
      deletedAt: deletedAt,
    );

final _fakeAnimals = <AnimalWithContext>[
  AnimalWithContext(
    animal: _animal(id: 'a1', number: 1, category: 'vaca'),
    lotName: 'Lote A',
    paddockId: 'p1',
    paddockName: 'Piquete Norte',
  ),
  AnimalWithContext(
    animal: _animal(id: 'a4', number: 4, category: 'vaca'),
    lotName: 'Lote A',
    paddockId: 'p1',
    paddockName: 'Piquete Norte',
  ),
  AnimalWithContext(
    animal: _animal(id: 'a14', number: 14, category: 'novilha', lotId: 'lot-b'),
    lotName: 'Lote B',
    paddockId: 'p2',
    paddockName: 'Piquete Sul',
  ),
  AnimalWithContext(
    animal: _animal(
      id: 'a5',
      number: 5,
      category: 'vaca',
      baixaReason: 'sale',
      deletedAt: _archived,
    ),
    lotName: 'Lote A',
    paddockId: 'p1',
    paddockName: 'Piquete Norte',
  ),
];

final _fakePaddocks = <Paddock>[
  Paddock(
    id: 'p1',
    propertyId: 'prop-1',
    name: 'Piquete Norte',
    areaHa: 10,
    uaCapacity: 20,
    createdAt: _now,
  ),
  Paddock(
    id: 'p2',
    propertyId: 'prop-1',
    name: 'Piquete Sul',
    areaHa: 8,
    uaCapacity: 15,
    createdAt: _now,
  ),
];

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

final _router = GoRouter(
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const AnimaisScreen(),
    ),
    GoRoute(
      path: '/animais/:id',
      builder: (context, state) =>
          Scaffold(body: Text('detail-${state.pathParameters['id']}')),
    ),
  ],
);

Widget _buildScreen({List<AnimalWithContext>? animals}) {
  return ProviderScope(
    overrides: [
      animalListByPropertyProvider.overrideWith(
        (ref) async => animals ?? _fakeAnimals,
      ),
      paddockListProvider.overrideWith(
        (ref) async => _fakePaddocks,
      ),
      animalReproStatusByPropertyProvider.overrideWith(
        (ref) async => const <String, AnimalReproStatus>{},
      ),
    ],
    child: MaterialApp.router(routerConfig: _router),
  );
}

Future<void> _pumpDesktop(WidgetTester tester, {List<AnimalWithContext>? animals}) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen(animals: animals));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

Future<void> _pumpMobile(WidgetTester tester) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(_buildScreen());
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnimaisScreen — mestre-detalhe desktop (Task 3, 260813-p10)', () {
    testWidgets(
        '1440x900: renders AnimaisTableView, not the mobile grouped list',
        (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(AnimaisTableView), findsOneWidget);
      expect(find.text('Buscar por número ou lote'), findsOneWidget);
      expect(find.text('Buscar número'), findsNothing);
    });

    testWidgets(
        'tapping a table row shows AnimalDetailPanel; table rows stay present',
        (tester) async {
      await _pumpDesktop(tester);

      expect(find.byType(AnimalDetailPanel), findsNothing);

      await tester.tap(find.text('#1'));
      await tester.pump();

      expect(find.byType(AnimalDetailPanel), findsOneWidget);
      expect(find.byType(AnimaisTableView), findsOneWidget);
      // The row is still in the table tree (findsWidgets: table cell + panel header both say #1).
      expect(find.text('#1'), findsWidgets);
      expect(find.text('#4'), findsOneWidget);
    });

    testWidgets('tapping the panel close button hides it; table remains',
        (tester) async {
      await _pumpDesktop(tester);

      await tester.tap(find.text('#1'));
      await tester.pump();
      expect(find.byType(AnimalDetailPanel), findsOneWidget);

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(find.byType(AnimalDetailPanel), findsNothing);
      expect(find.byType(AnimaisTableView), findsOneWidget);
    });

    testWidgets(
        '800x600: renders the mobile grouped list, no AnimaisTableView/AnimalDetailPanel',
        (tester) async {
      await _pumpMobile(tester);

      expect(find.byType(AnimaisTableView), findsNothing);
      expect(find.byType(AnimalDetailPanel), findsNothing);
      expect(find.text('Buscar número'), findsOneWidget);
    });

    testWidgets(
        'an archived animal with "Com baixa" scope active shows the reason badge, never hidden',
        (tester) async {
      await _pumpDesktop(tester);

      // "Ativos" scope is the default — the archived animal is hidden.
      expect(find.text('#5'), findsNothing);
      expect(find.text('Baixa · Vendido'), findsNothing);

      await tester.tap(find.textContaining('Com baixa'));
      await tester.pump();

      expect(find.text('#5'), findsOneWidget);
      expect(find.text('Baixa · Vendido'), findsOneWidget);
    });

    testWidgets(
        'switching a filter so the selected animal drops out of the list closes the panel',
        (tester) async {
      await _pumpDesktop(tester);

      await tester.tap(find.text('#14'));
      await tester.pump();
      expect(find.byType(AnimalDetailPanel), findsOneWidget);

      // Filter to "Lote A" — #14 lives in lot-b and drops out of `filtered`.
      await tester.tap(find.text('+ Lote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lote A').last);
      await tester.pumpAndSettle();

      expect(find.text('#14'), findsNothing);
      expect(find.byType(AnimalDetailPanel), findsNothing);
    });
  });
}
