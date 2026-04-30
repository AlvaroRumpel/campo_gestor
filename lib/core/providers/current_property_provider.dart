import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Placeholder property type. Phase 1 replaces with `@freezed` immutable model
/// loaded from `propriedades` table via PropertyRepository.
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

class CurrentPropertyNotifier extends AsyncNotifier<Property?> {
  /// Phase 0: always null. Phase 1 reads `property_members` for current user
  /// and resolves the active property (with multi-property selector UX).
  @override
  Future<Property?> build() async => null;

  /// Set the active property (used by selector dropdown in AppShell).
  Future<void> selectProperty(Property property) async {
    state = AsyncData(property);
  }

  /// Clear the active property (used on logout).
  Future<void> clear() async {
    state = const AsyncData(null);
  }
}

final currentPropertyProvider =
    AsyncNotifierProvider<CurrentPropertyNotifier, Property?>(
  CurrentPropertyNotifier.new,
);
