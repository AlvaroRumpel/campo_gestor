// MOV-01 — MoverAnimalDialog widget tests.
// Wave 0 stubs. Implementation lands in Plan 04-02 (MoverAnimalDialog).
// Decisions enforced: D-02 (lot picker), D-03 (item format), D-05 (SnackBar copy).
import 'package:campo_gestor/core/services/supabase_service.dart';
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

  @override
  Future<Animal> moveAnimal({
    required String id,
    required String newLotId,
  }) async => _sampleAnimal.copyWith(lotId: newLotId);
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

      expect(find.widgetWithText(TextButton, 'Cancelar'), findsOneWidget);
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
  });
}
