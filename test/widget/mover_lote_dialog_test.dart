// MOV-02 — MoverLoteDialog widget tests.
// Wave 0 stubs. Implementation lands in Plan 04-03 (MoverLoteDialog).
// Decisions enforced: D-07 (paddock picker + info text), D-09 (current paddock excluded), D-10 (SnackBar copy).
import 'package:campo_gestor/core/services/supabase_service.dart';
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

  @override
  Future<void> moveLot({
    required String lotId,
    required String newPaddockId,
  }) async {
    // no-op success
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
  });
}
