// MEMB-01 — canManageMembers: the project's second two-role permission gate
// (after canManageExpenses, D-23). Locked decision: veterinarian and owner
// invite/remove/change-role; reader only views.
import 'package:campo_gestor/core/auth/role_gates.dart';
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

const _propA = SelectedProperty(id: 'prop-a', name: 'Fazenda A');
const _propB = SelectedProperty(id: 'prop-b', name: 'Fazenda B');

PropertyMembership _membership(SelectedProperty property, String role) =>
    PropertyMembership(property: property, role: role);

void main() {
  group('canManageMembers (MEMB-01)', () {
    test('returns true when the membership role is veterinarian', () {
      expect(
        canManageMembers(_propA, [_membership(_propA, 'veterinarian')]),
        isTrue,
      );
    });

    test('returns true when the membership role is owner', () {
      expect(
        canManageMembers(_propA, [_membership(_propA, 'owner')]),
        isTrue,
      );
    });

    test('returns false when the membership role is reader', () {
      expect(
        canManageMembers(_propA, [_membership(_propA, 'reader')]),
        isFalse,
      );
    });

    test('returns false when current is null and when members is null', () {
      expect(
        canManageMembers(null, [_membership(_propA, 'veterinarian')]),
        isFalse,
      );
      expect(canManageMembers(_propA, null), isFalse);
    });

    test(
        'resolves the role by the active property, not the first membership '
        'in the list', () {
      expect(
        canManageMembers(_propA, [_membership(_propB, 'veterinarian')]),
        isFalse,
      );
    });
  });
}
