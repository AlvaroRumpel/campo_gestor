import 'package:campo_gestor/features/planilhas/data/sheet_codec.dart';
import 'package:campo_gestor/features/planilhas/domain/import_preview.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/import_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('MappingStep bloqueia Revisar sem obrigatórios', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingStep(
          schema: animaisSchema,
          table: const SheetTable(
            headers: ['Brinco', 'Peso'],
            rows: [
              ['1', '400'],
            ],
          ),
          initial: const {0: 'number'},
          autoKeys: const {'number'},
          fileName: 'x.xlsx',
          onBack: () {},
          onNext: (a, b) {},
        ),
      ),
    ));
    final btn = tester
        .widget<FilledButton>(find.widgetWithText(FilledButton, 'Revisar'));
    expect(btn.onPressed, isNull);
    expect(find.textContaining('Categoria'), findsWidgets);
  });

  testWidgets('MappingStep habilita Revisar com obrigatórios mapeados',
      (tester) async {
    Map<int, String>? next;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: MappingStep(
          schema: animaisSchema,
          table: const SheetTable(
            headers: ['Brinco', 'Categ.', 'Lote'],
            rows: [
              ['1', 'Vaca', 'Lote 01'],
            ],
          ),
          initial: const {0: 'number', 1: 'category', 2: 'lot_name'},
          autoKeys: const {'number', 'category', 'lot_name'},
          fileName: 'x.xlsx',
          onBack: () {},
          onNext: (m, _) => next = m,
        ),
      ),
    ));
    await tester.tap(find.widgetWithText(FilledButton, 'Revisar'));
    await tester.pump();
    expect(next, {0: 'number', 1: 'category', 2: 'lot_name'});
  });

  testWidgets('ReviewStep mostra contagens e habilita importar', (tester) async {
    var committed = false;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: ReviewStep(
          schema: animaisSchema,
          mapping: const {0: 'number', 1: 'category'},
          rows: const [
            ImportRow(
              index: 2,
              values: {'number': 1, 'category': 'vaca'},
              status: ImportRowStatus.update,
              errors: [],
            ),
            ImportRow(
              index: 3,
              values: {'number': 2, 'category': 'vaca'},
              status: ImportRowStatus.create,
              errors: [],
            ),
            ImportRow(
              index: 4,
              values: {},
              status: ImportRowStatus.error,
              errors: ['Categoria é obrigatório'],
            ),
          ],
          saving: false,
          serverError: null,
          onBack: () {},
          onCommit: () => committed = true,
        ),
      ),
    ));
    expect(find.text('1'), findsWidgets); // chips de contagem
    await tester.tap(find.widgetWithText(FilledButton, 'Importar 2 válidas'));
    await tester.pump();
    expect(committed, true);
  });
}
