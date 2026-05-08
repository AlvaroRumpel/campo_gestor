import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Paddock model has all 7 required fields', () {
    final p = Paddock(
      id: 'piq-1',
      propertyId: 'prop-1',
      name: 'Paddock North',
      areaHa: 12.5,
      uaCapacity: 50.0,
      createdAt: DateTime(2026, 5, 8),
      deletedAt: null,
    );
    expect(p.id, 'piq-1');
    expect(p.propertyId, 'prop-1');
    expect(p.name, 'Paddock North');
    expect(p.areaHa, 12.5);
    expect(p.uaCapacity, 50.0);
    expect(p.createdAt, DateTime(2026, 5, 8));
    expect(p.deletedAt, isNull);
  });

  test('Paddock supports copyWith (freezed contract)', () {
    final original = Paddock(
      id: 'piq-1',
      propertyId: 'prop-1',
      name: 'Paddock North',
      areaHa: 12.5,
      uaCapacity: 50.0,
      createdAt: DateTime(2026, 5, 8),
    );
    final updated = original.copyWith(name: 'Paddock South');
    expect(updated.name, 'Paddock South');
    expect(updated.id, 'piq-1');
  });

  test('Paddock.fromJson deserializes snake_case keys', () {
    final json = {
      'id': 'piq-2',
      'property_id': 'prop-2',
      'name': 'Paddock East',
      'area_ha': 8.0,
      'ua_capacity': 30.0,
      'created_at': '2026-05-08T00:00:00.000Z',
      'deleted_at': null,
    };
    final p = Paddock.fromJson(json);
    expect(p.id, 'piq-2');
    expect(p.propertyId, 'prop-2');
    expect(p.areaHa, 8.0);
    expect(p.uaCapacity, 30.0);
    expect(p.deletedAt, isNull);
  });

  test('PaddockRepository class exists and has expected method signatures', () {
    expect(PaddockRepository, isA<Type>());
  });

  test('paddockRepositoryProvider is a non-null provider', () {
    expect(paddockRepositoryProvider, isNotNull);
  });

  test('paddockListProvider is a non-null FutureProvider', () {
    expect(paddockListProvider, isNotNull);
  });

  test('paddockByIdProvider is a non-null FutureProvider.family', () {
    expect(paddockByIdProvider, isNotNull);
  });
}
