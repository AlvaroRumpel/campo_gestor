// Validação client-side do import: SheetTable + mapeamento → ImportRow[]
// com status create/update/error e mensagens pt-BR. O servidor revalida
// tudo nas RPCs bulk — aqui é o preview do passo 3.
import '../data/sheet_codec.dart';
import 'header_matcher.dart';
import 'sheet_schema.dart';

enum ImportRowStatus { create, update, error }

class ImportRow {
  const ImportRow({
    required this.index,
    required this.values,
    required this.status,
    required this.errors,
  });

  /// Linha no arquivo (1-based; linha 1 é o cabeçalho, dados começam em 2).
  final int index;

  /// key do SheetColumn → valor tipado (DateTime para datas, chave para enum).
  /// Célula vazia ou coluna não mapeada = key ausente.
  final Map<String, dynamic> values;
  final ImportRowStatus status;
  final List<String> errors;
}

/// Dados da propriedade carregados dos providers, usados nas checagens de
/// existência (lote, dose, animal, membro do IATF).
class ImportContext {
  const ImportContext({
    this.existingAnimalNumbers = const {},
    this.lotNamesLower = const {},
    this.doseNamesLower = const {},
    this.iatfAnimalNumbers = const {},
    this.paddockNamesLower = const {},
  });
  final Set<int> existingAnimalNumbers;
  final Set<String> lotNamesLower;
  final Set<String> doseNamesLower;
  final Set<int> iatfAnimalNumbers;
  final Set<String> paddockNamesLower;
}

final _excelEpoch = DateTime(1899, 12, 30);

/// Converte o texto cru da célula para o tipo da coluna. Lança
/// [FormatException] com mensagem pt-BR pronta para o preview.
Object? parseCell(SheetColumn col, String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  switch (col.type) {
    case SheetColumnType.text:
      return s;
    case SheetColumnType.integer:
      final v = int.tryParse(s.split(',').first.split('.').first);
      if (v == null) throw FormatException('${col.label} deve ser número inteiro');
      return v;
    case SheetColumnType.decimal:
      final v = double.tryParse(s.replaceAll('.', '').replaceAll(',', '.')) ??
          double.tryParse(s);
      if (v == null) throw FormatException('${col.label} deve ser número');
      return v;
    case SheetColumnType.date:
      final br = RegExp(r'^(\d{1,2})/(\d{1,2})/(\d{4})$').firstMatch(s);
      if (br != null) {
        final mo = int.parse(br.group(2)!);
        final d = DateTime(
            int.parse(br.group(3)!), mo, int.parse(br.group(1)!));
        if (d.month != mo) throw FormatException('${col.label}: data inválida');
        return d;
      }
      final iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})').firstMatch(s);
      if (iso != null) {
        final mo = int.parse(iso.group(2)!);
        final d = DateTime(
            int.parse(iso.group(1)!), mo, int.parse(iso.group(3)!));
        if (d.month != mo) throw FormatException('${col.label}: data inválida');
        return d;
      }
      // Serial Excel (dias desde 30/12/1899) — faixa ~1954..2119.
      final serial = int.tryParse(s);
      if (serial != null && serial > 20000 && serial < 80000) {
        return _excelEpoch.add(Duration(days: serial));
      }
      throw FormatException('${col.label}: use dd/MM/yyyy');
    case SheetColumnType.enumeration:
      final n = normalizeHeader(s);
      for (final e in col.enumValues.entries) {
        if (normalizeHeader(e.key) == n || normalizeHeader(e.value) == n) {
          return e.key;
        }
      }
      throw FormatException(
          '${col.label} "$s" inválido · use ${col.enumValues.values.join(', ')}');
  }
}

