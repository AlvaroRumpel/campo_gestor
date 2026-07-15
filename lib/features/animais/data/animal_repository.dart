// ignore_for_file: use_null_aware_elements
// Reason: `use_null_aware_elements` suggests `'key'?: value` syntax which causes
// compiler errors in Dart 3.11 (the feature was proposed but not finalized as
// map-literal syntax). The `if (x != null) 'key': x` pattern is the correct idiom.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show PostgrestException;

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import 'animal_constants.dart';
import 'animal_model.dart';

/// Thrown when a manual animal number conflicts with an existing active animal.
///
/// Triggered by PostgrestException with code '23505' (unique_violation).
/// UI should display the message from UI-SPEC.md (T-3-10).
class AnimalNumberConflictException implements Exception {
  const AnimalNumberConflictException(this.message);
  final String message;

  @override
  String toString() => 'AnimalNumberConflictException: $message';
}

/// CRUD + baixa repository for animals (ANIM-01, ANIM-02, ANIM-04).
///
/// All Supabase access flows through SupabaseService — widgets must NEVER
/// import supabase_flutter directly (T-3-09: only PostgrestException type is
/// referenced here, which is a domain-error type, not a client constructor).
class AnimalRepository {
  AnimalRepository(this._service);
  final SupabaseService _service;

