// G-07-1 regression guard (found in Phase 7 UAT): the /gastos/:paddockId
// screen was reported as reachable only by editing the URL. Phase 7 shipped a
// PaddockExpenseSummaryCard wired into PaddockDetailScreen as the entry point,
// but nothing asserted that it actually renders THERE — 07-07's own test
// mounted the card standalone, which passes even if the card were never added
// to the detail screen.
//
// This test mounts the real PaddockDetailScreen and asserts the entry point is
// present and tappable. It fails if the card is ever dropped from the screen.
import 'dart:async';

import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/gastos/presentation/paddock_expense_summary_card.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/piquetes/presentation/paddock_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
// ignore: depend_on_referenced_packages
import 'package:riverpod/misc.dart' show Override;

const _paddockId = 'pad-1';
const _propertyId = 'prop-1';

final _paddock = Paddock(
  id: _paddockId,
  propertyId: _propertyId,
  name: 'Piquete 2A',
  areaHa: 10,
  uaCapacity: 20,
  createdAt: DateTime(2026, 1, 1),
);

Widget _buildScreen(List<Override> extra) {
  return ProviderScope(
    overrides: [
      paddockByIdProvider.overrideWith((ref, id) async => _paddock),
      loteListByPaddockProvider.overrideWith((ref, id) async => const []),
      ...extra,
    ],
    child: const MaterialApp(
      home: PaddockDetailScreen(paddockId: _paddockId),
    ),
  );
}

void main() {
  group('PaddockDetailScreen — gastos entry point (G-07-1)', () {
    testWidgets(
      'renders the PaddockExpenseSummaryCard so /gastos/:paddockId is '
      'reachable without editing the URL',
      (tester) async {
        await tester.pumpWidget(_buildScreen([
          paddockMonthExpenseTotalProvider
              .overrideWith((ref, id) async => 1240.0),
        ]));
        await tester.pumpAndSettle();

        expect(
          find.byType(PaddockExpenseSummaryCard),
          findsOneWidget,
          reason: 'the Gastos card is the ONLY in-app entry point to '
              '/gastos/:paddockId — without it the screen is URL-only',
        );
        expect(find.text('Gastos'), findsOneWidget);
      },
    );

    testWidgets(
      'the entry point is present even while the month total is still loading',
      (tester) async {
        final never = Completer<double>();
        await tester.pumpWidget(_buildScreen([
          paddockMonthExpenseTotalProvider.overrideWith((ref, id) => never.future),
        ]));
        await tester.pump();

        // A pending total must not hide the entry point — the card is
        // tappable in every async state by design.
        expect(find.byType(PaddockExpenseSummaryCard), findsOneWidget);
        expect(find.text('Gastos'), findsOneWidget);
      },
    );

    testWidgets(
      'the entry point survives a failed month-total load',
      (tester) async {
        await tester.pumpWidget(_buildScreen([
          paddockMonthExpenseTotalProvider
              .overrideWith((ref, id) => Future<double>.error('boom')),
        ]));
        await tester.pumpAndSettle();

        // An error in the total must degrade the figure, never remove the
        // navigation affordance.
        expect(find.byType(PaddockExpenseSummaryCard), findsOneWidget);
        expect(find.text('Gastos'), findsOneWidget);
      },
    );
  });
}
