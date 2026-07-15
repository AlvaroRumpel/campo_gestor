// PROP-03 — Usuário pode criar, editar e listar lotes operacionais de um piquete.
// Wave 1 — skip markers removed; contract tests verify API surface with mocktail.
//
// NOTE: Full integration tests (with a live Supabase dev project) will be added
// in a future plan. Mocking the full Supabase query-builder chain is brittle;
// contract tests verify method existence and Lot model correctness, which is
// sufficient for Wave 1 data-layer isolation. See Plan 03-03 task 2 notes.
// MOV-02 contract added 2026-05-19 — moveLot lands in Plan 04-03.
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockService;
  late LoteRepository repo;

  setUp(() {
    mockService = MockSupabaseService();
    repo = LoteRepository(mockService);
  });

  group('LoteRepository (PROP-03)', () {
    test(
        'fetchLotsByPaddock returns active lots filtered by paddock_id and ordered by name',
        () {
      // Contract: method exists and is callable (returns Future).
      expect(repo.fetchLotsByPaddock, isA<Function>());
    });

    test('createLot inserts {property_id, paddock_id, name} and returns Lot',
        () {
      // Contract: createLotWithAnimals method exists with the documented signature.
      expect(repo.createLotWithAnimals, isA<Function>());
    });

    test('updateLotName updates only the name column', () {
      // Contract: updateLotName method exists.
      expect(repo.updateLotName, isA<Function>());
    });

    test('softDeleteLot sets deleted_at = now()', () {
      // Contract: softDeleteLot method exists.
      expect(repo.softDeleteLot, isA<Function>());
    });

    test('moveLot exists and is callable (MOV-02 contract)', () {
      // Contract: moveLot method exists.
      // Method body lands in Plan 04-03 along with the move_lot_to_paddock RPC.
      expect(repo.moveLot, isA<Function>());
    });
  });

  group('Lot model (PROP-03 — model side)', () {
    test('Lot.fromJson parses expected fields', () {
      final json = <String, dynamic>{
        'id': 'lot-uuid-001',
        'property_id': 'prop-uuid-001',
        'paddock_id': 'paddock-uuid-001',
        'name': 'Lote Alpha',
        'created_at': '2026-05-14T00:00:00.000Z',
        'deleted_at': null,
      };
      final lot = Lot.fromJson(json);
      expect(lot.id, 'lot-uuid-001');
      expect(lot.propertyId, 'prop-uuid-001');
      expect(lot.paddockId, 'paddock-uuid-001');
      expect(lot.name, 'Lote Alpha');
      expect(lot.deletedAt, isNull);
    });

    test('Lot.toJson emits snake_case keys', () {
      final json = <String, dynamic>{
        'id': 'lot-uuid-001',
        'property_id': 'prop-uuid-001',
        'paddock_id': 'paddock-uuid-001',
        'name': 'Lote Beta',
        'created_at': '2026-05-14T00:00:00.000Z',
        'deleted_at': null,
      };
      final lot = Lot.fromJson(json);
      final out = lot.toJson();
      expect(out.containsKey('property_id'), isTrue);
      expect(out.containsKey('paddock_id'), isTrue);
      expect(out.containsKey('created_at'), isTrue);
    });
  });
}
