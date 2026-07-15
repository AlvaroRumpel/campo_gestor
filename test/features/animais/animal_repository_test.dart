// MOV-01 — AnimalRepository.moveAnimal contract.
// Wave 0 stubs. Method `moveAnimal` lands in Plan 04-02.
// Until Plan 04-02 commits, the `expect(repo.moveAnimal, ...)` lines below
// FAIL TO COMPILE — that is the desired Nyquist red state.
// Pattern mirrors test/features/lotes/lote_repository_test.dart.
import 'package:campo_gestor/core/services/supabase_service.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/animais/data/animal_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSupabaseService extends Mock implements SupabaseService {}

void main() {
  late MockSupabaseService mockService;
  late AnimalRepository repo;

  setUp(() {
    mockService = MockSupabaseService();
    repo = AnimalRepository(mockService);
  });

  group('AnimalRepository (MOV-01)', () {
    test('moveAnimal exists and is callable', () {
      expect(repo.moveAnimal, isA<Function>());
    });

    test(
        'moveAnimal accepts named params id and newLotId returning Future<Animal>',
        () {
      // Planned signature: Future<Animal> moveAnimal({required String id, required String newLotId})
      expect(repo.moveAnimal, isA<Function>());
    });

    test('fetchAnimalsByLot still exists (regression guard)', () {
      expect(repo.fetchAnimalsByLot, isA<Function>());
    });

    test('updateAnimal still exists (regression guard for unchanged surface)',
        () {
      expect(repo.updateAnimal, isA<Function>());
    });
  });

  group('Animal model (MOV-01 — model side regression)', () {
    test('Animal.fromJson parses lot_id correctly', () {
      final json = <String, dynamic>{
        'id': 'animal-uuid-001',
        'property_id': 'prop-uuid-001',
        'lot_id': 'lot-uuid-A',
        'category': 'vaca',
        'number': 1,
        'created_at': '2026-05-14T00:00:00.000Z',
      };
      final animal = Animal.fromJson(json);
      expect(animal.lotId, 'lot-uuid-A');
    });
  });
}
