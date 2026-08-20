import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/lotes/data/lote_model.dart';
import 'package:campo_gestor/features/planilhas/presentation/animais_grid_view.dart';
import 'package:campo_gestor/features/planilhas/presentation/editable_grid.dart';
import 'package:flutter_test/flutter_test.dart';

AnimalWithContext _aw(String id, int number, String category, String lotId) =>
    AnimalWithContext(
      animal: Animal(
        id: id,
        propertyId: 'p1',
        lotId: lotId,
        category: category,
        number: number,
        createdAt: DateTime(2026),
      ),
      lotName: 'Lote 01',
      paddockId: 'pad1',
      paddockName: 'Piquete Norte',
    );

void main() {
  final lots = [
    Lot(
      id: 'l1',
      propertyId: 'p1',
      paddockId: 'pad1',
      name: 'Lote 01',
      createdAt: DateTime(2026),
    ),
    Lot(
      id: 'l2',
      propertyId: 'p1',
      paddockId: 'pad1',
      name: 'Lote 02',
      createdAt: DateTime(2026),
    ),
  ];
  final animals = [
    _aw('a', 1021, 'vaca', 'l1'),
    _aw('b', 1022, 'novilha', 'l1'),
  ];

  test('mudança simples inclui number e category do animal', () {
    final rows = animalChangesToRows(
      [
        const GridChange(rowId: 'a', values: {'breed': 'Angus'}),
      ],
      animals,
      lots,
    );
    expect(rows.single, {
      'number': 1021,
      'category': 'vaca',
      'breed': 'Angus',
    });
  });

  test('mudança de lote resolve lot_id → lot_name', () {
    final rows = animalChangesToRows(
      [
        const GridChange(rowId: 'b', values: {'lot_id': 'l2'}),
      ],
      animals,
      lots,
    );
    expect(rows.single, {
      'number': 1022,
      'category': 'novilha',
      'lot_name': 'Lote 02',
    });
  });

  test('mudança de categoria usa o novo valor', () {
    final rows = animalChangesToRows(
      [
        const GridChange(
          rowId: 'a',
          values: {'category': 'touro', 'body_condition': 4},
        ),
      ],
      animals,
      lots,
    );
    expect(rows.single, {
      'number': 1021,
      'category': 'touro',
      'body_condition': 4,
    });
  });
}
