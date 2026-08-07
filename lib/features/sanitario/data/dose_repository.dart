import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'dose_model.dart';

/// CRUD repository for doses (SANI-01).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (T-3-09). Dose writes go through the
/// `doses` table endpoint directly, not an RPC: single-row single-entity
/// writes are fully covered by the `veterinarian_can_insert_dose` /
/// `veterinarian_can_update_active_dose` RLS policies (06-02).
class DoseRepository {
  DoseRepository(this._service);
  final SupabaseService _service;

  /// Doses for [propertyId], ordered by name. Excludes archived doses unless
  /// [includeArchived] is true — one query shape, one filter switch (D-15,
  /// D-29 toggle semantics), rather than a second method.
  Future<List<Dose>> fetchDosesByProperty(
    String propertyId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('doses')
        .select()
        .eq('property_id', propertyId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('name');
    return (rows as List)
        .map((r) => Dose.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// A single dose by id. Returns null if not found or RLS blocks.
  Future<Dose?> fetchDose(String id) async {
    final row = await _service.client
        .from('doses')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Dose.fromJson(row);
  }

  /// Create a dose. Blank [activeIngredient]/[costPerKg] are sent as null,
  /// never an empty string — the nullable column is what lets the "omit the
  /// row" rendering rule downstream work (D-11).
  Future<Dose> createDose({
    required String propertyId,
    required String name,
    String? activeIngredient,
    required double dosagePerKg,
    double? costPerKg,
  }) async {
    final trimmedIngredient = activeIngredient?.trim();
    final row = await _service.client.from('doses').insert({
      'property_id': propertyId,
      'name': name.trim(),
      'active_ingredient':
          (trimmedIngredient == null || trimmedIngredient.isEmpty)
              ? null
              : trimmedIngredient,
      'dosage_per_kg': dosagePerKg,
      'cost_per_kg': costPerKg,
    }).select().single();
    return Dose.fromJson(row);
  }

  /// Update a dose's editable fields.
  Future<Dose> updateDose({
    required String id,
    required String name,
    String? activeIngredient,
    required double dosagePerKg,
    double? costPerKg,
  }) async {
    final trimmedIngredient = activeIngredient?.trim();
    final row = await _service.client
        .from('doses')
        .update({
          'name': name.trim(),
          'active_ingredient':
              (trimmedIngredient == null || trimmedIngredient.isEmpty)
                  ? null
                  : trimmedIngredient,
          'dosage_per_kg': dosagePerKg,
          'cost_per_kg': costPerKg,
        })
        .eq('id', id)
        .select()
        .single();
    return Dose.fromJson(row);
  }

  /// Soft-delete: set deleted_at = now(). No DELETE policy exists — a hard
  /// delete would fail at the database anyway (D-15).
  ///
  /// `.select().single()` forces a thrown error when RLS or a stale/wrong id
  /// silently matches zero rows — PostgREST otherwise answers 2xx on a 0-row
  /// UPDATE, the exact silent no-op class fixed server-side for the dose
  /// UPDATE policy in `20260812_06_fix_dose_update_policy.sql` (G-06-2).
  Future<void> archiveDose(String id) async {
    await _service.client
        .from('doses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }

  /// Restore an archived dose: set deleted_at = null.
  Future<void> restoreDose(String id) async {
    await _service.client
        .from('doses')
        .update({'deleted_at': null})
        .eq('id', id)
        .select()
        .single();
  }
}

final doseRepositoryProvider = Provider<DoseRepository>(
  (ref) => DoseRepository(ref.watch(supabaseServiceProvider)),
);

/// Active doses in the active property, ordered by name.
///
/// Resolves [currentPropertyProvider] internally, matching
/// [atfListByPropertyProvider]'s shape, so consuming widgets never pass a
/// property id. Returns [] when no property is selected.
final doseListByPropertyProvider = FutureProvider<List<Dose>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(doseRepositoryProvider);
  return repo.fetchDosesByProperty(property.id);
});

/// Archived doses in the active property, ordered by name — the "Mostrar
/// arquivadas" toggle's data source. A sibling provider rather than a family
/// parameter keeps the toggle a pure provider swap (D-15, D-29).
final archivedDoseListByPropertyProvider =
    FutureProvider<List<Dose>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(doseRepositoryProvider);
  return repo.fetchDosesByProperty(property.id, includeArchived: true);
});
