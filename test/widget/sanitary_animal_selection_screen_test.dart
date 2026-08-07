// SANI-02/03 — SanitaryAnimalSelectionScreen widget tests (06-UI-SPEC.md E5).
// Covers: default-all seeding with archived animals invisible (D-22),
// live counter/UA updates on deselection, the zero-selected disabled state,
// and the discard-confirm dialog only firing after a real deselection.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:campo_gestor/features/sanitario/presentation/sanitary_animal_selection_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

Animal _animal({
  required String id,
  required int number,
  String category = 'vaca',
  DateTime? deletedAt,
}) =>
    Animal(
      id: id,
      propertyId: 'prop-1',
      lotId: 'lot-a',
      category: category,
      number: number,
      createdAt: DateTime(2026, 1, 1),
      deletedAt: deletedAt,
    );

final _dose = Dose(
  id: 'dose-1',
  propertyId: 'prop-1',
  name: 'Ivomec Gold',
  dosagePerKg: 1.0,
  createdAt: DateTime(2026, 1, 1),
);

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------

Widget _buildScreen({required List<Animal> animals}) {
  return ProviderScope(
    overrides: [
      animalListByLotProvider.overrideWith((ref, id) async => animals),
    ],
    child: MaterialApp(
      home: SanitaryAnimalSelectionScreen(
        lotId: 'lot-a',
        lotName: 'Lote A',
        dose: _dose,
        appliedAt: DateTime(2026, 8, 6),
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('SanitaryAnimalSelectionScreen (SANI-02/03, 06-UI-SPEC E5)', () {
    testWidgets(
        'every active animal arrives pre-checked; an archived animal never appears (D-22)',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
        _animal(id: 'a3', number: 3, deletedAt: DateTime(2026, 1, 2)),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      final tiles = tester.widgetList<CheckboxListTile>(
        find.byType(CheckboxListTile),
      );
      expect(tiles, hasLength(2));
      expect(tiles.every((t) => t.value == true), isTrue);
      expect(find.text('2 de 2 selecionados · 2,0 UA'), findsOneWidget);
    });

    testWidgets('unchecking one animal updates both counter figures live',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('1 de 2 selecionados · 1,0 UA'), findsOneWidget);
    });

    testWidgets(
        'deselecting every animal disables Continuar and shows the minimum-selection message',
        (tester) async {
      final animals = [_animal(id: 'a1', number: 1)];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      expect(find.text('Selecione ao menos 1 animal'), findsOneWidget);
      final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Continuar'),
      );
      expect(btn.onPressed, isNull);
    });

    testWidgets('closing with nothing deselected pops directly, no dialog',
        (tester) async {
      final animals = [_animal(id: 'a1', number: 1)];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Descartar seleção?'), findsNothing);
      expect(find.byType(SanitaryAnimalSelectionScreen), findsNothing);
    });

    testWidgets(
        'closing after a deselection shows the locked discard-confirm dialog; cancelling keeps the screen with the deselection intact',
        (tester) async {
      final animals = [
        _animal(id: 'a1', number: 1),
        _animal(id: 'a2', number: 2),
      ];
      await tester.pumpWidget(_buildScreen(animals: animals));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(CheckboxListTile).first);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      expect(find.text('Descartar seleção?'), findsOneWidget);
      expect(
        find.text('A seleção de animais será perdida.'),
        findsOneWidget,
      );

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(SanitaryAnimalSelectionScreen), findsOneWidget);
      expect(find.text('1 de 2 selecionados · 1,0 UA'), findsOneWidget);
    });
  });
}
