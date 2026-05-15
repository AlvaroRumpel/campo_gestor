// ANIM-01 — Animal model serializes/deserializes snake_case JSON.
// Wave 1 — skip markers removed; tests pass with freezed + json_serializable model.
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Animal model (ANIM-01)', () {
    final validJson = <String, dynamic>{
      'id': 'a1b2c3d4-0000-0000-0000-000000000001',
      'property_id': 'p1b2c3d4-0000-0000-0000-000000000002',
      'lot_id': 'l1b2c3d4-0000-0000-0000-000000000003',
      'category': 'vaca',
      'number': 42,
      'breed': 'Nelore',
      'body_condition': 3,
      'observation': null,
      'baixa_reason': null,
      'baixa_date': null,
      'created_at': '2026-05-14T12:00:00.000Z',
      'deleted_at': null,
    };

    test('Animal.fromJson parses snake_case payload from Supabase', () {
      final animal = Animal.fromJson(validJson);
      expect(animal.id, 'a1b2c3d4-0000-0000-0000-000000000001');
      expect(animal.propertyId, 'p1b2c3d4-0000-0000-0000-000000000002');
      expect(animal.lotId, 'l1b2c3d4-0000-0000-0000-000000000003');
      expect(animal.category, 'vaca');
      expect(animal.number, 42);
      expect(animal.breed, 'Nelore');
      expect(animal.bodyCondition, 3);
      expect(animal.observation, isNull);
      expect(animal.baixaReason, isNull);
      expect(animal.baixaDate, isNull);
      expect(animal.deletedAt, isNull);
    });

    test(
        'Animal.toJson emits snake_case keys (lot_id, body_condition, baixa_reason, baixa_date)',
        () {
      final animal = Animal.fromJson(validJson);
      final json = animal.toJson();
      expect(json.containsKey('lot_id'), isTrue);
      expect(json.containsKey('body_condition'), isTrue);
      expect(json.containsKey('baixa_reason'), isTrue);
      expect(json.containsKey('baixa_date'), isTrue);
      expect(json['lot_id'], 'l1b2c3d4-0000-0000-0000-000000000003');
      expect(json['body_condition'], 3);
    });

    test(
        'Animal supports nullable breed / bodyCondition / observation / baixaReason / baixaDate',
        () {
      final animal = Animal(
        id: 'test-id',
        propertyId: 'prop-id',
        lotId: 'lot-id',
        category: 'terneiro',
        number: 1,
        createdAt: DateTime.utc(2026),
      );
      expect(animal.breed, isNull);
      expect(animal.bodyCondition, isNull);
      expect(animal.observation, isNull);
      expect(animal.baixaReason, isNull);
      expect(animal.baixaDate, isNull);
    });

    test('Animal.number is int and required', () {
      final animal = Animal(
        id: 'test-id',
        propertyId: 'prop-id',
        lotId: 'lot-id',
        category: 'touro',
        number: 99,
        createdAt: DateTime.utc(2026),
      );
      expect(animal.number, isA<int>());
      expect(animal.number, 99);
    });
  });
}
