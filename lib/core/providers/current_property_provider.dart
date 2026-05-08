import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/property_repository.dart';
import '../../features/auth/providers/auth_provider.dart';

/// Lightweight shell DTO for the currently active property.
///
/// Used by AppShell, PropertySelector, and router — only needs id + name.
/// The full domain model (Property) lives in propriedade_model.dart.
class SelectedProperty {
  const SelectedProperty({required this.id, required this.name});
  final String id;
  final String name;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SelectedProperty && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// SharedPreferences key for the persisted active property (D-06).
const _kActivePropertyIdKey = 'active_property_id';

/// All properties the current user is a member of, joined with their role.
///
/// Re-fetches whenever auth state changes. Returns [] when no session.
final memberPropertiesProvider =
    FutureProvider<List<PropertyMembership>>((ref) async {
  final auth = ref.watch(authNotifierProvider);
  final session = auth.asData?.value?.session;
  if (session == null) return const [];

  final repo = ref.read(membershipRepositoryProvider);
  return repo.fetchMemberProperties();
});

class CurrentPropertyNotifier extends AsyncNotifier<SelectedProperty?> {
  @override
  Future<SelectedProperty?> build() async {
    final memberships = await ref.watch(memberPropertiesProvider.future);

    if (memberships.isEmpty) return null;

    if (memberships.length == 1) {
      return memberships.first.property;
    }

    final prefs = await SharedPreferences.getInstance();
    final savedId = prefs.getString(_kActivePropertyIdKey);
    final match = memberships.where((m) => m.property.id == savedId);
    return match.isNotEmpty ? match.first.property : memberships.first.property;
  }

  Future<void> selectProperty(SelectedProperty property) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kActivePropertyIdKey, property.id);
    state = AsyncData(property);
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kActivePropertyIdKey);
    state = const AsyncData(null);
  }
}

final currentPropertyProvider =
    AsyncNotifierProvider<CurrentPropertyNotifier, SelectedProperty?>(
  CurrentPropertyNotifier.new,
);
