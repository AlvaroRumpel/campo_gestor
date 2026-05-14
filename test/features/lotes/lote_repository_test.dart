// PROP-03 — Usuário pode criar, editar e listar lotes operacionais de um piquete.
// Wave 0 stubs. Implementations land in Plan 03 (data layer) + Plan 04 (form).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LoteRepository (PROP-03)', () {
    test('fetchLotsByPaddock returns active lots filtered by paddock_id and ordered by name',
        () {}, skip: 'pending Wave 1 implementation');
    test('createLot inserts {property_id, paddock_id, name} and returns Lot',
        () {}, skip: 'pending Wave 1 implementation');
    test('updateLotName updates only the name column',
        () {}, skip: 'pending Wave 1 implementation');
    test('softDeleteLot sets deleted_at = now()',
        () {}, skip: 'pending Wave 1 implementation');
  });
}
