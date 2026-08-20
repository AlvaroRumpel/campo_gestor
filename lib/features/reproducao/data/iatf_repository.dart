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
import 'iatf_model.dart';
import 'dg_record_model.dart';
import 'dg_summary.dart';

/// `yyyy-MM-dd`, no timezone conversion — for date-only fields (WR-03).
/// `.toUtc()` before truncation shifts a local-midnight `DateTime` across
/// the calendar day boundary for any UTC-ahead offset.
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

/// Repository for the reproductive module: IATF batches, memberships, and DG
/// records (REPR-01..05).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (T-3-09). Every mutation except the
/// single-row [createIatf] insert routes through a named `SECURITY DEFINER`
/// RPC, because `animal_iatf_memberships` and `dg_records` carry no direct
/// INSERT/UPDATE/DELETE grant (05-01, RESEARCH Pattern 1).
class IatfRepository {
  IatfRepository(this._service);
  final SupabaseService _service;

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// All IATF batches (active and closed) for [propertyId], ordered by
  /// insemination date descending. The "Mostrar encerrados" toggle filters
  /// in memory (D-03), mirroring AnimaisScreen's archived-filter convention.
  Future<List<IatfBatch>> fetchIatfBatchesByProperty(String propertyId) async {
    final rows = await _service.client
        .from('iatf_batches')
        .select()
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .order('insemination_date', ascending: false);
    return (rows as List)
        .map((r) => IatfBatch.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// A single IATF batch by id. Returns null if soft-deleted or RLS blocks.
  Future<IatfBatch?> fetchIatf(String id) async {
    final row = await _service.client
        .from('iatf_batches')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return IatfBatch.fromJson(row);
  }

  /// Memberships for [iatfBatchId], joined with
  /// `animals(number, category, deleted_at)`, ordered by animal number.
  ///
  /// [activeOnly] defaults to false: per RESEARCH Pattern 3 the DG section
  /// lists every membership row regardless of `active` so a closed IATF still
  /// shows its full roster for correction, while the composition section
  /// passes `activeOnly: true`.
  ///
  /// Returned rows now carry the member animal's archive status
  /// ([IatfMembershipView.animalDeleted], G-05-2). A caller rendering an
  /// editable surface should filter on `animalDeleted`, not on `active` —
  /// filtering on `active` is what would break the D-16 closed-IATF
  /// correction flow, since a closed IATF deactivates every membership
  /// without archiving any animal.
  Future<List<IatfMembershipView>> fetchMemberships(
    String iatfBatchId, {
    bool activeOnly = false,
  }) async {
    var query = _service.client
        .from('animal_iatf_memberships')
        .select(
          'id, iatf_batch_id, animal_id, active, '
          'animals(number, category, deleted_at)',
        )
        .eq('iatf_batch_id', iatfBatchId);
    if (activeOnly) {
      query = query.eq('active', true);
    }
    final rows = await query;
    final views = (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final animalJson = map['animals'] as Map<String, dynamic>;
      return IatfMembershipView(
        membershipId: map['id'] as String,
        iatfBatchId: map['iatf_batch_id'] as String,
        animalId: map['animal_id'] as String,
        active: map['active'] as bool,
        animalNumber: animalJson['number'] as int,
        animalCategory: animalJson['category'] as String,
        animalDeleted: animalJson['deleted_at'] != null,
      );
    }).toList();
    views.sort((a, b) => a.animalNumber.compareTo(b.animalNumber));
    return views;
  }

  /// DG records for [iatfBatchId], ordered by created_at.
  Future<List<DgRecord>> fetchDgRecords(String iatfBatchId) async {
    final rows = await _service.client
        .from('dg_records')
        .select()
        .eq('iatf_batch_id', iatfBatchId)
        .order('created_at');
    return (rows as List)
        .map((r) => DgRecord.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// IATF batches for [propertyId] enriched with active membership count and
  /// [DgSummary] — the IatfCard data source (RESEARCH Pattern 4).
  ///
  /// Follows [fetchLotsWithCountByProperty]'s two-query idiom: one query for
  /// the IATF batches, one for their memberships + DG records, grouped in
  /// Dart. No SQL view.
  Future<List<IatfSummary>> fetchIatfSummaries(String propertyId) async {
    final atfs = await fetchIatfBatchesByProperty(propertyId);
    if (atfs.isEmpty) return const [];
    final iatfIds = atfs.map((a) => a.id).toList();

    final membershipRows = await _service.client
        .from('animal_iatf_memberships')
        .select('iatf_batch_id, active')
        .inFilter('iatf_batch_id', iatfIds);
    final dgRows = await _service.client
        .from('dg_records')
        .select()
        .inFilter('iatf_batch_id', iatfIds);

    final activeCounts = <String, int>{};
    for (final row in membershipRows as List) {
      final map = row as Map<String, dynamic>;
      if (map['active'] != true) continue;
      final iatfId = map['iatf_batch_id'] as String;
      activeCounts[iatfId] = (activeCounts[iatfId] ?? 0) + 1;
    }

    final dgByIatf = <String, List<DgRecord>>{};
    for (final row in dgRows as List) {
      final dg = DgRecord.fromJson(row as Map<String, dynamic>);
      dgByIatf.putIfAbsent(dg.iatfBatchId, () => []).add(dg);
    }

    return atfs.map((iatf) {
      final animalCount = activeCounts[iatf.id] ?? 0;
      final dgSummary = summarizeDg(
        dgByIatf[iatf.id] ?? const [],
        compositionCount: animalCount,
      );
      return IatfSummary(
        iatf: iatf,
        animalCount: animalCount,
        dgSummary: dgSummary,
      );
    }).toList();
  }

  /// Reproductive history for [animalId] — REPR-05.
  ///
  /// One entry per IATF the animal participated in, active or closed alike,
  /// carrying the most recent DG for that IATF (greatest `examDate`, via
  /// [isLaterDg], G-05-4), ordered by insemination date descending (D-14).
  Future<List<ReproductiveHistoryEntry>> fetchReproductiveHistory(
    String animalId,
  ) async {
    final membershipRows = await _service.client
        .from('animal_iatf_memberships')
        .select(
          'iatf_batch_id, iatf_batches(id, name, insemination_date, active, '
          'implantation_date, bull_name)',
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

    // Most-recent DG per IATF (isLaterDg's exam-date tie-breaker, applied
    // per-IATF here, G-05-4). lastDgDate below reads lastDg?.examDate, so the
    // displayed date and the selection rule now finally agree — that
    // mismatch is exactly why this site's bug was invisible before.
    final lastDgByIatf = <String, DgRecord>{};
    for (final dg in dgRecords) {
      final current = lastDgByIatf[dg.iatfBatchId];
      if (current == null || isLaterDg(dg, current)) {
        lastDgByIatf[dg.iatfBatchId] = dg;
      }
    }

    // Full DG list per IATF (D-09/D-10) — additive grouping over the same
    // dgRecords already fetched above, zero extra requests.
    final dgsByIatf = <String, List<DgRecord>>{};
    for (final dg in dgRecords) {
      dgsByIatf.putIfAbsent(dg.iatfBatchId, () => []).add(dg);
    }

    final entries = (membershipRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final iatfJson = map['iatf_batches'] as Map<String, dynamic>;
      final iatfBatchId = iatfJson['id'] as String;
      final lastDg = lastDgByIatf[iatfBatchId];
      // Growable copy — sorting a `const []` in place throws at runtime.
      final iatfDgRecords = List<DgRecord>.from(dgsByIatf[iatfBatchId] ?? const [])
        ..sort((a, b) {
          if (isLaterDg(a, b)) return -1;
          if (isLaterDg(b, a)) return 1;
          return 0;
        });
      return ReproductiveHistoryEntry(
        iatfBatchId: iatfBatchId,
        iatfName: iatfJson['name'] as String,
        inseminationDate:
            DateTime.parse(iatfJson['insemination_date'] as String),
        iatfActive: iatfJson['active'] as bool,
        lastDgResult: lastDg != null ? DgResult.fromDb(lastDg.result) : null,
        lastDgDate: lastDg?.examDate,
        dgRecords: iatfDgRecords,
        bullName: iatfJson['bull_name'] as String?,
        implantationDate:
            DateTime.parse(iatfJson['implantation_date'] as String),
      );
    }).toList();

    entries.sort((a, b) => b.inseminationDate.compareTo(a.inseminationDate));
    return entries;
  }

  /// Eligible animals to add to [iatfBatchId] — the D-06/D-07/D-09 picker
  /// data source.
  ///
  /// Loads the property's active `vaca`/`novilha` animals plus every active
  /// membership in the property. An animal whose active membership already
  /// belongs to [iatfBatchId] is excluded entirely (already composed). An
  /// animal whose active membership belongs to a DIFFERENT IATF is included
  /// with [EligibleAnimal.blockedByIatfName] set, so the UI can render the
  /// D-07 disabled row instead of silently hiding it (RESEARCH Open
  /// Question 2). Every other eligible animal has a null
  /// [EligibleAnimal.blockedByIatfName].
  Future<List<EligibleAnimal>> fetchEligibleAnimalsForIatf({
    required String propertyId,
    required String iatfBatchId,
  }) async {
    final animalRows = await _service.client
        .from('animals')
        .select()
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .inFilter('category', const ['vaca', 'novilha'])
        .order('number');

    final membershipRows = await _service.client
        .from('animal_iatf_memberships')
        .select('animal_id, iatf_batch_id, iatf_batches(name)')
        .eq('property_id', propertyId)
        .eq('active', true);

    final blockingIatfByAnimal = <String, ({String iatfBatchId, String iatfName})>{};
    for (final row in membershipRows as List) {
      final map = row as Map<String, dynamic>;
      final iatfJson = map['iatf_batches'] as Map<String, dynamic>;
      blockingIatfByAnimal[map['animal_id'] as String] = (
        iatfBatchId: map['iatf_batch_id'] as String,
        iatfName: iatfJson['name'] as String,
      );
    }

    final result = <EligibleAnimal>[];
    for (final row in animalRows as List) {
      final animal = Animal.fromJson(row as Map<String, dynamic>);
      final blocking = blockingIatfByAnimal[animal.id];
      if (blocking != null && blocking.iatfBatchId == iatfBatchId) {
        // Already composed in THIS iatf — excluded entirely, no action needed.
        continue;
      }
      result.add(EligibleAnimal(
        animal: animal,
        blockedByIatfName: blocking?.iatfName,
      ));
    }
    return result;
  }

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  /// Create an IATF header (REPR-01, D-01, D-05).
  ///
  /// Direct insert — the `veterinarian_can_insert_atf_batch` RLS policy
  /// covers this single-row, single-entity write. Dates are sent as
  /// date-only ISO strings to avoid timezone-shifted off-by-one days.
  Future<IatfBatch> createIatf({
    required String propertyId,
    required String name,
    required DateTime implantationDate,
    required DateTime inseminationDate,
    String? inseminationTime,
    String? bullAnimalId,
    String? bullName,
    String? observation,
  }) async {
    final row = await _service.client.from('iatf_batches').insert({
      'property_id': propertyId,
      'name': name,
      'implantation_date': _dateOnlyFmt.format(implantationDate),
      'insemination_date': _dateOnlyFmt.format(inseminationDate),
      if (inseminationTime != null) 'insemination_time': inseminationTime,
      if (bullAnimalId != null) 'bull_animal_id': bullAnimalId,
      if (bullName != null) 'bull_name': bullName,
      if (observation != null) 'observation': observation,
    }).select().single();
    return IatfBatch.fromJson(row);
  }

  /// Add [animalIds] to [iatfBatchId] via the `add_animals_to_iatf` RPC
  /// (REPR-02). `p_animal_ids` is a JSON array of uuid strings — the RPC
  /// parameter is `jsonb`, not `uuid[]` (05-RESEARCH assumption A1).
  Future<void> addAnimalsToIatf({
    required String iatfBatchId,
    required List<String> animalIds,
  }) async {
    await _service.client.rpc('add_animals_to_iatf', params: {
      'p_iatf_batch_id': iatfBatchId,
      'p_animal_ids': animalIds,
    });
  }

  /// Remove a single animal from [iatfBatchId] via `remove_animal_from_iatf`
  /// (D-08). Only allowed server-side when the animal has zero DG in this IATF.
  Future<void> removeAnimalFromIatf({
    required String iatfBatchId,
    required String animalId,
  }) async {
    await _service.client.rpc('remove_animal_from_iatf', params: {
      'p_iatf_batch_id': iatfBatchId,
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
    required String iatfBatchId,
    required List<Map<String, dynamic>> records,
  }) async {
    await _service.client.rpc('save_dg_records', params: {
      'p_iatf_batch_id': iatfBatchId,
      'p_records': records,
    });
  }

  /// Manually close [iatfBatchId] via `close_iatf` (D-15, D-16). DG correction
  /// stays possible afterward — this only deactivates memberships going
  /// forward, per RESEARCH Pattern 3.
  Future<void> closeIatf(String iatfBatchId) async {
    await _service.client.rpc('close_iatf', params: {
      'p_iatf_batch_id': iatfBatchId,
    });
  }

  /// Reproductive status per animal for [propertyId] (Task 1, quick task
  /// 260813-p10) — the desktop table + detail panel status source.
  ///
  /// Two queries, mirroring [fetchIatfSummaries]'s idiom: one for active
  /// memberships, one for DG records, both filtered by `property_id`
  /// directly (no per-IATF fan-out). Reduction delegated to
  /// [reduceAnimalReproStatus] — the ONE place the DG tie-break rule lives.
  Future<Map<String, AnimalReproStatus>> fetchAnimalReproStatusByProperty(
    String propertyId,
  ) async {
    final membershipRows = await _service.client
        .from('animal_iatf_memberships')
        .select('animal_id, iatf_batch_id')
        .eq('property_id', propertyId)
        .eq('active', true);
    final activeMemberships = (membershipRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      return (
        animalId: map['animal_id'] as String,
        iatfBatchId: map['iatf_batch_id'] as String,
      );
    }).toList();

    final dgRows = await _service.client
        .from('dg_records')
        .select()
        .eq('property_id', propertyId);
    final dgRecords = (dgRows as List)
        .map((r) => DgRecord.fromJson(r as Map<String, dynamic>))
        .toList();

    return reduceAnimalReproStatus(
      activeMemberships: activeMemberships,
      dgRecords: dgRecords,
    );
  }
}

final iatfRepositoryProvider = Provider<IatfRepository>(
  (ref) => IatfRepository(ref.watch(supabaseServiceProvider)),
);

/// IATF summaries (with animal count + DG summary) for the active property.
///
/// Re-fetches when the active property changes. Returns [] when no property.
final iatfListByPropertyProvider = FutureProvider<List<IatfSummary>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchIatfSummaries(property.id);
});

/// Single IATF batch by id (for IatfDetailScreen).
final iatfByIdProvider = FutureProvider.family<IatfBatch?, String>((ref, id) async {
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchIatf(id);
});

/// Every membership row for an IATF, regardless of active state (DG section).
final iatfMembershipsProvider =
    FutureProvider.family<List<IatfMembershipView>, String>((ref, iatfId) async {
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchMemberships(iatfId);
});

/// Active-only membership rows for an IATF (composition section).
final iatfActiveMembershipsProvider =
    FutureProvider.family<List<IatfMembershipView>, String>((ref, iatfId) async {
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchMemberships(iatfId, activeOnly: true);
});

/// DG records for an IATF, ordered by created_at.
final dgRecordsByIatfProvider =
    FutureProvider.family<List<DgRecord>, String>((ref, iatfId) async {
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchDgRecords(iatfId);
});

/// Reproductive history entries for an animal (REPR-05).
final reproductiveHistoryByAnimalProvider =
    FutureProvider.family<List<ReproductiveHistoryEntry>, String>(
        (ref, animalId) async {
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchReproductiveHistory(animalId);
});

/// Reproductive status per animal for the active property (Task 1, quick
/// task 260813-p10) — the AnimaisTableView + AnimalDetailPanel status
/// source. Resolves the active property internally. Returns {} when none.
final animalReproStatusByPropertyProvider =
    FutureProvider<Map<String, AnimalReproStatus>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const {};
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchAnimalReproStatusByProperty(property.id);
});

