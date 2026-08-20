// ANIM-03, D-04 — AnimalSanitaryHistorySection retry-per-block scope.
// Widget under test is AnimalSanitaryHistorySection mounted directly (not
// the whole ficha) — faster and isolates the D-04 retry behavior. See
// 08-PATTERNS.md §Retry-per-block and 08-03-PLAN.md Task 1.
import 'package:campo_gestor/features/reproducao/data/iatf_model.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:campo_gestor/features/reproducao/presentation/animal_reproductive_history_section.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_repository.dart';
import 'package:campo_gestor/features/sanitario/presentation/sanitary_history_section.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

const _animalId = 'animal-1';

final _application = SanitaryApplication(
  id: 'app-1',
  propertyId: 'prop-1',
  lotId: 'lot-a',
  lotName: 'Lote A',
  paddockId: 'p1',
  paddockName: 'Piquete Norte',
  doseId: 'dose-1',
  doseName: 'Vermífugo X',
  dosagePerKg: 1,
  dosagePerUa: 1,
  appliedAt: DateTime(2026, 1, 10),
  appliedBy: 'vet-1',
  animalCount: 1,
  totalUa: 1,
  totalVolume: 1,
  skippedCount: 0,
  createdAt: DateTime(2026, 1, 10),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

// main.dart wires app-wide auto-retry (G-06-9, providerRetryPolicy) with a
// real 200ms+ backoff on the ProviderScope. Disabling it here isolates the
// manual "Tentar novamente" invalidation under test from that background
// retry racing it on the same clock.
Widget _buildSection({
  required Future<List<SanitaryApplication>> Function(String animalId)
      historyBuilder,
}) {
  return ProviderScope(
    retry: (retryCount, error) => null,
    overrides: [
      sanitaryHistoryByAnimalProvider.overrideWith(
        (ref, id) => historyBuilder(id),
      ),
    ],
    child: const MaterialApp(
      home: Scaffold(
        body: AnimalSanitaryHistorySection(animalId: _animalId),
      ),
    ),
  );
}

void main() {
  group(
    'AnimalSanitaryHistorySection — retry on error (D-04, D-37 boundary)',
    () {
      testWidgets(
          'error state renders the error message AND a "Tentar novamente" button',
          (tester) async {
        await tester.pumpWidget(
          _buildSection(
            historyBuilder: (id) async => throw Exception('boom'),
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico sanitário.'),
          findsOneWidget,
        );
        expect(
          find.widgetWithText(TextButton, 'Tentar novamente'),
          findsOneWidget,
        );
      });

      testWidgets(
          'tapping "Tentar novamente" retries the fetch; rows replace the error on success',
          (tester) async {
        var callCount = 0;
        await tester.pumpWidget(
          _buildSection(
            historyBuilder: (id) async {
              callCount++;
              if (callCount == 1) throw Exception('boom');
              return [_application];
            },
          ),
        );
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico sanitário.'),
          findsOneWidget,
        );

        await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
        await tester.pumpAndSettle();

        expect(
          find.text('Erro ao carregar histórico sanitário.'),
          findsNothing,
        );
        expect(find.textContaining('Vermífugo X'), findsOneWidget);
      });

      testWidgets(
          'retrying the sanitary block does not re-invoke the sibling reproductive provider',
          (tester) async {
        var sanitaryCallCount = 0;
        var reproductiveCallCount = 0;

        final widget = ProviderScope(
          retry: (retryCount, error) => null,
          overrides: [
            sanitaryHistoryByAnimalProvider.overrideWith((ref, id) async {
              sanitaryCallCount++;
              if (sanitaryCallCount == 1) throw Exception('boom');
              return [_application];
            }),
            reproductiveHistoryByAnimalProvider.overrideWith((ref, id) async {
              reproductiveCallCount++;
              return <ReproductiveHistoryEntry>[];
            }),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: Column(
                children: [
                  AnimalSanitaryHistorySection(animalId: _animalId),
                  AnimalReproductiveHistorySection(animalId: _animalId),
                ],
              ),
            ),
          ),
        );

        await tester.pumpWidget(widget);
        await tester.pumpAndSettle();

        expect(reproductiveCallCount, 1);

        await tester.tap(find.widgetWithText(TextButton, 'Tentar novamente'));
        await tester.pumpAndSettle();

        expect(sanitaryCallCount, 2);
        expect(reproductiveCallCount, 1);
      });

      testWidgets(
          'success state (with data) renders no "Tentar novamente" button',
          (tester) async {
        await tester.pumpWidget(
          _buildSection(historyBuilder: (id) async => [_application]),
        );
        await tester.pumpAndSettle();

        expect(
          find.widgetWithText(TextButton, 'Tentar novamente'),
          findsNothing,
        );
      });
    },
  );
}
