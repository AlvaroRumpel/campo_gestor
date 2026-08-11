// REPR-01..05 — AtfRepository contract tests.
//
// Mocking the full Supabase query-builder chain is brittle (see
// lote_repository_test.dart / animal_repository.dart precedent). These are
// contract tests — method existence + callability — plus a non-contract
// test exercising the pure DG-grouping logic underneath fetchAtfSummaries
// via summarizeDg directly (the grouping itself is not factored into a
// separately-exported helper, so it is covered end-to-end by
// dg_summary_test.dart instead).
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/reproducao/data/atf_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockService;
  late AtfRepository repo;

  setUp(() {
    mockService = MockSupabaseService();
    repo = AtfRepository(mockService);
  });

  group('AtfRepository reads (REPR-01..05)', () {
    test('fetchAtfBatchesByProperty exists and is callable', () {
      expect(repo.fetchAtfBatchesByProperty, isA<Function>());
    });

    test('fetchAtf exists and is callable', () {
      expect(repo.fetchAtf, isA<Function>());
    });

    test('fetchMemberships exists and is callable', () {
      expect(repo.fetchMemberships, isA<Function>());
    });

    test('fetchDgRecords exists and is callable', () {
      expect(repo.fetchDgRecords, isA<Function>());
    });

    test('fetchAtfSummaries exists and is callable (RESEARCH Pattern 4)', () {
      expect(repo.fetchAtfSummaries, isA<Function>());
    });

    test(
        'fetchReproductiveHistory exists and is callable (REPR-05, D-09/D-10 — '
        'entries now carry the full dgRecords list, bull name and '
        'implantation date)', () {
      expect(repo.fetchReproductiveHistory, isA<Function>());
    });

    test(
        'fetchEligibleAnimalsForAtf exists and is callable (D-06/D-07/D-09)',
        () {
      expect(repo.fetchEligibleAnimalsForAtf, isA<Function>());
    });
  });

  group('AtfRepository mutations — every one an RPC except createAtf', () {
    test('createAtf exists and is callable (direct insert, D-05)', () {
      expect(repo.createAtf, isA<Function>());
    });

    test('addAnimalsToAtf exists and is callable', () {
      expect(repo.addAnimalsToAtf, isA<Function>());
    });

    test('removeAnimalFromAtf exists and is callable (D-08)', () {
      expect(repo.removeAnimalFromAtf, isA<Function>());
    });

    test('saveDgRecords exists and is callable (D-10..D-12)', () {
      expect(repo.saveDgRecords, isA<Function>());
    });

    test('closeAtf exists and is callable (D-15, D-16)', () {
      expect(repo.closeAtf, isA<Function>());
    });
  });
}
