// Wave 0 RED stub for PROP-02. Plan 03 makes this green.
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Piquete model exposes id, propriedadeId, nome, areaHa, capacidadeUa, createdAt, deletedAt', () {
    final p = Piquete(
      id: 'pq1',
      propriedadeId: 'prop1',
      nome: 'Piquete A',
      areaHa: 12.5,
      capacidadeUa: 10.0,
      createdAt: DateTime.parse('2026-05-08T00:00:00Z'),
      deletedAt: null,
    );
    expect(p.id, 'pq1');
    expect(p.propriedadeId, 'prop1');
    expect(p.nome, 'Piquete A');
    expect(p.areaHa, 12.5);
    expect(p.capacidadeUa, 10.0);
    expect(p.deletedAt, isNull);
  });

  test('PiqueteRepository surface exists', () {
    expect(PiqueteRepository, isA<Type>());
  });
}
