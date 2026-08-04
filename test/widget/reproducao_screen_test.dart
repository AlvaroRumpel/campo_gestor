// REPR-01, REPR-04 — ReproducaoScreen widget tests (05-UI-SPEC.md E1, E9).
// Covers the two distinct empty states, a populated card list, the
// zero-animal "aguardando DG" card, the veterinarian-only FAB gate, and the
// generic load-failure copy.
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
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

AtfBatch _atf({
  String id = 'atf-1',
  String name = 'ATF Primavera',
  bool active = true,
}) =>
    AtfBatch(
      id: id,
      propertyId: 'prop-1',
      name: name,
      implantationDate: DateTime(2026, 9, 12),
      inseminationDate: DateTime(2026, 9, 22),
      active: active,
      createdAt: DateTime(2026, 9, 12),
    );

AtfSummary _summary({
  required AtfBatch atf,
  int animalCount = 0,
  DgSummary dgSummary = const DgSummary(pregnant: 0, total: 0, pending: 0),
}) =>
    AtfSummary(atf: atf, animalCount: animalCount, dgSummary: dgSummary);

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

final _router = GoRouter(
  routes: [
    GoRoute(path: '/', builder: (context, state) => const ReproducaoScreen()),
    GoRoute(
      path: AppRoutes.atfById,
      builder: (context, state) =>
          Scaffold(body: Text('atf-${state.pathParameters['atfId']}')),
    ),
  ],
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({
  List<AtfSummary>? atfs,
  bool asError = false,
  String role = 'veterinarian',
}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      atfListByPropertyProvider.overrideWith((ref) async {
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
    testWidgets('zero ATFs: renders "Nenhum ATF cadastrado"', (tester) async {
      await tester.pumpWidget(_buildScreen(atfs: const []));
      await tester.pumpAndSettle();

      expect(find.text('Nenhum ATF cadastrado'), findsOneWidget);
      expect(
        find.text('Crie um ATF para iniciar um ciclo reprodutivo.'),
        findsOneWidget,
      );
    });

    testWidgets(
        'only encerrados, toggle off: renders "Nenhum ATF ativo"; flipping the toggle reveals the cards',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [_summary(atf: _atf(active: false))],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Nenhum ATF ativo'), findsOneWidget);
      expect(
        find.text("Ative 'Mostrar encerrados' para ver o histórico."),
        findsOneWidget,
      );
      expect(find.text('ATF Primavera'), findsNothing);

      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(find.text('ATF Primavera'), findsOneWidget);
      expect(find.text('Encerrado'), findsOneWidget);
    });

    testWidgets(
        'populated: renders one card per ATF with the name and a "prenhez" string',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [
            _summary(
              atf: _atf(),
              animalCount: 2,
              dgSummary: const DgSummary(pregnant: 1, total: 2, pending: 0),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('ATF Primavera'), findsOneWidget);
      expect(find.textContaining('prenhez'), findsOneWidget);
    });

    testWidgets(
        'zero-animal ATF: renders the aguardando-DG tail and no "%" string',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          atfs: [_summary(atf: _atf(), animalCount: 0)],
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('— · aguardando DG'), findsOneWidget);
      expect(find.textContaining('%'), findsNothing);
    });

    testWidgets('FAB "Novo ATF" is present for a veterinarian',
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
