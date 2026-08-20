// REPR-01, REPR-04 — ReproducaoScreen widget tests (05-UI-SPEC.md E1, E9).
// Covers the two distinct empty states, a populated card list, the
// zero-animal "aguardando DG" card, the veterinarian-only FAB gate, and the
// generic load-failure copy.
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_model.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:campo_gestor/features/reproducao/presentation/reproducao_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

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

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ReproducaoScreen()),
    GoRoute(
      path: AppRoutes.iatfById,
      builder: (context, state) =>
          Scaffold(body: Text('iatf-${state.pathParameters['iatfId']}')),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  List<IatfSummary>? atfs,
  bool asError = false,
  String role = 'veterinarian',
}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      iatfListByPropertyProvider.overrideWith((ref) async {
        if (asError) throw Exception('boom');
        return atfs ?? const [];
      }),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
    ],
    child: MaterialApp.router(routerConfig: _router),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ReproducaoScreen (REPR-01, REPR-04, 05-UI-SPEC E1/E9)', () {
    testWidgets('zero IATFs: renders "Nenhum IATF cadastrado"', (tester) async {
      await tester.pumpWidget(_buildScreen(atfs: const []));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum IATF cadastrado'), findsOneWidget);
      expect(
        find.text('Crie um IATF para iniciar um ciclo reprodutivo.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'only encerrados, "Ativos" selected: renders "Nenhum IATF ativo"; tapping the "Encerrados" chip reveals the cards',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [_summary(iatf: _atf(active: false))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum IATF ativo'), findsOneWidget);
      expect(
        find.text("Toque em 'Encerrados' para ver o histórico."),
        findsOneWidget,
      );
      expect(find.text('IATF Primavera'), findsNothing);

      // textContaining matches both the chip's Text.rich and its inner
      // RichText — same widget on screen, so tapping the first is enough.
      await tester.tap(find.textContaining('Encerrados').first);
      await tester.pumpAndSettle();

      expect(find.text('IATF Primavera'), findsOneWidget);
      expect(find.text('Encerrado'), findsOneWidget);
    });

    testWidgets(
        'populated: renders one card per IATF with the name and a "prenhez" string',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [
            _summary(
              iatf: _atf(),
              animalCount: 2,
              dgSummary: const DgSummary(pregnant: 1, total: 2, pending: 0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('IATF Primavera'), findsOneWidget);
      expect(find.textContaining('prenhez'), findsOneWidget);
    });

    testWidgets(
        'zero-animal IATF: renders the aguardando-DG tail and no "%" string',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [_summary(iatf: _atf(), animalCount: 0)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('— · aguardando DG'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('FAB "Novo IATF" is present for a veterinarian',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(atfs: const [], role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('FAB is absent for a reader (not disabled — absent)',
        (tester) async {
      await tester.pumpWidget(_buildScreen(atfs: const [], role: 'reader'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });

    testWidgets('error: renders the generic load-failure copy', (
      tester,
    ) async {
      await tester.pumpWidget(_buildScreen(asError: true));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Erro ao carregar. Verifique sua conexão e tente novamente.',
        ),
        findsOneWidget,
      );
    });
  });
}
