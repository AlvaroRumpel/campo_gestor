import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart' show Property;
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';

/// One row of `property_members` joined with `propriedades`.
///
/// `perfil` holds the raw enum value from PostgreSQL: `'proprietario'`,
/// `'veterinario'`, or `'leitor'`. UI maps to capitalized pt-BR labels.
class PropertyMembership {
  const PropertyMembership({
    required this.property,
    required this.perfil,
  });

  final Property property;
  final String perfil;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is PropertyMembership &&
          other.property == property &&
          other.perfil == perfil;

  @override
  int get hashCode => Object.hash(property, perfil);
}

/// Repository for property-membership reads.
///
/// Reads are gated by RLS: the policy on `property_members` is
/// `USING (user_id = auth.uid())`, so this query returns ONLY the rows the
/// authenticated user owns. No explicit user_id filter is needed.
///
/// `propriedades(id, nome)` is a PostgREST embedded select that joins the
/// row's referenced propriedade automatically.
class PropertyRepository {
  PropertyRepository(this._service);
  final SupabaseService _service;

  Future<List<PropertyMembership>> fetchMemberProperties() async {
    final rows = await _service.client
        .from('property_members')
        .select('perfil, propriedades(id, nome)')
        .order('propriedades(nome)');

    return (rows as List).map((row) {
      final r = row as Map<String, dynamic>;
      final rawProp = r['propriedades'];
      if (rawProp == null) {
        // Membership row exists but the joined property is not readable —
        // RLS blocked it (e.g., mid-query membership revocation). Skip it.
        return null;
      }
      final p = rawProp as Map<String, dynamic>;
      return PropertyMembership(
        property: Property(
          id: p['id'] as String,
          nome: p['nome'] as String,
        ),
        perfil: r['perfil'] as String,
      );
    }).whereType<PropertyMembership>().toList();
  }
}

final propertyRepositoryProvider = Provider<PropertyRepository>(
  (ref) => PropertyRepository(ref.watch(supabaseServiceProvider)),
);
