import 'package:campo_gestor/features/planilhas/domain/header_matcher.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizeHeader remove acento, caixa e pontuação', () {
    expect(normalizeHeader(' Nº do Animal '), 'n do animal');
    expect(normalizeHeader('Raça'), 'raca');
    expect(normalizeHeader('ECC (1-5)'), 'ecc 15');
  });

  test('autoMatch casa aliases de animais', () {
    final m = autoMatch(
      ['Brinco', 'Categ.', 'Raça', 'ECC', 'Lote', 'Peso'],
      animaisSchema,
    );
    expect(m[0], 'number');
    expect(m[1], 'category');
    expect(m[2], 'breed');
    expect(m[3], 'body_condition');
    expect(m[4], 'lot_name');
    expect(m.containsKey(5), false);
  });

  test('autoMatch não repete alvo', () {
    final m = autoMatch(['Número', 'Nº'], animaisSchema);
    expect(m.values.where((v) => v == 'number').length, 1);
  });

  test('schemas têm obrigatórios e enums traduzidos', () {
    expect(
      animaisSchema.requiredColumns.map((c) => c.key),
      containsAll(['category', 'lot_name']),
    );
    expect(animaisSchema.byKey('category')!.enumValues['vaca'], 'Vaca');
    expect(dgSchema.byKey('result')!.enumValues['pregnant'], 'Prenhe');
    expect(
      schemaFor(SheetEntity.doses).importColumns.map((c) => c.key),
      contains('dosage_per_kg'),
    );
    expect(animaisSchema.templateRows().length, 2);
    // exportOnly fica fora do import
    expect(
      animaisSchema.importColumns.map((c) => c.key),
      isNot(contains('ua')),
    );
  });
}