/// Eligible animals for the animal-selection picker (D-06/D-07/D-09).
///
/// Resolves the active property internally, keyed by the target IATF id.
final eligibleAnimalsForIatfProvider =
    FutureProvider.family<List<EligibleAnimal>, String>(
        (ref, iatfBatchId) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(iatfRepositoryProvider);
  return repo.fetchEligibleAnimalsForIatf(
    propertyId: property.id,
    iatfBatchId: iatfBatchId,
  );
});

/// IATF batch joined with active animal count and DG summary — the IatfCard
/// data source (RESEARCH Pattern 4). Not a Supabase row by itself.
class IatfSummary {
  const IatfSummary({
    required this.iatf,
    required this.animalCount,
    required this.dgSummary,
  });
  final IatfBatch iatf;
  final int animalCount;
  final DgSummary dgSummary;
}

/// An animal eligible for the IATF picker, annotated with the name of a
/// DIFFERENT active IATF it already belongs to, if any (D-07). Not a Supabase
/// row by itself.
class EligibleAnimal {
  const EligibleAnimal({required this.animal, this.blockedByIatfName});
  final Animal animal;

  /// Non-null when the animal is already in a different active IATF — the UI
  /// renders a disabled row with "já em IATF [nome]" (D-07) rather than
  /// hiding the animal.
  final String? blockedByIatfName;
}