  /// Fetch animals in a lot.
  ///
  /// [includeArchived] — when false (default), excludes soft-deleted animals.
  Future<List<Animal>> fetchAnimalsByLot(
    String lotId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('animals')
        .select()
        .eq('lot_id', lotId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('number');
    return (rows as List)
        .map((r) => Animal.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Fetch all animals for a property with embedded lot + paddock context.
  ///
  /// Returns [AnimalWithContext] — animal joined with lot.name, paddock.id,
  /// paddock.name for AnimaisScreen display (D-18, D-19, Pitfall 5).
  ///
  /// Always loads ALL animals (active + archived) — AnimaisScreen filters
  /// in-memory based on the toggle state (Pitfall 6, single query path).
  Future<List<AnimalWithContext>> fetchAnimalsByProperty(
    String propertyId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('animals')
        .select('*, lots!inner(name, paddock_id, paddocks!inner(id, name))')
        .eq('property_id', propertyId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query.order('number');
    return (rows as List).map((row) {
      final map = row as Map<String, dynamic>;
      final clean = Map<String, dynamic>.from(map)..remove('lots');
      final animal = Animal.fromJson(clean);
      final lotsJson = map['lots'] as Map<String, dynamic>;
      final paddockJson = lotsJson['paddocks'] as Map<String, dynamic>;
      return AnimalWithContext(
        animal: animal,
        lotName: lotsJson['name'] as String,
        paddockId: paddockJson['id'] as String,
        paddockName: paddockJson['name'] as String,
      );
    }).toList();
  }

  /// Fetch a single animal by id. Returns null if not found or RLS blocks.
  Future<Animal?> fetchAnimal(String id) async {
    final row = await _service.client
        .from('animals')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return Animal.fromJson(row);
  }

  /// Generate the next available animal number for a property.
  ///
  /// Calls the `generate_animal_number` RPC which holds a pg_advisory_xact_lock
  /// to prevent concurrent duplicates (D-05, D-08, Pitfall 3).
  Future<int> generateAnimalNumber(String propertyId) async {
    final result = await _service.client.rpc(
      'generate_animal_number',
      params: {'p_property_id': propertyId},
    );
    return result as int;
  }

  /// Create an individual animal in an existing lot (D-13).
  ///
  /// Throws [AnimalNumberConflictException] on unique constraint violation (T-3-10).
  Future<Animal> createAnimal({
    required String propertyId,
    required String lotId,
    required String category,
    required int number,
    String? breed,
    int? bodyCondition,
    String? observation,
  }) async {
    try {
      final row = await _service.client.from('animals').insert({
        'property_id': propertyId,
        'lot_id': lotId,
        'category': category,
        'number': number,
        if (breed != null) 'breed': breed,
        if (bodyCondition != null) 'body_condition': bodyCondition,
        if (observation != null) 'observation': observation,
      }).select().single();
      return Animal.fromJson(row);
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        throw const AnimalNumberConflictException(
          'O número informado já está em uso. Escolha outro número ou deixe em branco para auto-gerar.',
        );
      }
      rethrow;
    }
  }

  /// Update editable animal fields: breed, body_condition, observation (ANIM-02).
  ///
  /// Only sends provided non-null fields — never touches category, number,
  /// property_id, or lot_id (T-3-12 mass-assignment mitigation). Use
  /// [moveAnimal] to change `lot_id` — it intentionally bypasses this guard.
  Future<Animal> updateAnimal({
    required String id,
    String? breed,
    int? bodyCondition,
    String? observation,
  }) async {
    final payload = <String, dynamic>{
      if (breed != null) 'breed': breed,
      if (bodyCondition != null) 'body_condition': bodyCondition,
      if (observation != null) 'observation': observation,
    };
    final row = await _service.client
        .from('animals')
        .update(payload)
        .eq('id', id)
        .select()
        .single();
    return Animal.fromJson(row);
  }

  /// Move an animal to a different lot in the same property (MOV-01, D-04).
  ///
  /// Only updates `lot_id` — never touches category, number, property_id, or
  /// any editable field. RLS [veterinarian_can_update_active_animal] gates
  /// this UPDATE: blocked for non-veterinarians and archived animals.
  ///
  /// Cross-property safety (T-4-01): RLS validates the source animal's
  /// property membership but does NOT enforce that [newLotId] belongs to the
  /// same property. The UI layer enforces this by scoping the picker via
  /// [loteListByPropertyProvider] to the active property. A malicious direct
  /// API call could still set lot_id to a foreign-property lot — this is an
  /// accepted MVP gap (documented in 04-RESEARCH.md Pitfall / Open Question 1).
  Future<Animal> moveAnimal({
    required String id,
    required String newLotId,
  }) async {
    final row = await _service.client
        .from('animals')
        .update({'lot_id': newLotId})
        .eq('id', id)
        .select()
        .single();
    return Animal.fromJson(row);
  }

  /// Register baixa (soft delete with reason and date) for an animal (ANIM-04).
  ///
  /// Sets baixa_reason, baixa_date, and deleted_at in a single UPDATE.
  Future<void> registerBaixa({
    required String id,
    required BaixaReason reason,
    required DateTime date,
    String? observation,
  }) async {
    final payload = <String, dynamic>{
      'baixa_reason': reason.dbValue,
      'baixa_date': date.toUtc().toIso8601String().substring(0, 10),
      'deleted_at': DateTime.now().toUtc().toIso8601String(),
      if (observation != null) 'observation': observation,
    };
    await _service.client.from('animals').update(payload).eq('id', id);
  }
}

final animalRepositoryProvider = Provider<AnimalRepository>(
  (ref) => AnimalRepository(ref.watch(supabaseServiceProvider)),
);

/// Active animals in a lot, ordered by number.
final animalListByLotProvider =
    FutureProvider.family<List<Animal>, String>((ref, lotId) async {
  final repo = ref.watch(animalRepositoryProvider);
  return repo.fetchAnimalsByLot(lotId);
});

/// All animals (active + archived) for the active property with lot+paddock context.
///
/// Always fetches all — AnimaisScreen filters in-memory (Pitfall 6).
/// Re-fetches when the active property changes.
final animalListByPropertyProvider =
    FutureProvider<List<AnimalWithContext>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(animalRepositoryProvider);
  return repo.fetchAnimalsByProperty(property.id, includeArchived: true);
});

/// Single animal by id (for /animais/:id detail screen).
final animalByIdProvider =
    FutureProvider.family<Animal?, String>((ref, id) async {
  final repo = ref.watch(animalRepositoryProvider);
  return repo.fetchAnimal(id);
});
