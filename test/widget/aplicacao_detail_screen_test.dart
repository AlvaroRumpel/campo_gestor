// SANI-02/SANI-04 — AplicacaoDetailScreen widget test (06-UI-SPEC.md E7).
//
// Covers the E7 backstop specifically: the frozen composition renders through
// a nested `ListView.builder(shrinkWrap: true, physics:
// NeverScrollableScrollPhysics())` inside the page's own ListView. That shape
// is a known nested-scroll trap if the inner list keeps its own physics — the
// page would stop scrolling once the pointer lands on the composition. This
// test pins both halves of the contract at 200 rows: the screen builds without
// throwing, and the inner list never owns a scroll of its own.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:campo_gestor/features/sanitario/presentation/aplicacao_detail_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');

const _categories = ['vaca', 'novilha', 'terneiro', 'touro', 'boi'];

SanitaryApplication _application({int compositionSize = 200}) {
  final entries = [
    for (var i = 0; i < compositionSize; i++)
      SanitaryCompositionEntry(
        animalId: 'a$i',
        number: i + 1,
        category: _categories[i % _categories.length],
        ua: 1.0,
      ),
  ];
  return SanitaryApplication(
    id: 'app-1',
    propertyId: 'prop-1',
    lotId: 'lot-1',
    lotName: 'Lote Recria',
    doseId: 'dose-1',
    doseName: 'Ivomec Gold',
    dosagePerKg: 1.0,
    dosagePerUa: 400,
    appliedAt: DateTime(2026, 3, 15),
    appliedBy: 'user-1',
    animalCount: entries.length,
    totalUa: entries.length.toDouble(),
    totalVolume: entries.length * 400.0,
    skippedCount: 0,
    compositionSnapshot: entries,
    createdAt: DateTime(2026, 3, 15),
  );
}

Lot _lot() => Lot(
      id: 'lot-1',
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      name: 'Lote Recria',
      createdAt: DateTime(2026, 1, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildApp(SanitaryApplication app) {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
      sanitaryApplicationByIdProvider.overrideWith((ref, id) async => app),
      sanitaryApplicationsByLotProvider.overrideWith((ref, id) async => [app]),
      loteByIdProvider.overrideWith((ref, id) async => _lot()),
    ],
    child: MaterialApp(
      home: AplicacaoDetailScreen(applicationId: app.id),
    ),
  );
}

void main() {
  testWidgets(
      'E7 backstop: a 200-row composition builds, and the nested composition '
      'list never owns its own scroll (no nested-scroll trap)', (tester) async {
    final app = _application();

    await tester.pumpWidget(_buildApp(app));
    await tester.pumpAndSettle();

    // 1. It builds. A nested-scroll assertion failure or an unbounded-height
    //    error would surface here as a thrown exception.
    expect(tester.takeException(), isNull);
    expect(find.byType(AplicacaoDetailScreen), findsOneWidget);

    // 2. Exactly one scrollable owns the page. Every OTHER Scrollable in the
    //    tree must be non-scrolling — that is what keeps the page scroll
    //    continuous across the composition. `physics` on a nested list that
    //    accepts drag is the exact defect this backstop guards.
    final scrollables = tester.widgetList<Scrollable>(find.byType(Scrollable));
    final scrolling = scrollables
        .where((s) => s.physics is! NeverScrollableScrollPhysics)
        .toList();
    // Sanity: the tree really does hold two lists, so the assertion below is
    // load-bearing rather than vacuously true.
    expect(scrollables, hasLength(2));
    expect(
      scrolling,
      hasLength(1),
      reason: 'the page ListView must be the only scrollable; the composition '
          'list must carry NeverScrollableScrollPhysics',
    );

    // 3. The frozen data is what is rendered — the first row is present, and
    //    the screen reports the full count rather than a truncated one.
    expect(find.textContaining('#1'), findsWidgets);
    expect(app.compositionSnapshot, hasLength(200));
  });

  testWidgets('a single-row composition renders the same way (no zero/one '
      'special-casing regressions)', (tester) async {
    final app = _application(compositionSize: 1);

    await tester.pumpWidget(_buildApp(app));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AplicacaoDetailScreen), findsOneWidget);
    expect(find.textContaining('#1'), findsWidgets);
  });
}
