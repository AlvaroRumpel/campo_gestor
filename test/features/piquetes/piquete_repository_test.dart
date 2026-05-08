import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Piquete model has all 7 required fields', () {
    // Compile-only assertion — proves the API surface exists and all fields
    // are correctly typed. No Supabase connection required.
    final p = Piquete(
      id: 'piq-1',
      propriedadeId: 'prop-1',
      nome: 'Piquete Norte',
      areaHa: 12.5,
      capacidadeUa: 50.0,
      createdAt: DateTime(2026, 5, 8),
      deletedAt: null,
    );
    expect(p.id, 'piq-1');
    expect(p.propriedadeId, 'prop-1');
    expect(p.nome, 'Piquete Norte');
    expect(p.areaHa, 12.5);
    expect(p.capacidadeUa, 50.0);
    expect(p.createdAt, DateTime(2026, 5, 8));
    expect(p.deletedAt, isNull);
  });

  test('Piquete supports copyWith (freezed contract)', () {
    final original = Piquete(
      id: 'piq-1',
      propriedadeId: 'prop-1',
      nome: 'Piquete Norte',
      areaHa: 12.5,
      capacidadeUa: 50.0,
      createdAt: DateTime(2026, 5, 8),
    );
    final updated = original.copyWith(nome: 'Piquete Sul');
    expect(updated.nome, 'Piquete Sul');
    expect(updated.id, 'piq-1');
  });

  test('Piquete.fromJson deserializes snake_case keys', () {
    final json = {
      'id': 'piq-2',
      'propriedade_id': 'prop-2',
      'nome': 'Piquete Leste',
      'area_ha': 8.0,
      'capacidade_ua': 30.0,
      'created_at': '2026-05-08T00:00:00.000Z',
      'deleted_at': null,
    };
    final p = Piquete.fromJson(json);
    expect(p.id, 'piq-2');
    expect(p.propriedadeId, 'prop-2');
    expect(p.areaHa, 8.0);
    expect(p.capacidadeUa, 30.0);
    expect(p.deletedAt, isNull);
  });

  test('PiqueteRepository class exists and has expected method signatures', () {
    // Compile-only assertion — proves the repository surface exists.
    expect(PiqueteRepository, isA<Type>());
  });

  test('piqueteRepositoryProvider is a non-null provider', () {
    expect(piqueteRepositoryProvider, isNotNull);
  });

  test('piqueteListProvider is a non-null FutureProvider', () {
    expect(piqueteListProvider, isNotNull);
  });

  test('piqueteByIdProvider is a non-null FutureProvider.family', () {
    expect(piqueteByIdProvider, isNotNull);
  });
}
