// MOV-02, SC-3 — LoteDetailScreen: "Mover para piquete" button gate.
// Wave 0 stubs. Button + canEdit prop on _LoteHeaderCard lands in Plan 04-03.
// Asserts: button absent when canEdit=false OR activeAnimals=0 OR lot archived.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:campo_gestor/features/lotes/presentation/lote_detail_screen.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

final _lot = Lot(
  id: 'lot-1',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote Alpha',
  createdAt: DateTime(2025, 1, 1),
);
final _archivedLot = Lot(
  id: 'lot-2',
  propertyId: 'prop-1',
  paddockId: 'pad-1',
  name: 'Lote Arquivado',
  createdAt: DateTime(2025, 1, 1),
  deletedAt: DateTime(2025, 6, 1),
);
final _pad = Paddock(
  id: 'pad-1',
  propertyId: 'prop-1',
  name: 'Piquete Norte',
  areaHa: 10,
  uaCapacity: 20,
  createdAt: DateTime(2025, 1, 1),
);
final _activeAnimal = Animal(
  id: 'a1',
  propertyId: 'prop-1',
  lotId: 'lot-1',
  category: 'vaca',
  number: 1,
  createdAt: DateTime(2025, 1, 1),
);
const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vet = PropertyMembership(property: _prop, role: 'veterinarian');
const _reader = PropertyMembership(property: _prop, role: 'reader');

// ---------------------------------------------------------------------------
// Widget builder
// ---------------------------------------------------------------------------
//
// NOTE: currentPropertyProvider is NOT overridden directly — it resolves the
// active property from memberPropertiesProvider when there's a single
// membership (same rationale as animal_detail_screen_test.dart).

Widget _buildScreen({
  required Lot lot,
  required String role,
  required List<Animal> animals,
}) {
  final membership = role == 'veterinarian' ? _vet : _reader;
  return ProviderScope(
    overrides: [
      loteByIdProvider.overrideWith((ref, id) async => lot),
      animalListByLotProvider.overrideWith((ref, lotId) async => animals),
      paddockByIdProvider.overrideWith((ref, id) async => _pad),
      memberPropertiesProvider.overrideWith((ref) async => [membership]),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      home: LoteDetailScreen(loteId: lot.id),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('LoteDetailScreen — Mover para piquete button (MOV-02, SC-3)', () {
    testWidgets(
        'shows Mover para piquete button when active && animals > 0 && veterinarian',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          lot: _lot,
          role: 'veterinarian',
          animals: [_activeAnimal],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover para piquete'),
        findsOneWidget,
      );
    });

    testWidgets('hides Mover para piquete button when role is reader',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(lot: _lot, role: 'reader', animals: [_activeAnimal]),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover para piquete'),
        findsNothing,
      );
    });

    testWidgets('hides Mover para piquete button when lot has 0 active animals',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(lot: _lot, role: 'veterinarian', animals: []),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover para piquete'),
        findsNothing,
      );
    });

    testWidgets('hides Mover para piquete button when lot is archived',
        (tester) async {
      await tester.pumpWidget(
        _buildScreen(
          lot: _archivedLot,
          role: 'veterinarian',
          animals: [_activeAnimal],
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.widgetWithText(OutlinedButton, 'Mover para piquete'),
        findsNothing,
      );
    });
  });
}
