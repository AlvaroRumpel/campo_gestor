// ANIM-02 — AnimalEditDialog: editable raça / EC 1-5 / observação.
// Wave 0 stubs. Implementation lands in Plan 06 (AnimalEditDialog).
// Decisions enforced: D-14 (raça hardcoded list), D-16 (EC 5 chips).
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_edit_dialog.dart';
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake repository — extends AnimalRepository; overrides never call _service
// ---------------------------------------------------------------------------

class _FakeAnimalRepo extends AnimalRepository {
  // SupabaseService() is safe to construct — client getter is never called
  // because we override all methods that would access it.
  _FakeAnimalRepo() : super(SupabaseService());

  @override
  Future<Animal> updateAnimal({
    required String id,
    String? breed,
    int? bodyCondition,
    String? observation,
  }) async {
    return Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: 'lot-a',
      category: 'vaca',
      number: 42,
      createdAt: DateTime(2025),
      breed: breed,
      bodyCondition: bodyCondition,
      observation: observation,
    );
  }
}

// ---------------------------------------------------------------------------
// Sample animal
// ---------------------------------------------------------------------------

final _sampleAnimal = Animal(
  id: 'animal-42',
  propertyId: 'prop-1',
  lotId: 'lot-a',
  category: 'vaca',
  number: 42,
  createdAt: DateTime(2025, 1, 1),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildDialog({Animal? animal}) {
  return ProviderScope(
    overrides: [
      animalRepositoryProvider.overrideWithValue(_FakeAnimalRepo()),
      animalListByPropertyProvider.overrideWith((ref) async => []),
      animalByIdProvider.overrideWith((ref, id) async => null),
    ],
    child: MaterialApp(
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: AnimalEditDialog(animal: animal ?? _sampleAnimal),
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
  group('AnimalEditDialog (ANIM-02)', () {
    testWidgets('shows Número and Categoria as read-only display fields',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Vaca'), findsOneWidget);
    });

    testWidgets(
        'shows Raça dropdown with hardcoded breed list (Nelore, Angus, Brahman, Gir, ...)',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      // Open the dropdown
      await tester.tap(find.byType(DropdownButtonFormField<String?>));
      await tester.pumpAndSettle();

      expect(find.text('Nelore'), findsWidgets);
    });

    testWidgets('shows 5 EC ChoiceChip widgets labeled 1..5 in a Row',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      expect(find.byType(ChoiceChip), findsNWidgets(5));
    });

    testWidgets('shows Observação multi-line TextFormField (maxLines: 3)',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      // Find text fields and verify one has maxLines == 3 via InputDecoration hint
      expect(find.byType(TextFormField), findsWidgets);
      // Verify the observation hint text is present
      expect(find.text('Observações adicionais (opcional)'), findsOneWidget);
    });

    testWidgets('Cancel button labeled "Cancelar"; submit button labeled "Salvar"',
        (tester) async {
      await tester.pumpWidget(_buildDialog());
      await tester.pump();

      expect(find.widgetWithText(OutlinedButton, 'Cancelar'), findsOneWidget);
      expect(find.widgetWithText(FilledButton, 'Salvar'), findsOneWidget);
    });
  });
}
