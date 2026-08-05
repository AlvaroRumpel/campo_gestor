// ignore_for_file: use_null_aware_elements
// Reason: `use_null_aware_elements` suggests `'key'?: value` syntax which causes
// compiler errors in Dart 3.11 (the feature was proposed but not finalized as
// map-literal syntax). The `if (x != null) 'key': x` pattern is the correct idiom.
// Mirrors animal_repository.dart's identical suppression.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../animais/data/animal_model.dart';
import 'atf_model.dart';
import 'dg_record_model.dart';
import 'dg_summary.dart';

/// `yyyy-MM-dd`, no timezone conversion — for date-only fields (WR-03).
/// `.toUtc()` before truncation shifts a local-midnight `DateTime` across
/// the calendar day boundary for any UTC-ahead offset.
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

/// Repository for the reproductive module: ATF batches, memberships, and DG
/// records (REPR-01..05).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (T-3-09). Every mutation except the
/// single-row [createAtf] insert routes through a named `SECURITY DEFINER`
/// RPC, because `animal_atf_memberships` and `dg_records` carry no direct
/// INSERT/UPDATE/DELETE grant (05-01, RESEARCH Pattern 1).
class AtfRepository {
  AtfRepository(this._service);
  final SupabaseService _service;

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// All ATF batches (active and closed) for [propertyId], ordered by
  /// insemination date descending. The "Mostrar encerrados" toggle filters
  /// in memory (D-03), mirroring AnimaisScreen's archived-filter convention.
  Future<List<AtfBatch>> fetchAtfBatchesByProperty(String propertyId) async {
    final rows = await _service.client
        .from('atf_batches')
        .select()
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .order('insemination_date', ascending: false);
    return (rows as List)
        .map((r) => AtfBatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// A single ATF batch by id. Returns null if soft-deleted or RLS blocks.
  Future<AtfBatch?> fetchAtf(String id) async {
    final row = await _service.client
        .from('atf_batches')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return AtfBatch.fromJson(row);
  }

  /// Memberships for [atfBatchId], joined with `animals(number, category)`,
  /// ordered by animal number.
  ///
  /// [activeOnly] defaults to false: per RESEARCH Pattern 3 the DG section
  /// lists every membership row regardless of `active` so a closed ATF still
  /// shows its full roster for correction, while the composition section
  /// passes `activeOnly: true`.
  Future<List<AtfMembershipView>> fetchMemberships(
    String atfBatchId, {
    bool activeOnly = false,
  }) async {
    var query = _service.client
        .from('animal_atf_memberships')
        .select('id, atf_batch_id, animal_id, active, animals(number, category)')
        .eq('atf_batch_id', atfBatchId);
    if (activeOnly) {
      query = query.eq('active', true);
    }
    final rows = await query;
    final views = (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final animalJson = map['animals'] as Map<String, dynamic>;
      return AtfMembershipView(
        membershipId: map['id'] as String,
        atfBatchId: map['atf_batch_id'] as String,
        animalId: map['animal_id'] as String,
        active: map['active'] as bool,
        animalNumber: animalJson['number'] as int,
        animalCategory: animalJson['category'] as String,
      );
    }).toList();
    views.sort((a, b) => a.animalNumber.compareTo(b.animalNumber));
    return views;
  }

  /// DG records for [atfBatchId], ordered by created_at.
  Future<List<DgRecord>> fetchDgRecords(String atfBatchId) async {
    final rows = await _service.client
        .from('dg_records')
        .select()
        .eq('atf_batch_id', atfBatchId)
        .order('created_at');
    return (rows as List)
        .map((r) => DgRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// ATF batches for [propertyId] enriched with active membership count and
  /// [DgSummary] — the AtfCard data source (RESEARCH Pattern 4).
  ///
  /// Follows [fetchLotsWithCountByProperty]'s two-query idiom: one query for
  /// the ATF batches, one for their memberships + DG records, grouped in
  /// Dart. No SQL view.
  Future<List<AtfSummary>> fetchAtfSummaries(String propertyId) async {
    final atfs = await fetchAtfBatchesByProperty(propertyId);
    if (atfs.isEmpty) return const [];
    final atfIds = atfs.map((a) => a.id).toList();

    final membershipRows = await _service.client
        .from('animal_atf_memberships')
        .select('atf_batch_id, active')
        .inFilter('atf_batch_id', atfIds);
    final dgRows = await _service.client
        .from('dg_records')
        .select()
        .inFilter('atf_batch_id', atfIds);

    final activeCounts = <String, int>{};
    for (final row in membershipRows as List) {
      final map = row as Map<String, dynamic>;
      if (map['active'] != true) continue;
      final atfId = map['atf_batch_id'] as String;
      activeCounts[atfId] = (activeCounts[atfId] ?? 0) + 1;
    }

    final dgByAtf = <String, List<DgRecord>>{};
    for (final row in dgRows as List) {
      final dg = DgRecord.fromJson(row as Map<String, dynamic>);
      dgByAtf.putIfAbsent(dg.atfBatchId, () => []).add(dg);
    }

    return atfs.map((atf) {
      final animalCount = activeCounts[atf.id] ?? 0;
      final dgSummary = summarizeDg(
        dgByAtf[atf.id] ?? const [],
        compositionCount: animalCount,
      );
      return AtfSummary(
        atf: atf,
        animalCount: animalCount,
        dgSummary: dgSummary,
      );
    }).toList();
  }

  /// Reproductive history for [animalId] — REPR-05.
  ///
  /// One entry per ATF the animal participated in, active or closed alike,
  /// carrying the most recent DG for that ATF (greatest `examDate`, via
  /// [isLaterDg], G-05-4), ordered by insemination date descending (D-14).
  Future<List<ReproductiveHistoryEntry>> fetchReproductiveHistory(
    String animalId,
  ) async {
    final membershipRows = await _service.client
        .from('animal_atf_memberships')
        .select(
          'atf_batch_id, atf_batches(id, name, insemination_date, active)',
        )
        .eq('animal_id', animalId);

    final dgRows = await _service.client
        .from('dg_records')
        .select()
        .eq('animal_id', animalId)
        .order('created_at');
    final dgRecords = (dgRows as List)
        .map((r) => DgRecord.fromJson(r as Map<String, dynamic>))
        .toList();

    // Most-recent DG per ATF (isLaterDg's exam-date tie-breaker, applied
    // per-ATF here, G-05-4). lastDgDate below reads lastDg?.examDate, so the
    // displayed date and the selection rule now finally agree — that
    // mismatch is exactly why this site's bug was invisible before.
    final lastDgByAtf = <String, DgRecord>{};
    for (final dg in dgRecords) {
      final current = lastDgByAtf[dg.atfBatchId];
      if (current == null || isLaterDg(dg, current)) {
        lastDgByAtf[dg.atfBatchId] = dg;
      }
    }

    final entries = (membershipRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final atfJson = map['atf_batches'] as Map<String, dynamic>;
      final atfBatchId = atfJson['id'] as String;
      final lastDg = lastDgByAtf[atfBatchId];
      return ReproductiveHistoryEntry(
        atfBatchId: atfBatchId,
        atfName: atfJson['name'] as String,
        inseminationDate:
            DateTime.parse(atfJson['insemination_date'] as String),
        atfActive: atfJson['active'] as bool,
        lastDgResult: lastDg != null ? DgResult.fromDb(lastDg.result) : null,
        lastDgDate: lastDg?.examDate,
      );
    }).toList();

    entries.sort((a, b) => b.inseminationDate.compareTo(a.inseminationDate));
    return entries;
  }

  /// Eligible animals to add to [atfBatchId] — the D-06/D-07/D-09 picker
  /// data source.
  ///
  /// Loads the property's active `vaca`/`novilha` animals plus every active
  /// membership in the property. An animal whose active membership already
  /// belongs to [atfBatchId] is excluded entirely (already composed). An
  /// animal whose active membership belongs to a DIFFERENT ATF is included
  /// with [EligibleAnimal.blockedByAtfName] set, so the UI can render the
  /// D-07 disabled row instead of silently hiding it (RESEARCH Open
  /// Question 2). Every other eligible animal has a null
  /// [EligibleAnimal.blockedByAtfName].
  Future<List<EligibleAnimal>> fetchEligibleAnimalsForAtf({
    required String propertyId,
    required String atfBatchId,
  }) async {
    final animalRows = await _service.client
        .from('animals')
        .select()
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .inFilter('category', const ['vaca', 'novilha'])
        .order('number');

    final membershipRows = await _service.client
        .from('animal_atf_memberships')
        .select('animal_id, atf_batch_id, atf_batches(name)')
        .eq('property_id', propertyId)
        .eq('active', true);

    final blockingAtfByAnimal = <String, ({String atfBatchId, String atfName})>{};
    for (final row in membershipRows as List) {
      final map = row as Map<String, dynamic>;
      final atfJson = map['atf_batches'] as Map<String, dynamic>;
      blockingAtfByAnimal[map['animal_id'] as String] = (
        atfBatchId: map['atf_batch_id'] as String,
        atfName: atfJson['name'] as String,
      );
    }

    final result = <EligibleAnimal>[];
    for (final row in animalRows as List) {
      final animal = Animal.fromJson(row as Map<String, dynamic>);
      final blocking = blockingAtfByAnimal[animal.id];
      if (blocking != null && blocking.atfBatchId == atfBatchId) {
        // Already composed in THIS atf — excluded entirely, no action needed.
        continue;
      }
      result.add(EligibleAnimal(
        animal: animal,
        blockedByAtfName: blocking?.atfName,
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  /// Create an ATF header (REPR-01, D-01, D-05).
  ///
  /// Direct insert — the `veterinarian_can_insert_atf_batch` RLS policy
  /// covers this single-row, single-entity write. Dates are sent as
  /// date-only ISO strings to avoid timezone-shifted off-by-one days.
  Future<AtfBatch> createAtf({
    required String propertyId,
    required String name,
    required DateTime implantationDate,
    required DateTime inseminationDate,
    String? bullAnimalId,
    String? bullName,
    String? observation,
  }) async {
    final row = await _service.client.from('atf_batches').insert({
      'property_id': propertyId,
      'name': name,
      'implantation_date': _dateOnlyFmt.format(implantationDate),
      'insemination_date': _dateOnlyFmt.format(inseminationDate),
      if (bullAnimalId != null) 'bull_animal_id': bullAnimalId,
      if (bullName != null) 'bull_name': bullName,
      if (observation != null) 'observation': observation,
    }).select().single();
    return AtfBatch.fromJson(row);
  }

  /// Add [animalIds] to [atfBatchId] via the `add_animals_to_atf` RPC
  /// (REPR-02). `p_animal_ids` is a JSON array of uuid strings — the RPC
  /// parameter is `jsonb`, not `uuid[]` (05-RESEARCH assumption A1).
  Future<void> addAnimalsToAtf({
    required String atfBatchId,
    required List<String> animalIds,
  }) async {
    await _service.client.rpc('add_animals_to_atf', params: {
      'p_atf_batch_id': atfBatchId,
      'p_animal_ids': animalIds,
    });
  }

  /// Remove a single animal from [atfBatchId] via `remove_animal_from_atf`
  /// (D-08). Only allowed server-side when the animal has zero DG in this ATF.
  Future<void> removeAnimalFromAtf({
    required String atfBatchId,
    required String animalId,
  }) async {
    await _service.client.rpc('remove_animal_from_atf', params: {
      'p_atf_batch_id': atfBatchId,
      'p_animal_id': animalId,
    });
  }

  /// Save a batch of DG records via `save_dg_records` (REPR-03, D-10..D-12).
  ///
  /// Each map in [records] has keys `animal_id`, `result` (one of the three
  /// [DgResult.dbValue] strings), `exam_date` (date-only ISO string), and
  /// optional `observation`. Additive only — this RPC never updates or
  /// deletes an existing `dg_records` row.
  Future<void> saveDgRecords({
    required String atfBatchId,
    required List<Map<String, dynamic>> records,
  }) async {
    await _service.client.rpc('save_dg_records', params: {
      'p_atf_batch_id': atfBatchId,
      'p_records': records,
    });
  }

  /// Manually close [atfBatchId] via `close_atf` (D-15, D-16). DG correction
  /// stays possible afterward — this only deactivates memberships going
  /// forward, per RESEARCH Pattern 3.
  Future<void> closeAtf(String atfBatchId) async {
    await _service.client.rpc('close_atf', params: {
      'p_atf_batch_id': atfBatchId,
    });
  }
}

final atfRepositoryProvider = Provider<AtfRepository>(
  (ref) => AtfRepository(ref.watch(supabaseServiceProvider)),
);

/// ATF summaries (with animal count + DG summary) for the active property.
///
/// Re-fetches when the active property changes. Returns [] when no property.
final atfListByPropertyProvider = FutureProvider<List<AtfSummary>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchAtfSummaries(property.id);
});

/// Single ATF batch by id (for AtfDetailScreen).
final atfByIdProvider = FutureProvider.family<AtfBatch?, String>((ref, id) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchAtf(id);
});

/// Every membership row for an ATF, regardless of active state (DG section).
final atfMembershipsProvider =
    FutureProvider.family<List<AtfMembershipView>, String>((ref, atfId) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchMemberships(atfId);
});

/// Active-only membership rows for an ATF (composition section).
final atfActiveMembershipsProvider =
    FutureProvider.family<List<AtfMembershipView>, String>((ref, atfId) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchMemberships(atfId, activeOnly: true);
});

/// DG records for an ATF, ordered by created_at.
final dgRecordsByAtfProvider =
    FutureProvider.family<List<DgRecord>, String>((ref, atfId) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchDgRecords(atfId);
});

