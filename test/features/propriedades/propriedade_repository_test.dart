// Wave 0 RED stub for PROP-01. Plan 02 makes this green.
import 'package:campo_gestor/features/propriedades/data/propriedade_model.dart';
import 'package:campo_gestor/features/propriedades/data/propriedade_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Propriedade model exposes id, nome, proprietario, createdAt, deletedAt', () {
    final p = Propriedade(
      id: 'p1',
      nome: 'Fazenda Teste',
      proprietario: 'Joao da Silva',
      createdAt: DateTime.parse('2026-05-08T00:00:00Z'),
      deletedAt: null,
    );
    expect(p.id, 'p1');
    expect(p.nome, 'Fazenda Teste');
    expect(p.proprietario, 'Joao da Silva');
    expect(p.deletedAt, isNull);
  });

  test('PropriedadeRepository surface exists', () {
    expect(PropriedadeRepository, isA<Type>());
  });
}
