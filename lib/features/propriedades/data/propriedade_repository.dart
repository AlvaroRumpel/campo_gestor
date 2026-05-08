import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'propriedade_model.dart';

/// CRUD repository for propriedades (PROP-01).
///
/// All methods route through SupabaseService — widgets must NEVER import
/// supabase_flutter directly (D-06 from Phase 0).
class PropriedadeRepository {
  PropriedadeRepository(this._service);
  final SupabaseService _service;

  /// Fetch all propriedades the user is a member of, excluding soft-deleted.
  /// Used by /propriedades management screen.
  Future<List<Propriedade>> fetchPropriedades() async {
    // Gated by RLS members_can_read_their_properties; we still pass the
    // deleted_at filter for clarity and to allow future query optimizer use.
    final rows = await _service.client
        .from('propriedades')
        .select()
        .isFilter('deleted_at', null)
        .order('nome');
    return (rows as List)
        .map((r) => Propriedade.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Create a propriedade and immediately register the creator as
  /// veterinario member (D-04). Two-step because RLS prevents
  /// arbitrary INSERT into property_members.
  ///
  /// Returns the created Propriedade. Throws on RLS or network failure.
  ///
  /// NOTE (T-02-12): If step 2 (membership INSERT) fails after step 1
  /// (propriedade INSERT), an orphan propriedade row is left in the DB.
  /// Accepted for MVP: the row is invisible (no membership → RLS blocks reads).
  /// A future phase will wrap both inserts in a Postgres function atomically.
  Future<Propriedade> createPropriedadeWithMembership({
    required String nome,
    required String proprietario,
  }) async {
    // Step 1: insert propriedade. RLS allows any authenticated user to INSERT.
    final propRow = await _service.client
        .from('propriedades')
        .insert({
          'nome': nome,
          'proprietario': proprietario,
        })
        .select()
        .single();
    final created = Propriedade.fromJson(propRow);

    // Step 2: insert membership row with perfil='veterinario' (D-04).
    // RLS WITH CHECK enforces user_id = auth.uid().
    final userId = _service.auth.currentUser?.id;
    if (userId == null) {
      throw StateError('Usuário não autenticado ao criar propriedade');
    }
    await _service.client.from('property_members').insert({
      'user_id': userId,
      'property_id': created.id,
      'perfil': 'veterinario',
    });

    return created;
  }

  /// Update a propriedade's editable fields. RLS requires get_perfil = veterinario.
  Future<Propriedade> updatePropriedade({
    required String id,
    required String nome,
    required String proprietario,
  }) async {
    final row = await _service.client
        .from('propriedades')
        .update({
          'nome': nome,
          'proprietario': proprietario,
        })
        .eq('id', id)
        .select()
        .single();
    return Propriedade.fromJson(row);
  }

  /// Soft-delete: sets deleted_at = now(). RLS requires veterinario perfil.
  /// Hard DELETE is intentionally not granted in the schema.
  Future<void> softDeletePropriedade(String id) async {
    await _service.client
        .from('propriedades')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}

final propriedadeRepositoryProvider = Provider<PropriedadeRepository>(
  (ref) => PropriedadeRepository(ref.watch(supabaseServiceProvider)),
);

/// List of propriedades the active user can see (filtered by RLS + soft-delete).
final propriedadeListProvider =
    FutureProvider<List<Propriedade>>((ref) async {
  // Re-fetch when auth state changes to handle login/logout cleanly.
  ref.watch(authNotifierProvider);
  final repo = ref.read(propriedadeRepositoryProvider);
  return repo.fetchPropriedades();
});