/// Reproductive history entries for an animal (REPR-05).
final reproductiveHistoryByAnimalProvider =
    FutureProvider.family<List<ReproductiveHistoryEntry>, String>(
        (ref, animalId) async {
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchReproductiveHistory(animalId);
});

/// Eligible animals for the animal-selection picker (D-06/D-07/D-09).
///
/// Resolves the active property internally, keyed by the target ATF id.
final eligibleAnimalsForAtfProvider =
    FutureProvider.family<List<EligibleAnimal>, String>(
        (ref, atfBatchId) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(atfRepositoryProvider);
  return repo.fetchEligibleAnimalsForAtf(
    propertyId: property.id,
    atfBatchId: atfBatchId,
  );
});

/// ATF batch joined with active animal count and DG summary — the AtfCard
/// data source (RESEARCH Pattern 4). Not a Supabase row by itself.
class AtfSummary {
  const AtfSummary({
    required this.atf,
    required this.animalCount,
    required this.dgSummary,
  });
  final AtfBatch atf;
  final int animalCount;
  final DgSummary dgSummary;
}

/// An animal eligible for the ATF picker, annotated with the name of a
/// DIFFERENT active ATF it already belongs to, if any (D-07). Not a Supabase
/// row by itself.
class EligibleAnimal {
  const EligibleAnimal({required this.animal, this.blockedByAtfName});
  final Animal animal;

  /// Non-null when the animal is already in a different active ATF — the UI
  /// renders a disabled row with "já em ATF [nome]" (D-07) rather than
  /// hiding the animal.
  final String? blockedByAtfName;
}
