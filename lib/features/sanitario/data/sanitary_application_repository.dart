// ignore_for_file: use_null_aware_elements
// Reason: `use_null_aware_elements` suggests `'key'?: value` syntax which
// causes compiler errors in Dart 3.11 (the feature was proposed but not
// finalized as map-literal syntax). The `if (x != null) 'key': x` pattern is
// the correct idiom. Mirrors atf_repository.dart's identical suppression.
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'sanitary_application_model.dart';

/// `yyyy-MM-dd`, no timezone conversion — for date-only fields (WR-03).
/// `.toUtc()` before truncation shifts a local-midnight `DateTime` across
/// the calendar day boundary for any UTC-ahead offset.
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

/// Repository for sanitary applications (SANI-02..05): both freeze RPCs plus
/// every read shape and the D-34 duplicate-detection query.
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (T-3-09). `sanitary_applications` has no
/// direct INSERT/UPDATE/DELETE grant; every mutation routes through the two
/// SECURITY DEFINER RPCs below (D-01, Pattern 2).
class SanitaryApplicationRepository {
  SanitaryApplicationRepository(this._service);
  final SupabaseService _service;

  // ---------------------------------------------------------------------
  // Reads
  // ---------------------------------------------------------------------

  /// All applications (registrations and reversals alike) for [propertyId],
  /// newest applied date first, creation time as the tie-breaker (D-06).
  /// "Mostrar estornadas" filters in memory via `visibleApplications`,
  /// mirroring `AtfRepository`'s archived-toggle idiom.
  Future<List<SanitaryApplication>> fetchApplicationsByProperty(
    String propertyId,
  ) async {
    final rows = await _service.client
        .from('sanitary_applications')
        .select()
        .eq('property_id', propertyId)
        .order('applied_at', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SanitaryApplication.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Applications for a single lot (SANI-04), same ordering as
  /// [fetchApplicationsByProperty].
  Future<List<SanitaryApplication>> fetchApplicationsByLot(String lotId) async {
    final rows = await _service.client
        .from('sanitary_applications')
        .select()
        .eq('lot_id', lotId)
        .order('applied_at', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SanitaryApplication.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// A single application by id (AplicacaoDetailScreen). Null when the row
  /// doesn't exist or RLS blocks it.
  Future<SanitaryApplication?> fetchApplication(String id) async {
    final row = await _service.client
        .from('sanitary_applications')
        .select()
        .eq('id', id)
        .order('applied_at', ascending: false)
        .order('created_at', ascending: false)
        .maybeSingle();
    if (row == null) return null;
    return SanitaryApplication.fromJson(row);
  }

  /// An animal's sanitary history (SANI-05, D-37) via jsonb containment on
  /// `composition_snapshot` (D-38, backed by
  /// `sanitary_applications_composition_gin_idx`) — resolves even after the
  /// animal has since moved lots, because the row's `lotName` is the one
  /// frozen at application time (D-04).
  Future<List<SanitaryApplication>> fetchSanitaryHistoryByAnimal(
    String animalId,
  ) async {
    // G-06-9: postgrest-dart's .contains() only JSON-encodes a String value;
    // a Dart List is stringified into a (non-JSON) Postgres array literal
    // instead. jsonEncode here forwards a String, so this hits the correct
    // branch and Postgres receives `cs.[{"animal_id":"<uuid>"}]`.
    final rows = await _service.client
        .from('sanitary_applications')
        .select()
        .contains(
          'composition_snapshot',
          jsonEncode([
            {'animal_id': animalId},
          ]),
        )
        .order('applied_at', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => SanitaryApplication.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// The id of a non-reversal application with the same [lotId], [doseId]
  /// and calendar [appliedAt] date, or null — the D-34 duplicate-detection
  /// query. Same lot, same dose, same day is the whole definition of
  /// "identical" here: no time window, because a window would either miss a
  /// same-day repeat dose or fire spuriously. Resolved client-side; the RPC
  /// never blocks on this.
  Future<String?> findRecentIdenticalApplication({
    required String lotId,
    required String doseId,
    required DateTime appliedAt,
  }) async {
    final row = await _service.client
        .from('sanitary_applications')
        .select('id')
        .eq('lot_id', lotId)
        .eq('dose_id', doseId)
        .eq('applied_at', _dateOnlyFmt.format(appliedAt))
        .isFilter('reverses_application_id', null)
        .limit(1)
        .maybeSingle();
    return row?['id'] as String?;
  }

  // ---------------------------------------------------------------------
  // Mutations
  // ---------------------------------------------------------------------

  /// Freezes a new registration via `register_sanitary_application`
  /// (SANI-02). [animalIds] is sent as a plain list and the client
  /// serializes it into the RPC's jsonb parameter — the same idiom
  /// `AtfRepository.addAnimalsToAtf` uses. [appliedAt] is sent date-only
  /// (WR-03 lesson). Does not catch — the calling widget maps any error via
  /// `asSanitaryException` with its own surface-specific fallback message
  /// (D-35), since the right generic-failure sentence differs per screen.
  Future<SanitaryApplication> registerApplication({
    required String lotId,
    required String doseId,
    required DateTime appliedAt,
    required List<String> animalIds,
    String? notes,
  }) async {
    final params = {
      'p_lot_id': lotId,
      'p_dose_id': doseId,
      'p_applied_at': _dateOnlyFmt.format(appliedAt),
      'p_animal_ids': animalIds,
      if (notes != null) 'p_notes': notes,
    };
    final result = await _service.client.rpc(
      'register_sanitary_application',
      params: params,
    );
    return SanitaryApplication.fromJson(result as Map<String, dynamic>);
  }

  /// Freezes a reversal row via `reverse_sanitary_application`
  /// (D-27..D-31). Does not catch — see [registerApplication].
  Future<SanitaryApplication> reverseApplication({
    required String applicationId,
    required String reason,
  }) async {
    final params = {'p_application_id': applicationId, 'p_reason': reason};
    final result = await _service.client.rpc(
      'reverse_sanitary_application',
      params: params,
    );
    return SanitaryApplication.fromJson(result as Map<String, dynamic>);
  }
}

final sanitaryApplicationRepositoryProvider =
    Provider<SanitaryApplicationRepository>(
      (ref) =>
          SanitaryApplicationRepository(ref.watch(supabaseServiceProvider)),
    );

/// All applications for the active property, newest first. Re-fetches when
/// the active property changes. Returns [] when no property is selected.
final sanitaryApplicationListByPropertyProvider =
    FutureProvider<List<SanitaryApplication>>((ref) async {
      final property = await ref.watch(currentPropertyProvider.future);
      if (property == null) return const [];
      final repo = ref.watch(sanitaryApplicationRepositoryProvider);
      return repo.fetchApplicationsByProperty(property.id);
    });

/// Applications for a single lot (SANI-04).
final sanitaryApplicationsByLotProvider =
    FutureProvider.family<List<SanitaryApplication>, String>((
      ref,
      lotId,
    ) async {
      final repo = ref.watch(sanitaryApplicationRepositoryProvider);
      return repo.fetchApplicationsByLot(lotId);
    });

/// A single application by id (AplicacaoDetailScreen).
final sanitaryApplicationByIdProvider =
    FutureProvider.family<SanitaryApplication?, String>((ref, id) async {
      final repo = ref.watch(sanitaryApplicationRepositoryProvider);
      return repo.fetchApplication(id);
    });

/// An animal's sanitary history, newest first (SANI-05) — the exact D-37
/// contract Phase 8 imports unchanged.
final sanitaryHistoryByAnimalProvider =
    FutureProvider.family<List<SanitaryApplication>, String>((
      ref,
      animalId,
    ) async {
      final repo = ref.watch(sanitaryApplicationRepositoryProvider);
      return repo.fetchSanitaryHistoryByAnimal(animalId);
    });
