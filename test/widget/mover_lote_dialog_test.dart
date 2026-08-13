// MOV-02 — MoverLoteDialog widget tests.
// Wave 0 stubs. Implementation lands in Plan 04-03 (MoverLoteDialog).
// Decisions enforced: D-07 (paddock picker + info text), D-09 (current paddock excluded), D-10 (SnackBar copy).
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/lotes/presentation/mover_lote_dialog.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class _FakeLoteRepo extends LoteRepository {
  _FakeLoteRepo() : super(SupabaseService());

  String? capturedLotId;
  String? capturedNewPaddockId;

  @override
  Future<void> moveLot({
    required String lotId,
    required String newPaddockId,
  }) async {
    capturedLotId = lotId;
    capturedNewPaddockId = newPaddockId;
  }
}

class _FakePaddockRepo extends PaddockRepository {
  _FakePaddockRepo() : super(SupabaseService());
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _sampleLot = Lot(
  id: 'lot-7',
  propertyId: 'prop-1',
  paddockId: 'pad-current',
  name: 'Lote Bravo',
  createdAt: DateTime(2025, 1, 1),
);
final _padCurrent = Paddock(
  id: 'pad-current',
  propertyId: 'prop-1',
  name: 'Piquete Atual',
  areaHa: 10.0,
  uaCapacity: 20.0,
  createdAt: DateTime(2025, 1, 1),
);
final _padTarget = Paddock(
  id: 'pad-target',
  propertyId: 'prop-1',
  name: 'Piquete Destino',
  areaHa: 15.0,
  uaCapacity: 30.0,
  createdAt: DateTime(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildDialog({Lot? lot, int activeAnimalCount = 5}) {
  return ProviderScope(
    overrides: [
      loteRepositoryProvider.overrideWithValue(_FakeLoteRepo()),
      paddockRepositoryProvider.overrideWithValue(_FakePaddockRepo()),
      paddockListProvider.overrideWith((ref) async => [_padCurrent, _padTarget]),
      loteByIdProvider.overrideWith((ref, id) async => lot ?? _sampleLot),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => Center(
            child: MoverLoteDialog(
              lot: lot ?? _sampleLot,
              activeAnimalCount: activeAnimalCount,
            ),
          ),
        ),
      ),
    ),
  );
}

/// Host that mirrors LoteDetailScreen's "Mover para piquete" flow: opens the
/// dialog via showDialog, shows the parent's SnackBar copy on a non-null pop
/// result, and watches [animalListByPropertyProvider] +
/// [loteListByPropertyProvider] via a probe so their invalidation actually
/// triggers a refetch we can count (IN-01, proves WR-01/WR-02).
Widget _buildHost({
  required _FakeLoteRepo repo,
  required void Function() onAnimalFetch,
  required void Function() onLoteFetch,
  Lot? lot,
  int activeAnimalCount = 5,
}) {
  return ProviderScope(
    overrides: [
      loteRepositoryProvider.overrideWithValue(repo),
      paddockRepositoryProvider.overrideWithValue(_FakePaddockRepo()),
      paddockListProvider.overrideWith((ref) async => [_padCurrent, _padTarget]),
      loteByIdProvider.overrideWith((ref, id) async => lot ?? _sampleLot),
      animalListByPropertyProvider.overrideWith((ref) async {
        onAnimalFetch();
        return <AnimalWithContext>[];
      }),
      loteListByPropertyProvider.overrideWith((ref) async {
        onLoteFetch();
        return <Lot>[];
      }),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Column(
          children: [
            // Probe: forces both providers to have an active listener so
            // ref.invalidate(...) in _submit actually triggers a refetch.
            Consumer(
              builder: (context, ref, _) {
                ref.watch(animalListByPropertyProvider);
                ref.watch(loteListByPropertyProvider);
                return const SizedBox.shrink();
              },
            ),
            Expanded(
              child: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () async {
                      final result = await showAdaptiveForm<Map<String, String>>(
                        context: context,
                        builder: (_) => MoverLoteDialog(
                          lot: lot ?? _sampleLot,
                          activeAnimalCount: activeAnimalCount,
                        ),
                      );
                      if (result != null && context.mounted) {
                        final paddockName = result['paddockName'] ?? '';
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Lote movido para $paddockName'),
                          ),
                        );
                      }
                    },
                    child: const Text('Abrir'),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('MoverLoteDialog (MOV-02)', () {
    testWidgets('renders title containing lot name', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.textContaining('Lote Bravo'), findsWidgets);
    });

    testWidgets('renders info text with active animal count', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.textContaining('5 animais'), findsOneWidget);
    });

    testWidgets('confirm button is disabled until a paddock is selected',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar movimentação'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('excludes the current paddock from the picker', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Piquete Atual'), findsNothing);
      expect(find.text('Piquete Destino'), findsOneWidget);
    });

    testWidgets('renders singular info text when activeAnimalCount is 1 (WR-04)',
        (tester) async {
      await tester.pumpWidget(_buildDialog(activeAnimalCount: 1));
      await tester.pumpAndSettle();

      expect(find.textContaining('1 animal será transferido'), findsOneWidget);
      expect(find.textContaining('1 animais'), findsNothing);
    });

    testWidgets(
        'tapping Confirmar movimentação submits the move, invalidates '
        'animalListByPropertyProvider + loteListByPropertyProvider, and '
        'shows the success SnackBar (IN-01, proves WR-01/WR-02)',
        (tester) async {
      final repo = _FakeLoteRepo();
      var animalFetchCount = 0;
      var loteFetchCount = 0;

      await tester.pumpWidget(_buildHost(
        repo: repo,
        onAnimalFetch: () => animalFetchCount++,
        onLoteFetch: () => loteFetchCount++,
      ));
      await tester.pumpAndSettle();

      expect(animalFetchCount, 1);
      expect(loteFetchCount, 1);

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Piquete Destino'));
      await tester.pump();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar movimentação'),
      );
      await tester.pumpAndSettle();

      expect(repo.capturedLotId, 'lot-7');
      expect(repo.capturedNewPaddockId, 'pad-target');
      expect(find.byType(MoverLoteDialog), findsNothing);
      expect(find.text('Lote movido para Piquete Destino'), findsOneWidget);
      expect(animalFetchCount, 2);
      expect(loteFetchCount, 2);
    });
  });
}
