// PROP-05 — UA total = sum(kUaWeights[a.category]) for all active animals.
// Wave 1 — skip markers removed; tests pass with calcTotalUa + kUaWeights from animal_constants.dart.
// Reference table from REQUIREMENTS.md Business Rules:
// vaca=1.0, novilha=0.75, terneiro=0.5, terneira=0.5, touro=1.5, boi=1.5, novilho=0.75
import 'package:campo_gestor/features/animais/data/animal_constants.dart';
import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:flutter_test/flutter_test.dart';

Animal _makeAnimal(String category, int number) => Animal(
      id: 'id-$category-$number',
      propertyId: 'prop-id',
      lotId: 'lot-id',
      category: category,
      number: number,
      createdAt: DateTime.utc(2026),
    );

void main() {
  group('UA calculation (PROP-05)', () {
    test('calcTotalUa returns 0.0 for empty list', () {
      expect(calcTotalUa([]), 0.0);
    });

    test(
        'calcTotalUa sums per-category weights — 10 vacas + 8 terneiros + 1 touro = 15.5',
        () {
      final animals = [
        for (int i = 0; i < 10; i++) _makeAnimal('vaca', i + 1),
        for (int i = 0; i < 8; i++) _makeAnimal('terneiro', i + 11),
        _makeAnimal('touro', 20),
      ];
      // 10 * 1.0 + 8 * 0.5 + 1 * 1.5 = 10.0 + 4.0 + 1.5 = 15.5
      expect(calcTotalUa(animals), closeTo(15.5, 0.001));
    });

    test('calcTotalUa returns 0.0 contribution for unknown category', () {
      final animals = [
        _makeAnimal('unknown_category', 1),
        _makeAnimal('vaca', 2),
      ];
      // unknown=0.0, vaca=1.0 => total=1.0
      expect(calcTotalUa(animals), closeTo(1.0, 0.001));
    });

    test('kUaWeights contains all 7 categories with exact decimal values', () {
      expect(kUaWeights['vaca'], 1.0);
      expect(kUaWeights['novilha'], 0.75);
      expect(kUaWeights['terneiro'], 0.5);
      expect(kUaWeights['terneira'], 0.5);
      expect(kUaWeights['touro'], 1.5);
      expect(kUaWeights['boi'], 1.5);
      expect(kUaWeights['novilho'], 0.75);
      expect(kUaWeights.length, 7);
    });
  });
}
