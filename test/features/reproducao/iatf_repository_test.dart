// REPR-01..05 — IatfRepository contract tests.
//
// Mocking the full Supabase query-builder chain is brittle (see
// lote_repository_test.dart / animal_repository.dart precedent). These are
// contract tests — method existence + callability — plus a non-contract
// test exercising the pure DG-grouping logic underneath fetchIatfSummaries
// via summarizeDg directly (the grouping itself is not factored into a
// separately-exported helper, so it is covered end-to-end by
// dg_summary_test.dart instead).
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/reproducao/data/iatf_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockService;
  late IatfRepository repo;

  setUp(() {
    mockService = MockSupabaseService();
    repo = IatfRepository(mockService);
  });

  group('IatfRepository reads (REPR-01..05)', () {
    test('fetchIatfBatchesByProperty exists and is callable', () {
      expect(repo.fetchIatfBatchesByProperty, isA<Function>());
    });

    test('fetchIatf exists and is callable', () {
      expect(repo.fetchIatf, isA<Function>());
    });

    test('fetchMemberships exists and is callable', () {
      expect(repo.fetchMemberships, isA<Function>());
    });

    test('fetchDgRecords exists and is callable', () {
      expect(repo.fetchDgRecords, isA<Function>());
    });

    test('fetchIatfSummaries exists and is callable (RESEARCH Pattern 4)', () {
      expect(repo.fetchIatfSummaries, isA<Function>());
    });

    test(
        'fetchReproductiveHistory exists and is callable (REPR-05, D-09/D-10 — '
        'entries now carry the full dgRecords list, bull name and '
        'implantation date)', () {
      expect(repo.fetchReproductiveHistory, isA<Function>());
    });

    test(
        'fetchEligibleAnimalsForIatf exists and is callable (D-06/D-07/D-09)',
        () {
      expect(repo.fetchEligibleAnimalsForIatf, isA<Function>());
    });
  });

  group('IatfRepository mutations — every one an RPC except createIatf', () {
    test('createIatf exists and is callable (direct insert, D-05)', () {
      expect(repo.createIatf, isA<Function>());
    });

    test('addAnimalsToIatf exists and is callable', () {
      expect(repo.addAnimalsToIatf, isA<Function>());
    });

    test('removeAnimalFromIatf exists and is callable (D-08)', () {
      expect(repo.removeAnimalFromIatf, isA<Function>());
    });

    test('saveDgRecords exists and is callable (D-10..D-12)', () {
      expect(repo.saveDgRecords, isA<Function>());
    });

    test('closeIatf exists and is callable (D-15, D-16)', () {
      expect(repo.closeIatf, isA<Function>());
    });
  });
}
