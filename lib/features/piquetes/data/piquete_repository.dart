import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'piquete_model.dart';

/// CRUD repository for piquetes (PROP-02).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (D-06 from Phase 0).
class PiqueteRepository {
  PiqueteRepository(this._service);
  final SupabaseService _service;

  /// Fetch active piquetes for a propriedade, ordered by nome.
  Future<List<Piquete>> fetchPiquetes(String propriedadeId) async {
    final rows = await _service.client
        .from('piquetes')
        .select()
        .eq('propriedade_id', propriedadeId)
        .isFilter('deleted_at', null)
        .order('nome');
    return (rows as List)
        .map((r) => Piquete.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch a single piquete by id (for detail screen).
  /// Returns null if soft-deleted or RLS blocks the read.
  Future<Piquete?> fetchPiquete(String id) async {
    final row = await _service.client
        .from('piquetes')
        .select()
        .eq('id', id)
        .isFilter('deleted_at', null)
        .maybeSingle();
    if (row == null) return null;
    return Piquete.fromJson(row);
  }

  /// Create piquete. RLS requires veterinario perfil on propriedade_id.
  Future<Piquete> createPiquete({
    required String propriedadeId,
    required String nome,
    required double areaHa,
    required double capacidadeUa,
  }) async {
    final row = await _service.client
        .from('piquetes')
        .insert({
          'propriedade_id': propriedadeId,
          'nome': nome,
          'area_ha': areaHa,
          'capacidade_ua': capacidadeUa,
        })
        .select()
        .single();
    return Piquete.fromJson(row);
  }

  /// Update piquete. RLS requires veterinario perfil.
  Future<Piquete> updatePiquete({
    required String id,
    required String nome,
    required double areaHa,
    required double capacidadeUa,
  }) async {
    final row = await _service.client
        .from('piquetes')
        .update({
          'nome': nome,
          'area_ha': areaHa,
          'capacidade_ua': capacidadeUa,
        })
        .eq('id', id)
        .select()
        .single();
    return Piquete.fromJson(row);
  }

  /// Soft-delete: set deleted_at = now(). Hard DELETE not granted.
  Future<void> softDeletePiquete(String id) async {
    await _service.client
        .from('piquetes')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}

final piqueteRepositoryProvider = Provider<PiqueteRepository>(
  (ref) => PiqueteRepository(ref.watch(supabaseServiceProvider)),
);

/// List of piquetes for the active propriedade. Empty when no active property.
///
/// Watching currentPropertyProvider.future ensures the list re-fetches when
/// the user switches propriedade via PropertySelector (Pitfall 6).
final piqueteListProvider = FutureProvider<List<Piquete>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.read(piqueteRepositoryProvider);
  return repo.fetchPiquetes(property.id);
});

/// Single piquete by id (for /piquetes/:id detail screen).
final piqueteByIdProvider =
    FutureProvider.family<Piquete?, String>((ref, id) async {
  final repo = ref.read(piqueteRepositoryProvider);
  return repo.fetchPiquete(id);
});
