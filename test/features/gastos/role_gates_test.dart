// GAST-01 — canManageExpenses: the project's first two-role permission gate
// (D-23). Deliberately diverges from PaddockDetailScreen._canEdit, which is
// vet-only and guards the "Novo lote" FAB; the two gates coexist on purpose.
import 'package:campo_gestor/core/auth/role_gates.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _propA = SelectedProperty(id: 'prop-a', name: 'Fazenda A');
const _propB = SelectedProperty(id: 'prop-b', name: 'Fazenda B');

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
}
