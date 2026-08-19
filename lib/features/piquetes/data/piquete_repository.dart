import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'piquete_model.dart';

/// CRUD repository for paddocks (PROP-02).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (D-06 from Phase 0).
class PaddockRepository {
  PaddockRepository(this._service);
  final SupabaseService _service;

  /// Fetch active paddocks for a property, ordered by name.
  Future<List<Paddock>> fetchPaddocks(String propertyId) async {
    final rows = await _service.client
        .from('paddocks')
        .select()
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .order('name');
    return (rows as List)
        .map((r) => Paddock.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single paddock by id. Returns null if soft-deleted or RLS blocks.
  Future<Paddock?> fetchPaddock(String id) async {
    final row = await _service.client
        .from('paddocks')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return Paddock.fromJson(row);
  }

  /// Create paddock. RLS requires veterinarian role on property_id.
  Future<Paddock> createPaddock({
    required String propertyId,
    required String name,
    required double areaHa,
    required double uaCapacity,
  }) async {
    final row = await _service.client
        .from('paddocks')
        .insert({
          'property_id': propertyId,
          'name': name,
          'area_ha': areaHa,
          'ua_capacity': uaCapacity,
        })
        .select()
        .single();
    return Paddock.fromJson(row);
  }

  /// Update paddock. RLS requires veterinarian role.
  Future<Paddock> updatePaddock({
    required String id,
    required String name,
    required double areaHa,
    required double uaCapacity,
  }) async {
    final row = await _service.client
        .from('paddocks')
        .update({
          'name': name,
          'area_ha': areaHa,
          'ua_capacity': uaCapacity,
        })
        .eq('id', id)
        .select()
        .single();
    return Paddock.fromJson(row);
  }

  /// Soft-delete: set deleted_at = now(). Hard DELETE not granted.
  ///
  /// `.select().single()` faz 0 linhas afetadas virar erro em vez de sucesso
  /// silencioso — RLS filtrando por USING, ou o trigger
  /// trg_paddocks_archive_guard (20260819_14) recusando o arquivamento,
  /// precisam chegar na UI (mesmo padrão de DoseRepository.archiveDose).
  Future<void> softDeletePaddock(String id) async {
    await _service.client
        .from('paddocks')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }
}

final paddockRepositoryProvider = Provider<PaddockRepository>(
  (ref) => PaddockRepository(ref.watch(supabaseServiceProvider)),
);

/// List of paddocks for the active property. Empty when no active property.
///
/// Watching currentPropertyProvider.future ensures the list re-fetches when
/// the user switches property via PropertySelector (Pitfall 6).
final paddockListProvider = FutureProvider<List<Paddock>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.read(paddockRepositoryProvider);
  return repo.fetchPaddocks(property.id);
});

/// Single paddock by id (for /piquetes/:id detail screen).
final paddockByIdProvider =
    FutureProvider.family<Paddock?, String>((ref, id) async {
  final repo = ref.read(paddockRepositoryProvider);
  return repo.fetchPaddock(id);
});
