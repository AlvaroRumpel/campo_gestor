import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/export_button.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('exportFileName gera slug + data', () {
    expect(
      exportFileName('animais', 'Fazenda Santa Rita', DateTime(2026, 8, 19)),
      'campo-gestor_animais_fazenda-santa-rita_20260819.xlsx',
    );
    expect(
      exportFileName('doses', 'São João!', DateTime(2026, 1, 2)),
      'campo-gestor_doses_sao-joao_20260102.xlsx',
    );
  });

  test('rowsForExport ordena por schema e traduz enum', () {
    final rows = rowsForExport(animaisSchema, [
      {
        'number': 1,
        'category': 'vaca',
        'lot_name': 'L1',
        'ua': 1.0,
        'paddock_name': 'P',
      },
    ]);
    expect(rows.single, [1, 'Vaca', null, null, 'L1', null, 'P', 1.0]);
  });
}
