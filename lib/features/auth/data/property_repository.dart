import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart' show SelectedProperty;
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';

/// One row of `property_members` joined with `properties`.
///
/// `role` holds the raw enum value from PostgreSQL: `'owner'`,
/// `'veterinarian'`, or `'reader'`. UI maps to display labels.
class PropertyMembership {
  const PropertyMembership({
    required this.property,
    required this.role,
  });

  final SelectedProperty property;
  final String role;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyMembership &&
          other.property == property &&
          other.role == role;

  @override
  int get hashCode => Object.hash(property, role);
}

/// Repository for property-membership reads.
///
/// Reads are gated by RLS: the policy on `property_members` is
/// `USING (user_id = auth.uid())`, so this query returns ONLY the rows the
/// authenticated user owns. No explicit user_id filter is needed.
class MembershipRepository {
  MembershipRepository(this._service);
  final SupabaseService _service;

  Future<List<PropertyMembership>> fetchMemberProperties() async {
    final rows = await _service.client
        .from('property_members')
        .select('role, properties!inner(id, name, deleted_at)')
        .isFilter('properties.deleted_at', null)
        .order('properties(name)');

    return (rows as List).map((row) {
      final r = row as Map<String, dynamic>;
      final rawProp = r['properties'];
      if (rawProp == null) return null;
      final p = rawProp as Map<String, dynamic>;
      return PropertyMembership(
        property: SelectedProperty(
          id: p['id'] as String,
          name: p['name'] as String,
        ),
        role: r['role'] as String,
      );
    }).whereType<PropertyMembership>().toList();
  }
}

final membershipRepositoryProvider = Provider<MembershipRepository>(
  (ref) => MembershipRepository(ref.watch(supabaseServiceProvider)),
);
