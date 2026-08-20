import 'package:campo_gestor/features/planilhas/presentation/doses_grid_view.dart';
import 'package:campo_gestor/features/planilhas/presentation/editable_grid.dart';
import 'package:campo_gestor/features/sanitario/data/dose_model.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final doses = [
    Dose(
      id: 'd1',
      propertyId: 'p1',
      name: 'Ivermectina',
      dosagePerKg: 0.02,
      createdAt: DateTime(2026),
    ),
  ];

  test('mudança em dose existente leva o nome atual', () {
    final rows = doseChangesToRows(
      [
        const GridChange(rowId: 'd1', values: {'dosage_per_kg': 0.03}),
      ],
      doses,
    );
    expect(rows.single, {'name': 'Ivermectina', 'dosage_per_kg': 0.03});
  });

  test('renomear dose mantém match pelo nome antigo? não — envia nome novo', () {
    // A RPC casa por nome; renomear cria outra dose. Grade bloqueia edição
    // do nome em linha existente — só linhas novas têm nome editável.
    final rows = doseChangesToRows(
      [
        const GridChange(
          rowId: 'new-1',
          values: {'name': 'Aftosa', 'dosage_per_kg': 0.005},
        ),
      ],
      doses,
    );
    expect(rows.single, {'name': 'Aftosa', 'dosage_per_kg': 0.005});
  });
}