List<ImportRow> validateRows({
  required SheetSchema schema,
  required SheetTable table,
  required Map<int, String> mapping,
  required ImportContext ctx,
}) {
  final out = <ImportRow>[];
  for (var r = 0; r < table.rows.length; r++) {
    final raw = table.rows[r];
    final values = <String, dynamic>{};
    final errors = <String>[];

    for (final e in mapping.entries) {
      final col = schema.byKey(e.value);
      if (col == null || e.key >= raw.length) continue;
      try {
        final v = parseCell(col, raw[e.key]);
        if (v != null) values[col.key] = v;
      } on FormatException catch (ex) {
        errors.add(ex.message);
      }
    }

    final isExistingAnimal = schema.entity == SheetEntity.animais &&
        _isExistingAnimal(values, ctx);
    final isExistingByName = switch (schema.entity) {
      SheetEntity.lotes => ctx.lotNamesLower
          .contains((values['name'] as String?)?.toLowerCase() ?? ''),
      SheetEntity.piquetes => ctx.paddockNamesLower
          .contains((values['name'] as String?)?.toLowerCase() ?? ''),
      _ => false,
    };

    for (final c in schema.requiredColumns) {
      if (values.containsKey(c.key)) continue;
      // Animal existente atualiza campos presentes — lote não é exigido.
      if (isExistingAnimal && c.key == 'lot_name') continue;
      // Lote/piquete existentes: só os campos presentes são atualizados.
      if (isExistingByName && c.key != 'name') continue;
      // Categoria de animal existente também pode faltar (mantém a atual)?
      // Não — RPC exige categoria sempre; preview segue a RPC.
      if (errors.any((m) => m.startsWith(c.label))) continue;
      errors.add('${c.label} é obrigatório');
    }

    var status = ImportRowStatus.create;
    switch (schema.entity) {
      case SheetEntity.animais:
        final ecc = values['body_condition'] as int?;
        if (ecc != null && (ecc < 1 || ecc > 5)) {
          errors.add('ECC deve ser de 1 a 5');
        }
        final lot = values['lot_name'] as String?;
        if (lot != null && !ctx.lotNamesLower.contains(lot.toLowerCase())) {
          errors.add('Lote "$lot" não existe');
        }
        if (isExistingAnimal) status = ImportRowStatus.update;
      case SheetEntity.doses:
        final d = values['dosage_per_kg'] as double?;
        if (d != null && d <= 0) errors.add('Dosagem deve ser maior que zero');
        final name = values['name'] as String?;
        if (name != null && ctx.doseNamesLower.contains(name.toLowerCase())) {
          status = ImportRowStatus.update;
        }
      case SheetEntity.sanitario:
        final n = values['animal_number'] as int?;
        if (n != null && !ctx.existingAnimalNumbers.contains(n)) {
          errors.add('Animal nº $n não encontrado');
        }
        final dose = values['dose_name'] as String?;
        if (dose != null && !ctx.doseNamesLower.contains(dose.toLowerCase())) {
          errors.add('Dose "$dose" não existe');
        }
      case SheetEntity.dg:
        final n = values['animal_number'] as int?;
        if (n != null && !ctx.iatfAnimalNumbers.contains(n)) {
          errors.add('Animal nº $n não está neste IATF');
        }
      case SheetEntity.lotes:
        final paddock = values['paddock_name'] as String?;
        if (paddock != null &&
            !ctx.paddockNamesLower.contains(paddock.toLowerCase())) {
          errors.add('Piquete "$paddock" não existe');
        }
        final name = values['name'] as String?;
        if (name != null && ctx.lotNamesLower.contains(name.toLowerCase())) {
          status = ImportRowStatus.update;
        }
      case SheetEntity.piquetes:
        final area = values['area_ha'] as double?;
        if (area != null && area <= 0) {
          errors.add('Área deve ser maior que zero');
        }
        final cap = values['ua_capacity'] as double?;
        if (cap != null && cap <= 0) {
          errors.add('Capacidade deve ser maior que zero');
        }
        final name = values['name'] as String?;
        if (name != null &&
            ctx.paddockNamesLower.contains(name.toLowerCase())) {
          status = ImportRowStatus.update;
        }
      case SheetEntity.gastos:
        final paddock = values['paddock_name'] as String?;
        if (paddock != null &&
            !ctx.paddockNamesLower.contains(paddock.toLowerCase())) {
          errors.add('Piquete "$paddock" não existe');
        }
        final amount = values['amount'] as double?;
        if (amount != null && amount <= 0) {
          errors.add('Valor deve ser maior que zero');
        }
    }

    if (errors.isNotEmpty) status = ImportRowStatus.error;
    out.add(ImportRow(
      index: r + 2,
      values: values,
      status: status,
      errors: errors,
    ));
  }
  return out;
}

bool _isExistingAnimal(Map<String, dynamic> values, ImportContext ctx) {
  final n = values['number'] as int?;
  return n != null && ctx.existingAnimalNumbers.contains(n);
}
