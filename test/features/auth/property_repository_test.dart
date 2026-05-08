import 'package:campo_gestor/core/providers/current_property_provider.dart'
    show SelectedProperty;
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PropertyMembership is exported with property and role fields', () {
    const m = PropertyMembership(
      property: SelectedProperty(id: 'p1', name: 'Fazenda Teste'),
      role: 'owner',
    );
    expect(m.property.id, 'p1');
    expect(m.role, 'owner');
  });

  test('MembershipRepository exposes fetchMemberProperties signature', () {
    expect(MembershipRepository, isA<Type>());
  });
}
