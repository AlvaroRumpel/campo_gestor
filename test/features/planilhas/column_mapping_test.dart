import 'package:campo_gestor/features/planilhas/data/column_mapping.dart';
import 'package:campo_gestor/features/planilhas/domain/sheet_schema.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('save/load por entidade + cabeçalhos', () async {
    final store = ColumnMappingStore();
    await store.save(
      SheetEntity.animais,
      ['Brinco', 'Categ.'],
      {0: 'number', 1: 'category'},
    );
    expect(
      await store.load(SheetEntity.animais, ['Brinco', 'Categ.']),
      {0: 'number', 1: 'category'},
    );
    expect(await store.load(SheetEntity.animais, ['Brinco', 'Cat']), isNull);
    expect(await store.load(SheetEntity.doses, ['Brinco', 'Categ.']), isNull);
  });

  test('cabeçalho normalizado: acento/caixa não muda a chave', () async {
    final store = ColumnMappingStore();
    await store.save(SheetEntity.animais, ['Raça'], {0: 'breed'});
    expect(await store.load(SheetEntity.animais, ['raca']), {0: 'breed'});
  });
}
