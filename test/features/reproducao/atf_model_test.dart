// REPR-01, REPR-03 — AtfBatch / DgRecord model round-trips + DgResult mapping.
import 'package:campo_gestor/features/reproducao/data/atf_model.dart';
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AtfBatch model (REPR-01)', () {
    final validJson = <String, dynamic>{
      'id': 'atf-uuid-001',
      'property_id': 'prop-uuid-001',
      'name': 'ATF Primavera',
      'implantation_date': '2026-09-12T00:00:00.000Z',
      'insemination_date': '2026-09-22T00:00:00.000Z',
      'bull_animal_id': null,
      'bull_name': 'Touro Nelore 12',
      'observation': null,
      'active': true,
      'created_at': '2026-09-12T12:00:00.000Z',
      'deleted_at': null,
    };

    test('AtfBatch.fromJson parses snake_case payload from Supabase', () {
      final atf = AtfBatch.fromJson(validJson);
      expect(atf.id, 'atf-uuid-001');
      expect(atf.propertyId, 'prop-uuid-001');
      expect(atf.name, 'ATF Primavera');
      expect(atf.implantationDate, DateTime.parse('2026-09-12T00:00:00.000Z'));
      expect(atf.inseminationDate, DateTime.parse('2026-09-22T00:00:00.000Z'));
      expect(atf.bullAnimalId, isNull);
      expect(atf.bullName, 'Touro Nelore 12');
      expect(atf.active, isTrue);
      expect(atf.deletedAt, isNull);
    });

    test('AtfBatch.toJson emits snake_case keys', () {
      final atf = AtfBatch.fromJson(validJson);
      final json = atf.toJson();
      expect(json.containsKey('property_id'), isTrue);
      expect(json.containsKey('implantation_date'), isTrue);
      expect(json.containsKey('insemination_date'), isTrue);
      expect(json.containsKey('bull_animal_id'), isTrue);
      expect(json.containsKey('bull_name'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
      expect(json.containsKey('deleted_at'), isTrue);
    });
  });

  group('DgRecord model (REPR-03)', () {
    final validJson = <String, dynamic>{
      'id': 'dg-uuid-001',
      'property_id': 'prop-uuid-001',
      'atf_batch_id': 'atf-uuid-001',
      'animal_id': 'animal-uuid-001',
      'result': 'pregnant',
      'exam_date': '2026-11-15T00:00:00.000Z',
      'observation': null,
      'created_at': '2026-11-15T09:00:00.000Z',
    };

    test('DgRecord.fromJson parses snake_case payload from Supabase', () {
      final dg = DgRecord.fromJson(validJson);
      expect(dg.id, 'dg-uuid-001');
      expect(dg.propertyId, 'prop-uuid-001');
      expect(dg.atfBatchId, 'atf-uuid-001');
      expect(dg.animalId, 'animal-uuid-001');
      expect(dg.result, 'pregnant');
      expect(dg.examDate, DateTime.parse('2026-11-15T00:00:00.000Z'));
      expect(dg.observation, isNull);
    });

    test('DgRecord.toJson emits snake_case keys', () {
      final dg = DgRecord.fromJson(validJson);
      final json = dg.toJson();
      expect(json.containsKey('atf_batch_id'), isTrue);
      expect(json.containsKey('animal_id'), isTrue);
      expect(json.containsKey('exam_date'), isTrue);
      expect(json.containsKey('created_at'), isTrue);
    });
  });

  group('DgResult (REPR-03)', () {
    test('DgResult.fromDb parses the three DB values', () {
      expect(DgResult.fromDb('pregnant'), DgResult.pregnant);
      expect(DgResult.fromDb('not_pregnant'), DgResult.notPregnant);
      expect(DgResult.fromDb('doubtful'), DgResult.doubtful);
    });

    test('DgResult.fromDb returns null for null and unknown strings', () {
      expect(DgResult.fromDb(null), isNull);
      expect(DgResult.fromDb('unknown_value'), isNull);
    });

    test('DgResult.label is the pt-BR display text', () {
      // Redesign spec vocabulary: Prenhe / Vazia / Duvidosa.
      expect(DgResult.pregnant.label, 'Prenhe');
      expect(DgResult.notPregnant.label, 'Vazia');
      expect(DgResult.doubtful.label, 'Duvidosa');
    });

    test('DgResult.dbValue is the raw DB string', () {
      expect(DgResult.pregnant.dbValue, 'pregnant');
      expect(DgResult.notPregnant.dbValue, 'not_pregnant');
      expect(DgResult.doubtful.dbValue, 'doubtful');
    });
  });
}
