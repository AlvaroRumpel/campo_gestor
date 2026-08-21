import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/editable_grid.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('gridColumnsFromSchema (GRID-01)', () {
    test('deriva colunas do schema sem as exportOnly', () {
      final cols = gridColumnsFromSchema(lotesSchema);
      expect(cols.map((c) => c.key), ['name', 'paddock_name']);
    });

    test('enum vira dropdown com os enumValues do schema', () {
      final cols = gridColumnsFromSchema(gastosSchema);
      final categoria = cols.firstWhere((c) => c.key == 'category');
      expect(categoria.options, isNotNull);
      expect(categoria.options!['manutencao'], 'Manutenção');
    });

    test('override substitui a coluna gerada e readOnly desliga edição', () {
      final cols = gridColumnsFromSchema(
        piquetesSchema,
        overrides: {
          'name': const GridColumn(key: 'name', label: 'X', width: 50),
        },
        readOnly: {'area_ha'},
        flexKey: 'ua_capacity',
      );
      expect(cols.firstWhere((c) => c.key == 'name').label, 'X');
      expect(cols.firstWhere((c) => c.key == 'area_ha').editable, isFalse);
      expect(cols.firstWhere((c) => c.key == 'ua_capacity').flex, isTrue);
    });

    test('tipos numéricos e data saem mono', () {
      final cols = gridColumnsFromSchema(gastosSchema);
      expect(cols.firstWhere((c) => c.key == 'amount').mono, isTrue);
      expect(cols.firstWhere((c) => c.key == 'expense_date').mono, isTrue);
      expect(cols.firstWhere((c) => c.key == 'description').mono, isFalse);
    });
  });
}
