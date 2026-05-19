import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'lote_model.dart';

/// CRUD repository for lots (PROP-03, PROP-04).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly.
class LoteRepository {
  LoteRepository(this._service);
  final SupabaseService _service;

  /// Fetch active lots for a paddock, ordered by name.
  Future<List<Lot>> fetchLotsByPaddock(String paddockId) async {
    final rows = await _service.client
        .from('lots')
        .select()
        .eq('paddock_id', paddockId)
        .isFilter('deleted_at', null)
        .order('name');
    return (rows as List)
        .map((r) => Lot.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single lot by id. Returns null if soft-deleted or RLS blocks.
  Future<Lot?> fetchLot(String id) async {
    final row = await _service.client
        .from('lots')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return Lot.fromJson(row);
  }

  /// Create lot with batch animal generation via atomic RPC (PROP-04).
  ///
  /// Params:
  /// - [propertyId]: The property this lot belongs to.
  /// - [paddockId]: The paddock this lot lives in.
  /// - [name]: Display name of the lot.
  /// - [categoryQuantities]: Map of category → quantity, e.g. {'vaca': 10, 'terneiro': 8}.
  /// - [categoryBreeds]: Map of category → breed (nullable), e.g. {'vaca': 'Nelore'}.
  /// - [startNumber]: Optional starting number for the batch. If null, uses MAX+1.
  Future<Lot> createLotWithAnimals({
    required String propertyId,
    required String paddockId,
    required String name,
    required Map<String, int> categoryQuantities,
    required Map<String, String?> categoryBreeds,
    int? startNumber,
  }) async {
    final result = await _service.client.rpc(
      'create_lot_with_animals',
      params: {
        'p_property_id': propertyId,
        'p_paddock_id': paddockId,
        'p_name': name,
        'p_category_qtys': categoryQuantities,
        'p_category_breeds': categoryBreeds,
        'p_start_number': startNumber,
      },
    );
    return Lot.fromJson(result as Map<String, dynamic>);
  }

  /// Update lot name only (D-12 — paddock/property are immutable after creation).
  Future<Lot> updateLotName({
    required String id,
    required String name,
  }) async {
    final row = await _service.client
        .from('lots')
        .update({'name': name})
        .eq('id', id)
        .select()
        .single();
    return Lot.fromJson(row);
  }

  /// Soft-delete: set deleted_at = now(). Hard DELETE not granted.
  Future<void> softDeleteLot(String id) async {
    await _service.client
        .from('lots')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}

final loteRepositoryProvider = Provider<LoteRepository>(
  (ref) => LoteRepository(ref.watch(supabaseServiceProvider)),
);

/// Active lots for a specific paddock, ordered by name.
final loteListByPaddockProvider =
    FutureProvider.family<List<Lot>, String>((ref, paddockId) async {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLotsByPaddock(paddockId);
});

/// Single lot by id (for LoteDetailScreen).
final loteByIdProvider =
    FutureProvider.family<Lot?, String>((ref, id) async {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLot(id);
});
