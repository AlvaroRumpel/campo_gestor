// MOV-01 — MoverAnimalDialog widget tests.
// Wave 0 stubs. Implementation lands in Plan 04-02 (MoverAnimalDialog).
// Decisions enforced: D-02 (lot picker), D-03 (item format), D-05 (SnackBar copy).
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/mover_animal_dialog.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repositories
// ---------------------------------------------------------------------------

class _FakeAnimalRepo extends AnimalRepository {
  _FakeAnimalRepo() : super(SupabaseService());

  String? capturedId;
  String? capturedNewLotId;

  @override
  Future<Animal> moveAnimal({
    required String id,
    required String newLotId,
  }) async {
    capturedId = id;
    capturedNewLotId = newLotId;
    return _sampleAnimal.copyWith(lotId: newLotId);
  }
}

class _FakeLoteRepo extends LoteRepository {
  _FakeLoteRepo() : super(SupabaseService());
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _sampleAnimal = Animal(
  id: 'animal-7',
  propertyId: 'prop-1',
  lotId: 'lot-current',
  category: 'vaca',
  number: 7,
  createdAt: DateTime(2025, 1, 1),
);
final _sampleLotCurrent = Lot(
  id: 'lot-current',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote Atual',
  createdAt: DateTime(2025, 1, 1),
);
final _sampleLotTarget = Lot(
  id: 'lot-target',
  propertyId: 'prop-1',
  paddockId: 'pad-2',
  name: 'Lote Destino',
  createdAt: DateTime(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildDialog({Animal? animal}) {
  return ProviderScope(
    overrides: [
      animalRepositoryProvider.overrideWithValue(_FakeAnimalRepo()),
      loteRepositoryProvider.overrideWithValue(_FakeLoteRepo()),
      animalByIdProvider.overrideWith((ref, id) async => animal ?? _sampleAnimal),
      animalListByLotProvider.overrideWith((ref, lotId) async => []),
      animalListByPropertyProvider.overrideWith((ref) async => []),
      loteListByPropertyProvider.overrideWith(
        (ref) async => [_sampleLotCurrent, _sampleLotTarget],
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: MoverAnimalDialog(animal: animal ?? _sampleAnimal),
          ),
        ),
      ),
    ),
  );
}

/// Host that mirrors AnimalDetailScreen's onMover: opens the dialog via
/// showAdaptiveForm (the production path), and on a non-null pop result shows
/// the parent's SnackBar copy — so submit-flow tests can assert the whole
/// tap -> confirm -> SnackBar path rather than the dialog in isolation (IN-01).
Widget _buildHost(_FakeAnimalRepo repo, {Animal? animal}) {
  return ProviderScope(
    overrides: [
      animalRepositoryProvider.overrideWithValue(repo),
      loteRepositoryProvider.overrideWithValue(_FakeLoteRepo()),
      animalByIdProvider.overrideWith((ref, id) async => animal ?? _sampleAnimal),
      animalListByLotProvider.overrideWith((ref, lotId) async => []),
      animalListByPropertyProvider.overrideWith((ref) async => []),
      loteListByPropertyProvider.overrideWith(
        (ref) async => [_sampleLotCurrent, _sampleLotTarget],
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: ElevatedButton(
              onPressed: () async {
                final result = await showAdaptiveForm<Map<String, String>>(
                  context: context,
                  builder: (_) =>
                      MoverAnimalDialog(animal: animal ?? _sampleAnimal),
                );
                if (result != null && context.mounted) {
                  final lotName = result['lotName'] ?? '';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Animal movido para $lotName')),
                  );
                }
              },
              child: const Text('Abrir'),
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
  group('MoverAnimalDialog (MOV-01)', () {
    testWidgets('renders title containing animal number', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.textContaining('#7'), findsWidgets);
    });

    testWidgets('renders Cancelar and Confirmar movimentação buttons',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOneWidget);
      expect(
        find.widgetWithText(FilledButton, 'Confirmar movimentação'),
        findsOneWidget,
      );
    });

    testWidgets('confirm button is disabled until a lot is selected',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Confirmar movimentação'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('excludes the current lot from the picker', (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pumpAndSettle();

      expect(find.text('Lote Atual'), findsNothing);
      expect(find.text('Lote Destino'), findsOneWidget);
    });

    testWidgets(
        'tapping Confirmar movimentação submits the move and shows the '
        'success SnackBar (IN-01)', (tester) async {
      final repo = _FakeAnimalRepo();
      await tester.pumpWidget(_buildHost(repo));

      await tester.tap(find.text('Abrir'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Lote Destino'));
      await tester.pump();

      await tester.tap(
        find.widgetWithText(FilledButton, 'Confirmar movimentação'),
      );
      await tester.pumpAndSettle();

      expect(repo.capturedId, 'animal-7');
      expect(repo.capturedNewLotId, 'lot-target');
      expect(find.byType(MoverAnimalDialog), findsNothing);
      expect(find.text('Animal movido para Lote Destino'), findsOneWidget);
    });
  });
}
