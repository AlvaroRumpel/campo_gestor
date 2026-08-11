// GAST-01 — canManageExpenses: the project's first two-role permission gate
// (D-23). Deliberately diverges from PaddockDetailScreen._canEdit, which is
// vet-only and guards the "Novo lote" FAB; the two gates coexist on purpose.
import 'package:campo_gestor/core/auth/role_gates.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/gastos/presentation/gastos_screen.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _propA = SelectedProperty(id: 'prop-a', name: 'Fazenda A');
const _propB = SelectedProperty(id: 'prop-b', name: 'Fazenda B');

final _pad = Paddock(
  id: 'pad-1',
  propertyId: 'prop-a',
  name: 'Piquete Norte',
  areaHa: 10,
  uaCapacity: 20,
  createdAt: DateTime(2025, 1, 1),
);

// currentPropertyProvider is NOT overridden directly — with exactly one
// membership, CurrentPropertyNotifier.build() resolves it as the active
// property (same rationale as lote_detail_screen_test.dart).
Widget _buildGastosScreen(String role) {
  return ProviderScope(
    overrides: [
      memberPropertiesProvider.overrideWith(
        (ref) async => [PropertyMembership(property: _propA, role: role)],
      ),
      paddockByIdProvider.overrideWith((ref, id) async => _pad),
      unifiedExpenseListByPaddockProvider.overrideWith(
        (ref, id) async => <ExpenseListItem>[],
      ),
    ],
    child: const MaterialApp(home: GastosScreen(paddockId: 'pad-1')),
  );
}

void main() {
  group('canManageExpenses (GAST-01, D-23)', () {
    test('returns true when the membership role is owner', () {
      final members = [const PropertyMembership(property: _propA, role: 'owner')];
      expect(canManageExpenses(_propA, members), isTrue);
    });

    test('returns true when the membership role is veterinarian', () {
      final members = [
        const PropertyMembership(property: _propA, role: 'veterinarian'),
      ];
      expect(canManageExpenses(_propA, members), isTrue);
    });

    test('returns false when the membership role is reader', () {
      final members = [const PropertyMembership(property: _propA, role: 'reader')];
      expect(canManageExpenses(_propA, members), isFalse);
    });

    test('returns false when selected is null', () {
      final members = [const PropertyMembership(property: _propA, role: 'owner')];
      expect(canManageExpenses(null, members), isFalse);
    });

    test('returns false when members is null', () {
      expect(canManageExpenses(_propA, null), isFalse);
    });

    test(
        'returns false when members is non-empty but holds no membership '
        'for the selected property', () {
      final members = [const PropertyMembership(property: _propB, role: 'owner')];
      expect(canManageExpenses(_propA, members), isFalse);
    });

    test(
        'returns true for owner even when the list also contains a reader '
        'membership in a different property', () {
      final members = [
        const PropertyMembership(property: _propA, role: 'owner'),
        const PropertyMembership(property: _propB, role: 'reader'),
      ];
      expect(canManageExpenses(_propA, members), isTrue);
    });
  });

  // Widget half of D-36's "gate de dois papéis" coverage — closes RESEARCH
  // Pitfall 2's stated warning sign: an owner who cannot see the "Novo
  // gasto" FAB.
  group('GastosScreen FAB role gate (GAST-01, D-23, D-36)', () {
    testWidgets('owner sees the Novo gasto FAB', (tester) async {
      await tester.pumpWidget(_buildGastosScreen('owner'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('veterinarian sees the Novo gasto FAB', (tester) async {
      await tester.pumpWidget(_buildGastosScreen('veterinarian'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsOneWidget);
    });

    testWidgets('reader sees no FAB at all (absent, not disabled)',
        (tester) async {
      await tester.pumpWidget(_buildGastosScreen('reader'));
      await tester.pumpAndSettle();

      expect(find.byType(FloatingActionButton), findsNothing);
    });
  });
}
