import 'package:campo_gestor/features/animais/data/animal_model.dart';
import 'package:campo_gestor/features/planilhas/presentation/sanitario_grade_screen.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:flutter_test/flutter_test.dart';

Animal _a(String id, int number) => Animal(
      id: id,
      propertyId: 'p1',
      lotId: 'l1',
      category: 'vaca',
      number: number,
      createdAt: DateTime(2026),
    );

void main() {
  final animals = [_a('a', 1021), _a('b', 1022), _a('c', 1023)];
  final doses = [
    Dose(
      id: 'd1',
      propertyId: 'p1',
      name: 'Ivermectina',
      dosagePerKg: 0.02,
      createdAt: DateTime(2026),
    ),
    Dose(
      id: 'd2',
      propertyId: 'p1',
      name: 'Aftosa',
      dosagePerKg: 0.005,
      createdAt: DateTime(2026),
    ),
  ];

  test('gradeToRows converte marcas em linhas do RPC', () {
    final rows = gradeToRows(
      marks: {
        'd1': {'a', 'b'},
        'd2': {'c'},
      },
      animals: animals,
      doses: doses,
      date: DateTime(2026, 8, 19),
    );
    expect(rows, hasLength(3));
    expect(
      rows,
      containsAll([
        {
          'animal_number': 1021,
          'dose_name': 'Ivermectina',
          'applied_at': '2026-08-19',
        },
        {
          'animal_number': 1022,
          'dose_name': 'Ivermectina',
          'applied_at': '2026-08-19',
        },
        {
          'animal_number': 1023,
          'dose_name': 'Aftosa',
          'applied_at': '2026-08-19',
        },
      ]),
    );
  });

  test('gradeToRows ignora dose sem marcas e animal desconhecido', () {
    final rows = gradeToRows(
      marks: {
        'd1': {'zzz'},
        'd2': <String>{},
      },
      animals: animals,
      doses: doses,
      date: DateTime(2026, 8, 19),
    );
    expect(rows, isEmpty);
  });
}
