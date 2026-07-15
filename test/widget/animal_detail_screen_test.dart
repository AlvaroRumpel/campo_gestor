// MOV-01, SC-3 — AnimalDetailScreen: "Mover animal" button gate.
// Wave 0 stubs. AnimalInfoCard.onMover parameter lands in Plan 04-02.
// Asserts: button absent when canEdit=false; present when isActive && canEdit.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/animais/presentation/animal_detail_screen.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _activeAnimal = Animal(
  id: 'animal-9',
  propertyId: 'prop-1',
  lotId: 'lot-A',
  category: 'vaca',
  number: 9,
  createdAt: DateTime(2025, 1, 1),
);
final _archivedAnimal = Animal(
  id: 'animal-10',
  propertyId: 'prop-1',
  lotId: 'lot-A',
  category: 'vaca',
  number: 10,
  createdAt: DateTime(2025, 1, 1),
  deletedAt: DateTime(2025, 6, 1),
  baixaReason: 'sale',
);
const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership = PropertyMembership(property: _prop, role: 'veterinarian');
const _readerMembership = PropertyMembership(property: _prop, role: 'reader');

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------
//
// NOTE: currentPropertyProvider is NOT overridden directly — it is an
// AsyncNotifierProvider whose build() resolves the active property from
// memberPropertiesProvider when there's a single membership. Overriding
// memberPropertiesProvider alone is sufficient and matches production logic.

Widget _buildScreen({required Animal animal, required String role}) {
  final membership = role == 'veterinarian' ? _vetMembership : _readerMembership;
  return ProviderScope(
    overrides: [
      animalByIdProvider.overrideWith((ref, id) async => animal),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: AnimalDetailScreen(animalId: animal.id),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // AnimalInfoCard formats dates with DateFormat(..., 'pt_BR'); locale data
  // must be initialized once before pumping any widget that reaches it.
  setUpAll(() async {
    await initializeDateFormatting('pt_BR', null);
  });

  group('AnimalDetailScreen — Mover animal button (MOV-01, SC-3)', () {
    testWidgets('shows Mover animal button when active && canEdit',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsOneWidget,
      );
    });

    testWidgets('hides Mover animal button when role is reader',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _activeAnimal, role: 'reader'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsNothing,
      );
    });

    testWidgets('hides Mover animal button when animal is archived',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(animal: _archivedAnimal, role: 'veterinarian'),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover animal'),
        findsNothing,
      );
    });
  });
}
