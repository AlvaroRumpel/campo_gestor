import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';
import 'package:campo_gestor/features/planilhas/domain/import_preview.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const ctx = ImportContext(
    existingAnimalNumbers: {1021},
    lotNamesLower: {'lote 03'},
    doseNamesLower: {'ivermectina'},
    atfAnimalNumbers: {1021},
  );
  const mapping = {0: 'number', 1: 'category', 2: 'body_condition', 3: 'lot_name'};

  test('classifica create/update/error', () {
    const t = SheetTable(headers: ['N', 'Cat', 'ECC', 'Lote'], rows: [
      ['1021', 'Vaca', '3', 'Lote 03'],
      ['1022', 'novilha', '4', 'lote 03'],
      ['1023', 'Bezerro', '3', 'Lote 03'],
      ['1024', 'Vaca', '6', 'Lote 03'],
      ['1025', 'Vaca', '', 'Lote 12'],
      ['', 'Vaca', '', 'Lote 03'],
    ]);
    final rows =
        validateRows(schema: animaisSchema, table: t, mapping: mapping, ctx: ctx);
    expect(rows[0].status, ImportRowStatus.update);
    expect(rows[1].status, ImportRowStatus.create);
    expect(rows[1].values['category'], 'novilha');
    expect(rows[2].errors.single, contains('"Bezerro" inválid'));
    expect(rows[3].errors.single, 'ECC deve ser de 1 a 5');
    expect(rows[4].errors.single, 'Lote "Lote 12" não existe');
    expect(rows[5].status, ImportRowStatus.create);
    expect(rows[5].values.containsKey('number'), false);
    expect(rows[0].index, 2); // linha 1 = cabeçalho
  });

  test('parseCell: data dd/MM/yyyy, ISO e serial Excel', () {
    final col = sanitarioSchema.byKey('applied_at')!;
    expect(parseCell(col, '19/08/2026'), DateTime(2026, 8, 19));
    expect(parseCell(col, '2026-08-19'), DateTime(2026, 8, 19));
    expect(parseCell(col, '46253'), DateTime(2026, 8, 19)); // serial Excel
    expect(() => parseCell(col, 'amanhã'), throwsFormatException);
    expect(() => parseCell(col, '40/13/2026'), throwsFormatException);
  });

  test('parseCell: decimal com vírgula e inteiro', () {
    expect(parseCell(dosesSchema.byKey('dosage_per_kg')!, '0,02'), 0.02);
    expect(parseCell(animaisSchema.byKey('number')!, '1021'), 1021);
    expect(() => parseCell(animaisSchema.byKey('number')!, 'abc'),
        throwsFormatException);
  });

  test('sanitário exige animal e dose existentes', () {
    const t = SheetTable(headers: ['N', 'Dose', 'Data'], rows: [
      ['1021', 'ivermectina', '01/08/2026'],
      ['9999', 'Ivermectina', '01/08/2026'],
      ['1021', 'Aftosa', '01/08/2026'],
    ]);
    final rows = validateRows(
      schema: sanitarioSchema,
      table: t,
      mapping: const {0: 'animal_number', 1: 'dose_name', 2: 'applied_at'},
      ctx: ctx,
    );
    expect(rows[0].status, ImportRowStatus.create);
    expect(rows[1].errors.single, 'Animal nº 9999 não encontrado');
    expect(rows[2].errors.single, 'Dose "Aftosa" não existe');
  });

  test('dg exige animal no ATF e resultado válido', () {
    const t = SheetTable(headers: ['N', 'R', 'D'], rows: [
      ['1021', 'Prenhe', '01/08/2026'],
      ['1022', 'Prenhe', '01/08/2026'],
      ['1021', 'Talvez', '01/08/2026'],
    ]);
    final rows = validateRows(
      schema: dgSchema,
      table: t,
      mapping: const {0: 'animal_number', 1: 'result', 2: 'exam_date'},
      ctx: ctx,
    );
    expect(rows[0].values['result'], 'pregnant');
    expect(rows[1].errors.single, 'Animal nº 1022 não está neste ATF');
    expect(rows[2].errors.single, contains('"Talvez" inválid'));
  });

  test('obrigatório vazio é erro', () {
    const t = SheetTable(headers: ['N', 'Cat', 'ECC', 'Lote'], rows: [
      ['1030', '', '', 'Lote 03'],
    ]);
    final rows =
        validateRows(schema: animaisSchema, table: t, mapping: mapping, ctx: ctx);
    expect(rows.single.errors.single, 'Categoria é obrigatório');
  });

  test('animal existente sem lote mapeado não exige lote', () {
    const t = SheetTable(headers: ['N', 'Cat'], rows: [
      ['1021', 'Vaca'],
    ]);
    final rows = validateRows(
      schema: animaisSchema,
      table: t,
      mapping: const {0: 'number', 1: 'category'},
      ctx: ctx,
    );
    expect(rows.single.status, ImportRowStatus.update);
    expect(rows.single.errors, isEmpty);
  });
}
