import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../auth/providers/auth_provider.dart';
import 'propriedade_model.dart';

/// CRUD repository for properties (PROP-01).
///
/// All methods route through SupabaseService — widgets must NEVER import
/// supabase_flutter directly (D-06 from Phase 0).
class PropertyRepository {
  PropertyRepository(this._service);
  final SupabaseService _service;

  /// Fetch all properties the user is a member of, excluding soft-deleted.
  Future<List<Property>> fetchProperties() async {
    final rows = await _service.client
        .from('properties')
        .select()
        .isFilter('deleted_at', null)
        .order('name');
    return (rows as List)
        .map((r) => Property.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Create a property and immediately register the creator as
  /// veterinarian member (D-04). Two-step because RLS prevents
  /// arbitrary INSERT into property_members.
  ///
  /// Returns the created Property. Throws on RLS or network failure.
  ///
  /// NOTE (T-02-12): If step 2 (membership INSERT) fails after step 1
  /// (property INSERT), an orphan property row is left in the DB.
  /// Accepted for MVP: the row is invisible (no membership → RLS blocks reads).
  /// A future phase will wrap both inserts in a Postgres function atomically.
  Future<Property> createPropertyWithMembership({
    required String name,
    String? owner,
  }) async {
    final result = await _service.client.rpc(
      'create_property_with_membership',
      params: {
        'p_name': name,
        if (owner != null) 'p_owner': owner,
      },
    );
    return Property.fromJson(result as Map<String, dynamic>);
  }

  /// Update a property's editable fields. RLS requires get_role = veterinarian.
  Future<Property> updateProperty({
    required String id,
    required String name,
    String? owner,
  }) async {
    final row = await _service.client
        .from('properties')
        .update({
          'name': name,
          'owner': owner,
        })
        .eq('id', id)
        .select()
        .single();
    return Property.fromJson(row);
  }

  /// Soft-delete: sets deleted_at = now(). RLS requires veterinarian role.
  Future<void> softDeleteProperty(String id) async {
    await _service.client
        .from('properties')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id);
  }
}

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => PropertyRepository(ref.watch(supabaseServiceProvider)),
);

/// List of properties the active user can see (filtered by RLS + soft-delete).
final propertyListProvider = FutureProvider<List<Property>>((ref) async {
  ref.watch(authNotifierProvider);
  final repo = ref.read(propertyRepositoryProvider);
  return repo.fetchProperties();
});
