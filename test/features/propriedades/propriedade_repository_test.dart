import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Property model exposes id, name, owner, createdAt, deletedAt', () {
    final p = Property(
      id: 'p1',
      name: 'Fazenda Teste',
      owner: 'Joao da Silva',
      createdAt: DateTime.parse('2026-05-08T00:00:00Z'),
      deletedAt: null,
    );
    expect(p.id, 'p1');
    expect(p.name, 'Fazenda Teste');
    expect(p.owner, 'Joao da Silva');
    expect(p.deletedAt, isNull);
  });

  test('Property model allows null owner', () {
    final p = Property(
      id: 'p2',
      name: 'Fazenda Sem Dono',
      createdAt: DateTime.parse('2026-05-08T00:00:00Z'),
    );
    expect(p.owner, isNull);
  });

  test('PropertyRepository surface exists', () {
    expect(PropertyRepository, isA<Type>());
  });
}
