import 'dart:typed_data';

import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('parseCsv', () {
    test('detecta ; e remove BOM', () {
      final t = parseCsv('﻿Nº;Categoria\n1;Vaca\n2;Touro\n');
      expect(t.headers, ['Nº', 'Categoria']);
      expect(t.rows, [
        ['1', 'Vaca'],
        ['2', 'Touro'],
      ]);
    });

    test('detecta , e respeita aspas', () {
      final t = parseCsv('a,b\n"x, y",2\n');
      expect(t.rows.single, ['x, y', '2']);
    });

    test('ignora linhas vazias e normaliza largura', () {
      final t = parseCsv('a;b\n\n1\n\n');
      expect(t.rows, [
        ['1', ''],
      ]);
    });
  });

  test('xlsx round-trip', () {
    final bytes = encodeXlsx(
      sheetName: 'Animais',
      headers: ['Nº', 'Raça', 'Data'],
      rows: [
        [1, 'Nelore', DateTime(2026, 8, 19)],
        [2, null, null],
      ],
    );
    final t = parseXlsx(Uint8List.fromList(bytes));
    expect(t.headers, ['Nº', 'Raça', 'Data']);
    expect(t.rows[0], ['1', 'Nelore', '19/08/2026']);
    expect(t.rows[1], ['2', '', '']);
  });

  test('decodeSheet despacha por extensão', () {
    final csv = Uint8List.fromList('a;b\n1;2'.codeUnits);
    expect(decodeSheet('x.CSV', csv).rows, [
      ['1', '2'],
    ]);
    expect(() => decodeSheet('x.txt', Uint8List(0)), throwsFormatException);
  });
}
