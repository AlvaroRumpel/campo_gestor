// Task 1, quick task 260813-p10 — reduceAnimalReproStatus pure-function
// coverage. Mirrors dg_summary_test.dart's fixture style; no Supabase fake.
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:flutter_test/flutter_test.dart';

DgRecord _dg(
  String animalId,
  String iatfBatchId,
  String result, {
  required DateTime createdAt,
  DateTime? examDate,
}) =>
    DgRecord(
      id: 'dg-$animalId-$iatfBatchId-${createdAt.microsecondsSinceEpoch}',
      propertyId: 'prop-id',
      iatfBatchId: iatfBatchId,
      animalId: animalId,
      result: result,
      examDate: examDate ?? createdAt,
      createdAt: createdAt,
    );

void main() {
  group('reduceAnimalReproStatus (Task 1, 260813-p10)', () {
    test('animal without an active membership is absent from the map', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [],
        dgRecords: [_dg('a1', 'iatf-1', 'pregnant', createdAt: DateTime.utc(2026))],
      );
      expect(result.containsKey('a1'), isFalse);
    });

    test('active membership with no DG in that IATF yields dgPendente', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: const [],
      );
      expect(result['a1'], AnimalReproStatus.dgPendente);
    });

    test('active membership with a pregnant DG yields prenhe', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: [_dg('a1', 'iatf-1', 'pregnant', createdAt: DateTime.utc(2026))],
      );
      expect(result['a1'], AnimalReproStatus.prenhe);
    });

    test('active membership with a not_pregnant DG yields vazia', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: [
          _dg('a1', 'iatf-1', 'not_pregnant', createdAt: DateTime.utc(2026)),
        ],
      );
      expect(result['a1'], AnimalReproStatus.vazia);
    });

    test('active membership with a doubtful DG yields duvidosa', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: [_dg('a1', 'iatf-1', 'doubtful', createdAt: DateTime.utc(2026))],
      );
      expect(result['a1'], AnimalReproStatus.duvidosa);
    });

    test(
        'two DGs in the same IATF: the later isLaterDg winner overrides an '
        'earlier pregnant with a newer not_pregnant', () {
      final earlier = DateTime.utc(2026, 11, 1);
      final later = DateTime.utc(2026, 11, 15);
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: [
          _dg('a1', 'iatf-1', 'pregnant', createdAt: earlier),
          _dg('a1', 'iatf-1', 'not_pregnant', createdAt: later),
        ],
      );
      expect(result['a1'], AnimalReproStatus.vazia);
    });

    test(
        'a DG from a different IATF than the active membership is ignored '
        '(falls back to dgPendente)', () {
      final result = reduceAnimalReproStatus(
        activeMemberships: const [(animalId: 'a1', iatfBatchId: 'iatf-1')],
        dgRecords: [
          _dg('a1', 'iatf-OTHER', 'pregnant', createdAt: DateTime.utc(2026)),
        ],
      );
      expect(result['a1'], AnimalReproStatus.dgPendente);
    });
  });

  group('AnimalReproStatus.label / chipKind (Task 1, 260813-p10)', () {
    test('every status has a distinct pt-BR label', () {
      final labels = AnimalReproStatus.values.map((s) => s.label).toSet();
      expect(labels.length, AnimalReproStatus.values.length);
    });
  });
}
