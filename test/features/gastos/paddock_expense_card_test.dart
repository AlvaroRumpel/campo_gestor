// GAST-02 — PaddockExpenseSummaryCard: loading/error/populated states plus
// the tap-through to /gastos/:paddockId (D-09). See 07-07-PLAN.md <behavior>.
import 'dart:async';

import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/gastos/presentation/paddock_expense_summary_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
// Override is not re-exported by flutter_riverpod in Riverpod 3.x; riverpod is
// a transitive dependency of it, so this import needs the lint exemption.
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;

const _paddockId = 'pad-1';

Widget _buildCard(List<Override> overrides) {
  return ProviderScope(
    overrides: overrides,
    child: const MaterialApp(
      home: Scaffold(body: PaddockExpenseSummaryCard(paddockId: _paddockId)),
    ),
  );
}

// Router harness for the tap-through assertion.
//
// G-07-1 REGRESSION GUARD: this harness deliberately reproduces the REAL
// router's shape — /piquetes/:id nested inside a StatefulShellRoute branch,
// /gastos/:paddockId at root level outside it. The original harness declared
// /piquetes/:id at root level, where `context.push` to a sibling root route
// works fine; that is why the flat harness passed while the shipped app could
// only reach /gastos/:paddockId by editing the URL. Keep the shell here — a
// flat harness cannot catch this bug class.
Widget _buildRoutedCard(List<Override> overrides) {
  final shellKey = GlobalKey<NavigatorState>();
  final router = GoRouter(
    initialLocation: '/piquetes/$_paddockId',
    routes: [
      GoRoute(
        path: AppRoutes.gastosById,
        builder: (context, state) => Scaffold(
          body: Text('gastos-${state.pathParameters['paddockId']}'),
        ),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) => navigationShell,
        branches: [
          StatefulShellBranch(
            navigatorKey: shellKey,
            routes: [
              GoRoute(
                path: '/piquetes',
                builder: (context, state) => const Scaffold(body: Text('lista')),
                routes: [
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => Scaffold(
                      body: PaddockExpenseSummaryCard(
                        paddockId: state.pathParameters['id']!,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  group('PaddockExpenseSummaryCard', () {
    testWidgets('loading: shows title and a CircularProgressIndicator',
        (tester) async {
      final completer = Completer<double>();
      await tester.pumpWidget(_buildCard([
        paddockMonthExpenseTotalProvider
            .overrideWith((ref, paddockId) => completer.future),
      ]));
      await tester.pump();

      expect(find.text('Gastos'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets(
        'error: shows — and a refresh IconButton, never a formatted currency figure',
        (tester) async {
      await tester.pumpWidget(_buildCard([
        paddockMonthExpenseTotalProvider.overrideWith(
          (ref, paddockId) async => throw Exception('load failed'),
        ),
      ]));
      await tester.pumpAndSettle();

      expect(find.text('Gastos'), findsOneWidget);
      expect(find.text('—'), findsOneWidget);
      expect(find.widgetWithIcon(IconButton, Icons.refresh), findsOneWidget);
      expect(find.textContaining('R\$'), findsNothing);
    });

    testWidgets(
        'populated (zero): shows R\$ 0,00 este mês and the card stays tappable',
        (tester) async {
      await tester.pumpWidget(_buildCard([
        paddockMonthExpenseTotalProvider
            .overrideWith((ref, paddockId) async => 0.0),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('R\$ 0,00'), findsOneWidget);
      expect(find.textContaining('este mês'), findsOneWidget);
      final listTile = tester.widget<ListTile>(find.byType(ListTile));
      expect(listTile.onTap, isNotNull);
    });

    testWidgets('populated (non-zero): shows the formatted total',
        (tester) async {
      await tester.pumpWidget(_buildCard([
        paddockMonthExpenseTotalProvider
            .overrideWith((ref, paddockId) async => 1240.50),
      ]));
      await tester.pumpAndSettle();

      expect(find.textContaining('R\$ 1.240,50'), findsOneWidget);
      expect(find.textContaining('este mês'), findsOneWidget);
    });

    testWidgets(
        'tapping the card in the populated state navigates to /gastos/{paddockId}',
        (tester) async {
      await tester.pumpWidget(_buildRoutedCard([
        paddockMonthExpenseTotalProvider
            .overrideWith((ref, paddockId) async => 1240.50),
      ]));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(Card));
      await tester.pumpAndSettle();

      expect(find.text('gastos-$_paddockId'), findsOneWidget);
    });
  });
}
