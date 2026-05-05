import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/property_repository.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Active rural property the user is operating on.
///
/// Phase 0 placeholder. Phase 1 connects to property_members + SharedPreferences.
class Property {
  const Property({required this.id, required this.nome});
  final String id;
  final String nome;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Property && other.id == id && other.nome == nome;

  @override
  int get hashCode => Object.hash(id, nome);
}

/// SharedPreferences key for the persisted active property (D-06).
const _kActivePropertyIdKey = 'active_property_id';

/// All properties the current user is a member of, joined with their perfil.
///
/// Re-fetches whenever auth state changes. Returns [] when no session.
final memberPropertiesProvider =
    FutureProvider<List<PropertyMembership>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final session = auth.asData?.value?.session;
  if (session == null) return const [];

  final repo = ref.read(propertyRepositoryProvider);
  return repo.fetchMemberProperties();
});

class CurrentPropertyNotifier extends AsyncNotifier<Property?> {
  @override
  Future<Property?> build() async {
    final memberships = await ref.watch(memberPropertiesProvider.future);

    // 0 propriedades → router envia para /sem-acesso (Task 4).
    if (memberships.isEmpty) return null;

    // 1 propriedade: auto-seleciona (D-05).
    if (memberships.length == 1) {
      return memberships.first.property;
    }

    // 2+ propriedades: respeita saved_id; senão first (Pitfall 4 — stale id).
    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kActivePropertyIdKey);
    final match = memberships.where((m) => m.property.id == savedId);
    return match.isNotEmpty ? match.first.property : memberships.first.property;
  }

  /// Set the active property (used by selector dropdown). Persists in
  /// SharedPreferences so the next reload bypasses the picker.
  Future<void> selectProperty(Property property) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActivePropertyIdKey, property.id);
    state = AsyncData(property);
  }

  /// Clear active property (used on logout). Removes the persisted id too.
  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActivePropertyIdKey);
    state = const AsyncData(null);
  }
}

final currentPropertyProvider =
    AsyncNotifierProvider<CurrentPropertyNotifier, Property?>(
  CurrentPropertyNotifier.new,
);
