import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:campo_gestor/features/planilhas/presentation/editable_grid.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseClipboardTsv', () {
    expect(parseClipboardTsv('a\tb\r\nc\td\n'), [
      ['a', 'b'],
      ['c', 'd'],
    ]);
    expect(parseClipboardTsv(''), isEmpty);
  });

  testWidgets('editar célula marca dirty e Salvar envia só mudanças',
      (tester) async {
    List<GridChange>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableGrid(
          columns: const [
            GridColumn(key: 'number', label: 'Nº', width: 80, editable: false),
            GridColumn(key: 'breed', label: 'Raça', width: 200),
          ],
          rows: const [
            GridRow(id: 'a', values: {'number': 1, 'breed': 'Nelore'}),
            GridRow(id: 'b', values: {'number': 2, 'breed': 'Angus'}),
          ],
          onSave: (c) async => saved = c,
        ),
      ),
    ));
    // Barra de salvar só aparece com dirty.
    expect(find.text('Salvar alterações'), findsNothing);

    await tester.tap(find.text('Angus'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Brangus');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    expect(find.textContaining('1 célula'), findsOneWidget);
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(saved, isNotNull);
    expect(saved!.single.rowId, 'b');
    expect(saved!.single.values, {'breed': 'Brangus'});
    // Após salvar, dirty limpa.
    expect(find.text('Salvar alterações'), findsNothing);
  });

  testWidgets('validator bloqueia Salvar e mostra erro', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableGrid(
          columns: const [
            GridColumn(
              key: 'ecc',
              label: 'ECC',
              width: 120,
              type: SheetColumnType.integer,
            ),
          ],
          rows: const [
            GridRow(id: 'a', values: {'ecc': 3}),
          ],
          validator: (k, v, _) =>
              k == 'ecc' && v is int && (v < 1 || v > 5)
                  ? 'ECC deve ser de 1 a 5'
                  : null,
          onSave: (c) async {},
        ),
      ),
    ));
    await tester.tap(find.text('3'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), '9');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();

    final btn = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Salvar alterações'));
    expect(btn.onPressed, isNull);
    expect(find.textContaining('ECC deve ser de 1 a 5'), findsOneWidget);
  });

  testWidgets('Descartar reverte edições', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableGrid(
          columns: const [
            GridColumn(key: 'breed', label: 'Raça', width: 200),
          ],
          rows: const [
            GridRow(id: 'a', values: {'breed': 'Nelore'}),
          ],
          onSave: (c) async {},
        ),
      ),
    ));
    await tester.tap(find.text('Nelore'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'Angus');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Angus'), findsOneWidget);

    await tester.tap(find.text('Descartar'));
    await tester.pump();
    expect(find.text('Nelore'), findsOneWidget);
    expect(find.text('Salvar alterações'), findsNothing);
  });

  testWidgets('dropdown de enum edita via options', (tester) async {
    List<GridChange>? saved;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableGrid(
          columns: const [
            GridColumn(
              key: 'category',
              label: 'Categoria',
              width: 200,
              type: SheetColumnType.enumeration,
              options: {'vaca': 'Vaca', 'touro': 'Touro'},
            ),
          ],
          rows: const [
            GridRow(id: 'a', values: {'category': 'vaca'}),
          ],
          onSave: (c) async => saved = c,
        ),
      ),
    ));
    await tester.tap(find.text('Vaca'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Touro').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salvar alterações'));
    await tester.pumpAndSettle();
    expect(saved!.single.values, {'category': 'touro'});
  });

  testWidgets('coluna com suggestions mostra search-select ao editar',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: EditableGrid(
          columns: const [
            GridColumn(
              key: 'breed',
              label: 'Raça',
              width: 300,
              suggestions: ['Nelore', 'Angus', 'Brangus'],
            ),
          ],
          rows: const [
            GridRow(id: 'a', values: {'breed': null}),
          ],
          onSave: (c) async {},
        ),
      ),
    ));
    await tester.tap(find.text('—'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'an');
    await tester.pump();
    // filtra: Angus e Brangus casam "an"; Nelore não
    expect(find.text('Angus'), findsOneWidget);
    expect(find.text('Brangus'), findsOneWidget);
    expect(find.text('Nelore'), findsNothing);
    // clicar na sugestão comita o valor
    await tester.tap(find.text('Angus'));
    await tester.pump();
    expect(find.textContaining('1 célula'), findsOneWidget);
  });
}
