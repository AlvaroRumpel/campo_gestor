// ANIM-01 — Animal model serializes/deserializes snake_case JSON.
// Wave 0 stubs. Implementations land in Plan 03 (Animal freezed model).
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Animal model (ANIM-01)', () {
    test('Animal.fromJson parses snake_case payload from Supabase',
        () {}, skip: 'pending Wave 1 implementation');
    test('Animal.toJson emits snake_case keys (lot_id, body_condition, baixa_reason, baixa_date)',
        () {}, skip: 'pending Wave 1 implementation');
    test('Animal supports nullable breed / bodyCondition / observation / baixaReason / baixaDate',
        () {}, skip: 'pending Wave 1 implementation');
    test('Animal.number is int and required',
        () {}, skip: 'pending Wave 1 implementation');
  });
}
