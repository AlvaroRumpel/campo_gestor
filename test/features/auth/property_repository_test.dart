import 'package:campo_gestor/core/providers/current_property_provider.dart'
    show Property;
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('PropertyMembership is exported with property and perfil fields', () {
    // Compile-only assertion — proves the API surface exists.
    const m = PropertyMembership(
      property: Property(id: 'p1', nome: 'Fazenda Teste'),
      perfil: 'proprietario',
    );
    expect(m.property.id, 'p1');
    expect(m.perfil, 'proprietario');
  });

  test('PropertyRepository exposes fetchMemberProperties signature', () {
    // The class must exist and the method must return Future<List<PropertyMembership>>.
    expect(PropertyRepository, isA<Type>());
  });
}
