// REPR-04 — % prenhez formula. D-12 (most-recent DG wins), D-17 (duvidosa
// counts in denominator not numerator), D-18 (display format), D-20 (baixa'd
// animal with a DG stays counted). See 05-UI-SPEC.md `## Copywriting Contract`
// and section E10 for the exact display strings this file asserts.
import 'package:campo_gestor/features/reproducao/data/dg_record_model.dart';
import 'package:campo_gestor/features/reproducao/data/dg_summary.dart';
import 'package:flutter_test/flutter_test.dart';

DgRecord _dg(
  String animalId,
  String result, {
  required DateTime createdAt,
  DateTime? examDate,
}) =>
    DgRecord(
      id: 'dg-$animalId-${createdAt.microsecondsSinceEpoch}',
      propertyId: 'prop-id',
      atfBatchId: 'atf-id',
      animalId: animalId,
      result: result,
      examDate: examDate ?? createdAt,
      createdAt: createdAt,
    );

void main() {
  group('summarizeDg (REPR-04)', () {
    test('empty list with compositionCount 10 yields total 0, pending 10, '
        'percent null', () {
      final summary = summarizeDg([], compositionCount: 10);
      expect(summary.total, 0);
      expect(summary.pregnant, 0);
      expect(summary.pending, 10);
      expect(summary.percent, isNull);
    });

    test(
        'two DG records for the same animal collapse to one — the later '
        'examDate wins (D-12, G-05-4)', () {
      final earlier = DateTime.utc(2026, 11, 1);
      final later = DateTime.utc(2026, 11, 15);
      final records = [
        _dg('a1', 'doubtful', createdAt: earlier),
        _dg('a1', 'pregnant', createdAt: later),
      ];
      final summary = summarizeDg(records, compositionCount: 1);
      expect(summary.total, 1);
      expect(summary.pregnant, 1); // later record (pregnant) wins
    });

    test('a doubtful most-recent DG increments total but not pregnant (D-17)',
        () {
      final records = [_dg('a1', 'doubtful', createdAt: DateTime.utc(2026))];
      final summary = summarizeDg(records, compositionCount: 1);
      expect(summary.total, 1);
      expect(summary.pregnant, 0);
    });

    test('a not_pregnant most-recent DG increments total but not pregnant',
        () {
      final records = [
        _dg('a1', 'not_pregnant', createdAt: DateTime.utc(2026)),
      ];
      final summary = summarizeDg(records, compositionCount: 1);
      expect(summary.total, 1);
      expect(summary.pregnant, 0);
    });

    test('31 pregnant out of 50 distinct animals with DGs returns percent 62',
        () {
      final base = DateTime.utc(2026);
      final records = [
        for (var i = 0; i < 31; i++)
          _dg('preg-$i', 'pregnant', createdAt: base),
        for (var i = 0; i < 19; i++)
          _dg('notpreg-$i', 'not_pregnant', createdAt: base),
      ];
      final summary = summarizeDg(records, compositionCount: 50);
      expect(summary.total, 50);
      expect(summary.pregnant, 31);
      expect(summary.percent, 62);
    });

    test(
        'a DG record whose animal is no longer in the composition still '
        'counts toward total and pregnant (D-20)', () {
      final records = [_dg('baixado', 'pregnant', createdAt: DateTime.utc(2026))];
      // compositionCount 0 — the animal was baixa'd and removed from composition.
      final summary = summarizeDg(records, compositionCount: 0);
      expect(summary.total, 1);
      expect(summary.pregnant, 1);
      expect(summary.pending, 0); // clamped, never negative
    });

    test(
        'summarizeDg regression: greater-examDate record wins even when it '
        'was inserted first (G-05-4)', () {
      final recordA = _dg(
        'a1',
        'pregnant',
        examDate: DateTime.utc(2026, 11, 15),
        createdAt: DateTime.utc(2026, 11, 16),
      );
      final recordB = _dg(
        'a1',
        'not_pregnant',
        examDate: DateTime.utc(2026, 11, 10),
        createdAt: DateTime.utc(2026, 11, 20),
      );
      final summary = summarizeDg([recordA, recordB], compositionCount: 1);
      expect(summary.total, 1);
      expect(summary.pregnant, 1); // recordA wins on examDate, not createdAt
    });
  });

  group('isLaterDg (A-DG-ORDER, G-05-4)', () {
    test('greater examDate wins regardless of insert order', () {
      final candidate = _dg(
        'a1',
        'pregnant',
        examDate: DateTime.utc(2026, 11, 15),
        createdAt: DateTime.utc(2026, 11, 1),
      );
      final current = _dg(
        'a1',
        'not_pregnant',
        examDate: DateTime.utc(2026, 11, 10),
        createdAt: DateTime.utc(2026, 11, 20),
      );
      expect(isLaterDg(candidate, current), isTrue);
    });

    test('equal examDate falls back to the greater createdAt', () {
      final sameExam = DateTime.utc(2026, 11, 15);
      final candidate = _dg(
        'a1',
        'pregnant',
        examDate: sameExam,
        createdAt: DateTime.utc(2026, 11, 16),
      );
      final current = _dg(
        'a1',
        'not_pregnant',
        examDate: sameExam,
        createdAt: DateTime.utc(2026, 11, 10),
      );
      expect(isLaterDg(candidate, current), isTrue);
    });

    test('is antisymmetric on a strict pair', () {
      final earlier = _dg(
        'a1',
        'doubtful',
        examDate: DateTime.utc(2026, 11, 1),
        createdAt: DateTime.utc(2026, 11, 1),
      );
      final later = _dg(
        'a1',
        'pregnant',
        examDate: DateTime.utc(2026, 11, 15),
        createdAt: DateTime.utc(2026, 11, 15),
      );
      expect(isLaterDg(later, earlier), isTrue);
      expect(isLaterDg(earlier, later), isFalse);
    });
  });

  group('formatPrenhez (REPR-04, D-18, E10)', () {
    test('zero-DG summary returns the aguardando-DG placeholder', () {
      final summary = summarizeDg([], compositionCount: 5);
      expect(formatPrenhez(summary), '— · aguardando DG');
    });

    test('partial summary uses singular pendente at pending == 1', () {
      final records = [
        for (var i = 0; i < 4; i++)
          _dg('a$i', 'pregnant', createdAt: DateTime.utc(2026)),
      ];
      final summary = summarizeDg(records, compositionCount: 5);
      expect(summary.pending, 1);
      expect(formatPrenhez(summary), '100% prenhez (4/4 DG · 1 pendente)');
    });

    test('partial summary uses plural pendentes at pending == 2', () {
      final records = [
        for (var i = 0; i < 3; i++)
          _dg('a$i', 'pregnant', createdAt: DateTime.utc(2026)),
      ];
      final summary = summarizeDg(records, compositionCount: 5);
      expect(summary.pending, 2);
      expect(formatPrenhez(summary), '100% prenhez (3/3 DG · 2 pendentes)');
    });

    test('partial summary matches the UI-SPEC example: 62% (31/50 · 12)', () {
      final base = DateTime.utc(2026);
      final records = [
        for (var i = 0; i < 31; i++)
          _dg('preg-$i', 'pregnant', createdAt: base),
        for (var i = 0; i < 19; i++)
          _dg('notpreg-$i', 'not_pregnant', createdAt: base),
      ];
      // 50 distinct animals with a DG (31 pregnant), 12 still pending —
      // matches 05-UI-SPEC.md's exact example string.
      final summary = summarizeDg(records, compositionCount: 62);
      expect(formatPrenhez(summary), '62% prenhez (31/50 DG · 12 pendentes)');
    });

    test('complete summary drops the pendentes clause entirely', () {
      final records = [
        for (var i = 0; i < 2; i++)
          _dg('a$i', 'pregnant', createdAt: DateTime.utc(2026)),
      ];
      final summary = summarizeDg(records, compositionCount: 2);
      expect(summary.pending, 0);
      expect(formatPrenhez(summary), '100% prenhez (2/2 DG)');
    });
  });
}
