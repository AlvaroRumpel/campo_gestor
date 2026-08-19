import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
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
  /// `.select().single()` faz 0 linhas afetadas virar erro em vez de sucesso
  /// silencioso — RLS filtrando por USING, ou trg_lots_archive_guard
  /// (20260814_10) recusando o arquivamento, precisam chegar na UI.
  Future<void> softDeleteLot(String id) async {
    await _service.client
        .from('lots')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }

  /// Move a lot to a different paddock atomically via plpgsql RPC (MOV-02, D-08).
  ///
  /// The RPC `move_lot_to_paddock` validates:
  /// 1. Lot exists and is active (deleted_at IS NULL)
  /// 2. Caller is a member of the lot's property
  /// 3. Caller's role on the property = veterinarian
  /// 4. Source paddock != destination paddock (prevents no-op)
  /// 5. Destination paddock belongs to the same property AND is active
  ///
  /// On any validation failure, the RPC raises a PostgrestException whose
  /// `code` is '42501' (permission), '23503' (FK violation), or '23514'
  /// (check violation). The caller (MoverLoteDialog) catches generically
  /// and shows the standard 'Erro ao mover. Tente novamente.' SnackBar.
  ///
  /// Returns `void` — the caller invalidates [loteByIdProvider] and the
  /// two affected [loteListByPaddockProvider] families to refetch UI state.
  Future<void> moveLot({
    required String lotId,
    required String newPaddockId,
  }) async {
    await _service.client.rpc(
      'move_lot_to_paddock',
      params: {
        'p_lot_id': lotId,
        'p_paddock_id': newPaddockId,
      },
    );
  }

  /// Fetch active lots for a property with paddock name + active animal count (MOV-01, D-03).
  ///
  /// Returns one row per active lot (deleted_at IS NULL), each enriched with:
  /// - `paddockName` from joined paddocks table
  /// - `activeAnimalCount` (animals where deleted_at IS NULL)
  ///
  /// Used by [MoverAnimalDialog] picker. Excludes archived lots (Pitfall 4).
  ///
  /// Uses two queries to avoid PostgREST embedded-aggregate ambiguity:
  /// (1) lots + paddock name, (2) animal counts grouped by lot_id (computed
  /// in Dart from a single property-wide animals query).
  Future<List<LotWithPaddockCount>> fetchLotsWithCountByProperty(
    String propertyId,
  ) async {
    // Query 1: active lots with embedded paddock name
    final lotRows = await _service.client
        .from('lots')
        .select('*, paddocks!inner(name)')
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null)
        .order('name');

    // Query 2: active animals for the property — count grouped by lot_id in Dart
    final animalRows = await _service.client
        .from('animals')
        .select('lot_id')
        .eq('property_id', propertyId)
        .isFilter('deleted_at', null);

    final counts = <String, int>{};
    for (final row in animalRows as List) {
      final map = row as Map<String, dynamic>;
      final lotId = map['lot_id'] as String?;
      if (lotId == null) continue;
      counts[lotId] = (counts[lotId] ?? 0) + 1;
    }

    return (lotRows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final paddockJson = map['paddocks'] as Map<String, dynamic>;
      final clean = Map<String, dynamic>.from(map)..remove('paddocks');
      final lot = Lot.fromJson(clean);
      return LotWithPaddockCount(
        lot: lot,
        paddockName: paddockJson['name'] as String,
        activeAnimalCount: counts[lot.id] ?? 0,
      );
    }).toList();
  }

  /// Fetch a single lot with its paddock name in one embedded-select query (D-01).
  ///
  /// Kills the lote → piquete waterfall: callers no longer need a second
  /// request to resolve `lot.paddockId` into a display name. Returns null
  /// if the lot is soft-deleted or does not exist (mirrors [fetchLot]).
  Future<LotWithPaddockName?> fetchLotWithPaddockName(String id) async {
    final row = await _service.client
        .from('lots')
        .select('*, paddocks!inner(name)')
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    final paddockJson = row['paddocks'] as Map<String, dynamic>;
    final clean = Map<String, dynamic>.from(row)..remove('paddocks');
    return LotWithPaddockName(
      lot: Lot.fromJson(clean),
      paddockName: paddockJson['name'] as String,
    );
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

/// Single lot with paddock name in one embedded-select query (D-01, D-03).
///
/// Auto-dispose family (no keepAlive) — reopening the ficha always refetches
/// so a vet never sees a stale lot/paddock on the animal dossier.
final loteWithPaddockByIdProvider =
    FutureProvider.family<LotWithPaddockName?, String>((ref, id) async {
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLotWithPaddockName(id);
});

/// Active lots in the active property (MOV-01, D-02).
///
/// Re-fetches when the active property changes (mirrors
/// [animalListByPropertyProvider]'s pattern of watching
/// `currentPropertyProvider` internally rather than taking a family arg).
/// Used by [MoverAnimalDialog] picker; paddock name + active animal count
/// per item are resolved separately via [paddockByIdProvider] and
/// [animalListByLotProvider] (D-03).
final loteListByPropertyProvider = FutureProvider<List<Lot>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(loteRepositoryProvider);
  final enriched = await repo.fetchLotsWithCountByProperty(property.id);
  return enriched.map((e) => e.lot).toList();
});

/// Active lots with paddock name + active animal count for the "Lotes" list
/// destination on /piquetes (spec 4.6). Reuses
/// [LoteRepository.fetchLotsWithCountByProperty] (same query as the mover
/// picker) — additive provider, no new repository method.
final loteWithPaddockListByPropertyProvider =
    FutureProvider<List<LotWithPaddockCount>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLotsWithCountByProperty(property.id);
});

/// Lot joined with its paddock name and active animal count for picker display (D-03, MOV-01).
///
/// Built from the embedded-resource select in [LoteRepository.fetchLotsWithCountByProperty].
/// Not a Supabase row by itself.
class LotWithPaddockCount {
  const LotWithPaddockCount({
    required this.lot,
    required this.paddockName,
    required this.activeAnimalCount,
  });
  final Lot lot;
  final String paddockName;
  final int activeAnimalCount;
}

/// Lot joined with its paddock name from a single embedded-select query (D-01).
///
/// Built from [LoteRepository.fetchLotWithPaddockName]. Not a Supabase row
/// by itself — same convention as [LotWithPaddockCount].
class LotWithPaddockName {
  const LotWithPaddockName({
    required this.lot,
    required this.paddockName,
  });
  final Lot lot;
  final String paddockName;
}
