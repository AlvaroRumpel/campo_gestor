// ANIM-05, ANIM-06 — AnimaisScreen: search by number + filter by category/lot/paddock.
// Wave 0 stubs. Implementation lands in Plan 06 (AnimaisScreen).
// Decisions enforced: D-18 (filters), D-19 (tile format), D-20 (debounce 300ms), D-21 (toggle archived).
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animais_screen.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
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
    animal: _animal(id: 'a42', number: 42, category: 'touro'),
    lotName: 'Lote A',
    paddockId: 'p1',
    paddockName: 'Piquete Norte',
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
    ],
    child: MaterialApp.router(routerConfig: _router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('AnimaisScreen — Search (ANIM-05)', () {
    testWidgets(
        'search field with hint "Buscar número" filters list in-memory after 300ms debounce',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump(); // start async
      await tester.pump(const Duration(milliseconds: 100)); // settle providers

      expect(find.text('Buscar número'), findsOneWidget);
    });

    testWidgets(
        'typing "4" matches animals whose number contains "4" (e.g. #4, #14, #42)',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump(const Duration(milliseconds: 350));

      // Should find tiles with numbers containing '4': #4, #14, #42
      expect(find.textContaining('#4'), findsWidgets);
    });

    testWidgets('clear button (X) appears when search field is non-empty',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      await tester.enterText(find.byType(TextField), '4');
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byIcon(Icons.close), findsOneWidget);
    });
  });

  group('AnimaisScreen — Filters (ANIM-06)', () {
    testWidgets(
        'renders FilterChips: Todas | Vaca | Novilha | Terneiro | Terneira | Touro | Boi | Novilho',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      for (final lbl in const [
        'Todas',
        'Vaca',
        'Novilha',
        'Terneiro',
        'Terneira',
        'Touro',
        'Boi',
        'Novilho',
      ]) {
        expect(
          find.widgetWithText(FilterChip, lbl),
          findsOneWidget,
          reason: 'Expected FilterChip with label "$lbl"',
        );
      }
    });

    testWidgets('selecting "Vaca" chip filters list to category == "vaca"',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Tap the 'Vaca' chip
      await tester.tap(find.widgetWithText(FilterChip, 'Vaca'));
      await tester.pump();

      // vacas in fake data (active): a1 (#1) and a4 (#4)
      expect(find.textContaining('#1'), findsWidgets);
      expect(find.textContaining('#4'), findsWidgets);
    });

    testWidgets(
        '"+ Lote" chip defaults to no lot filter; picking a lot filters by lot_id',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+ Lote'), findsOneWidget);
      expect(find.textContaining('#42'), findsWidgets); // unfiltered

      await tester.tap(find.text('+ Lote'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Lote B').last);
      await tester.pumpAndSettle();

      // Only #14 lives in lot-b; #42 (lot-a) is filtered out. The chip
      // becomes the removable "Lote B ✕".
      expect(find.textContaining('#14'), findsWidgets);
      expect(find.textContaining('#42'), findsNothing);
      expect(find.text('+ Lote'), findsNothing);
    });

    testWidgets(
        '"+ Piquete" chip defaults to no paddock filter; picking one filters by paddock_id',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('+ Piquete'), findsOneWidget);

      await tester.tap(find.text('+ Piquete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Piquete Sul').last);
      await tester.pumpAndSettle();

      // Only #14 lives in p2 (Piquete Sul); #42 (p1) is filtered out.
      expect(find.textContaining('#14'), findsWidgets);
      expect(find.textContaining('#42'), findsNothing);
      expect(find.text('+ Piquete'), findsNothing);
    });

    testWidgets('totals strip shows "X animais · Y,Y UA" updating with filters',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // 4 active animals: 1,0 + 1,0 + 0,75 + 1,5 = 4,25 → "4,3" (pt-BR).
      expect(find.text('4 animais · 4,3 UA'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilterChip, 'Vaca'));
      await tester.pump();

      expect(find.text('2 animais · 2,0 UA'), findsOneWidget);
    });

    testWidgets(
        '"Mostrar arquivados" toggle reveals archived animals with reason badge',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Archived animal (#5 - sale) should not be visible initially
      expect(find.text('Vendido'), findsNothing);

      // Toggle on
      await tester.tap(find.byType(Switch));
      await tester.pump();

      expect(find.text('Vendido'), findsOneWidget);
    });

    testWidgets(
        'list tile primary line format: "#42 · Touro"; secondary line: "<Lote> · <Piquete>"',
        (tester) async {
      await tester.pumpWidget(_buildScreen());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.textContaining('#'), findsWidgets);
      expect(find.textContaining(' · '), findsWidgets);
    });
  });

  group(
    'AnimaisScreen — Busca por número exato ignora o toggle de arquivados (D-17)',
    () {
      // A multi-digit number lets a "partial but not equal" search query
      // exist (single-digit #5 has no non-empty proper substring).
      final archivedMulti = AnimalWithContext(
        animal: _animal(
          id: 'a125',
          number: 125,
          category: 'vaca',
          baixaReason: 'death',
          deletedAt: _archived,
        ),
        lotName: 'Lote A',
        paddockId: 'p1',
        paddockName: 'Piquete Norte',
      );
      final animalsWithMulti = [..._fakeAnimals, archivedMulti];

      testWidgets(
          'toggle off + exact number search for an archived animal finds it',
          (tester) async {
        await tester.pumpWidget(_buildScreen(animals: animalsWithMulti));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.enterText(find.byType(TextField), '125');
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.textContaining('#125'), findsOneWidget);
      });

      testWidgets(
          'toggle off + partial (non-equal) number search does not find the archived animal',
          (tester) async {
        await tester.pumpWidget(_buildScreen(animals: animalsWithMulti));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.enterText(find.byType(TextField), '12');
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.textContaining('#125'), findsNothing);
      });

      testWidgets('toggle off + empty search does not find the archived animal',
          (tester) async {
        await tester.pumpWidget(_buildScreen(animals: animalsWithMulti));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        expect(find.textContaining('#125'), findsNothing);
      });

      testWidgets(
          'an archived animal surfaced by exact match still shows the baixa reason badge',
          (tester) async {
        await tester.pumpWidget(_buildScreen(animals: animalsWithMulti));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        await tester.enterText(find.byType(TextField), '125');
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.text('Morte'), findsOneWidget);
      });
    },
  );
}
