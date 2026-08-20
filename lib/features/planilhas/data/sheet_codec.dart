// Codec de planilhas: xlsx/csv → tabela de strings; tabela → bytes xlsx.
//
// Tudo vira String na leitura — a tipagem acontece depois, no validador do
// import (`parseCell`), guiada pelo SheetSchema. Datas do xlsx são
// normalizadas para dd/MM/yyyy, o mesmo formato aceito no CSV.
import 'dart:convert';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';

class SheetTable {
  const SheetTable({required this.headers, required this.rows});
  final List<String> headers;
  final List<List<String>> rows;
}

final _brDate = DateFormat('dd/MM/yyyy');

/// Despacha por extensão. Lança [FormatException] com mensagem pt-BR para
/// formatos não suportados.
SheetTable decodeSheet(String fileName, Uint8List bytes) {
  final ext = fileName.toLowerCase().split('.').last;
  switch (ext) {
    case 'csv':
      return parseCsv(utf8.decode(bytes, allowMalformed: true));
    case 'xlsx':
      return parseXlsx(bytes);
    default:
      throw FormatException('Formato não suportado: .$ext (use .xlsx ou .csv)');
  }
}

/// CSV com detecção de separador (`;` do Excel pt-BR ou `,`), BOM UTF-8 e
/// aspas duplas. Linha 1 = cabeçalho; linhas em branco são ignoradas; linhas
/// curtas são completadas com '' até a largura do cabeçalho.
SheetTable parseCsv(String text) {
  var src = text;
  if (src.startsWith('﻿')) src = src.substring(1);
  final lines = const LineSplitter()
      .convert(src)
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return const SheetTable(headers: [], rows: []);

  final sep = lines.first.split(';').length >= lines.first.split(',').length
      ? ';'
      : ',';

  List<String> split(String line) {
    final out = <String>[];
    final buf = StringBuffer();
    var inQuotes = false;
    for (var i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (c == sep && !inQuotes) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(c);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  final headers = split(lines.first);
  final rows = lines.skip(1).map(split).map((r) {
    if (r.length < headers.length) {
      return [...r, ...List.filled(headers.length - r.length, '')];
    }
    return r.take(headers.length).toList();
  }).toList();
  return SheetTable(headers: headers, rows: rows);
}

String _cellToString(Data? cell) {
  final v = cell?.value;
  if (v == null) return '';
  return switch (v) {
    DateCellValue d => _brDate.format(DateTime(d.year, d.month, d.day)),
    DateTimeCellValue d => _brDate.format(DateTime(d.year, d.month, d.day)),
    IntCellValue i => i.value.toString(),
    DoubleCellValue d => d.value == d.value.roundToDouble()
        ? d.value.toInt().toString()
        : d.value.toString().replaceAll('.', ','),
    TextCellValue t => t.value.toString(),
    BoolCellValue b => b.value ? 'sim' : 'não',
    _ => v.toString(),
  };
}

/// Lê a primeira aba do xlsx. Linha 1 = cabeçalho (colunas vazias à direita
/// são descartadas); linhas totalmente vazias são ignoradas.
SheetTable parseXlsx(Uint8List bytes) {
  final book = Excel.decodeBytes(bytes);
  if (book.tables.isEmpty) return const SheetTable(headers: [], rows: []);
  final sheet = book.tables.values.first;
  final all = sheet.rows.map((r) => r.map(_cellToString).toList()).toList();
  final nonEmpty = all.where((r) => r.any((c) => c.isNotEmpty)).toList();
  if (nonEmpty.isEmpty) return const SheetTable(headers: [], rows: []);

  final headers = nonEmpty.first.map((h) => h.trim()).toList();
  while (headers.isNotEmpty && headers.last.isEmpty) {
    headers.removeLast();
  }
  final rows = nonEmpty.skip(1).map((r) {
    if (r.length < headers.length) {
      return [...r, ...List.filled(headers.length - r.length, '')];
    }
    return r.take(headers.length).toList();
  }).toList();
  return SheetTable(headers: headers, rows: rows);
}

/// Gera um .xlsx de uma aba. Tipos preservados: int, double, DateTime (data
/// pura); o resto vira texto.
Uint8List encodeXlsx({
  required String sheetName,
  required List<String> headers,
  required List<List<Object?>> rows,
}) {
  final book = Excel.createExcel();
  final defaultName = book.getDefaultSheet()!;
  if (defaultName != sheetName) {
    book.rename(defaultName, sheetName);
  }
  final sheet = book[sheetName];
  sheet.appendRow([for (final h in headers) TextCellValue(h)]);
  for (final r in rows) {
    sheet.appendRow([
      for (final v in r)
        switch (v) {
          null => TextCellValue(''),
          final int i => IntCellValue(i),
          final double d => DoubleCellValue(d),
          final DateTime dt =>
            DateCellValue(year: dt.year, month: dt.month, day: dt.day),
          _ => TextCellValue(v.toString()),
        },
    ]);
  }
  return Uint8List.fromList(book.encode()!);
}
