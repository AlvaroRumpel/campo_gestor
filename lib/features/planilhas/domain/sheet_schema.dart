// SheetSchema — fonte única de colunas por entidade. Gera: cabeçalho do
// export, alvos do passo "mapear colunas" do import, colunas da grade
// editável e a planilha-modelo. Campo novo = 1 SheetColumn aqui.
import '../../animais/data/animal_constants.dart';
import '../../gastos/data/expense_constants.dart';

enum SheetEntity { animais, doses, sanitario, dg, lotes, piquetes, gastos }

enum SheetColumnType { text, integer, decimal, date, enumeration }

class SheetColumn {
  const SheetColumn({
    required this.key,
    required this.label,
    this.type = SheetColumnType.text,
    this.required = false,
    this.enumValues = const {},
    this.aliases = const [],
    this.editable = true,
    this.readOnlyWhenExisting = false,
    this.exportOnly = false,
  });

  /// Key = nome do campo no payload das RPCs bulk (snake_case).
  final String key;
  final String label;
  final SheetColumnType type;
  final bool required;

  /// chave interna → label pt-BR; import aceita ambos.
  final Map<String, String> enumValues;

  /// Cabeçalhos alternativos (já normalizados por [normalizeHeader] na
  /// comparação) vistos em planilhas de outros softwares.
  final List<String> aliases;
  final bool editable;
  final bool readOnlyWhenExisting;

  /// Sai no export mas não participa de import nem de edição (derivado).
  final bool exportOnly;
}

class SheetSchema {
  const SheetSchema({
    required this.entity,
    required this.title,
    required this.sheetName,
    required this.columns,
    this.templateExamples = const [],
  });

  final SheetEntity entity;
  final String title;
  final String sheetName;
  final List<SheetColumn> columns;
  final List<List<Object?>> templateExamples;

  List<SheetColumn> get importColumns =>
      columns.where((c) => !c.exportOnly).toList();
  List<SheetColumn> get requiredColumns =>
      importColumns.where((c) => c.required).toList();
  SheetColumn? byKey(String key) =>
      columns.where((c) => c.key == key).firstOrNull;
  List<String> get importHeaders => importColumns.map((c) => c.label).toList();
  List<List<Object?>> templateRows() => templateExamples;
}

const animaisSchema = SheetSchema(
  entity: SheetEntity.animais,
  title: 'Animais',
  sheetName: 'Animais',
  columns: [
    SheetColumn(
      key: 'number',
      label: 'Nº',
      type: SheetColumnType.integer,
      aliases: [
        'numero',
        'n',
        'n do animal',
        'numero do animal',
        'brinco',
        'identificacao',
        'id animal',
      ],
      readOnlyWhenExisting: true,
    ),
    SheetColumn(
      key: 'category',
      label: 'Categoria',
      type: SheetColumnType.enumeration,
      required: true,
      enumValues: kCategoryLabels,
      aliases: ['categ', 'cat', 'classe'],
    ),
    SheetColumn(key: 'breed', label: 'Raça', aliases: ['raca']),
    SheetColumn(
      key: 'body_condition',
      label: 'ECC',
      type: SheetColumnType.integer,
      aliases: [
        'ecc 15',
        'escore',
        'escore corporal',
        'condicao corporal',
        'cc',
      ],
    ),
    SheetColumn(
      key: 'lot_name',
      label: 'Lote',
      required: true,
      aliases: ['nome do lote', 'grupo'],
    ),
    SheetColumn(
      key: 'observation',
      label: 'Observação',
      aliases: ['obs', 'observacao', 'observacoes', 'notas'],
    ),
    SheetColumn(key: 'paddock_name', label: 'Piquete', exportOnly: true),
    SheetColumn(
      key: 'ua',
      label: 'UA',
      type: SheetColumnType.decimal,
      exportOnly: true,
    ),
  ],
  templateExamples: [
    [1001, 'Vaca', 'Nelore', 3, 'Lote 01', ''],
    [null, 'Novilha', 'Angus', 4, 'Lote 01', 'número gerado ao importar'],
  ],
);

const dosesSchema = SheetSchema(
  entity: SheetEntity.doses,
  title: 'Doses',
  sheetName: 'Doses',
  columns: [
    SheetColumn(
      key: 'name',
      label: 'Nome',
      required: true,
      aliases: ['dose', 'produto', 'vacina', 'medicamento', 'nome da dose'],
    ),
    SheetColumn(
      key: 'active_ingredient',
      label: 'Princípio ativo',
      aliases: ['principio ativo', 'principio', 'ativo'],
    ),
    SheetColumn(
      key: 'dosage_per_kg',
      label: 'Dosagem (ml/kg)',
      type: SheetColumnType.decimal,
      required: true,
      aliases: ['dosagem', 'dosagem por kg', 'ml kg', 'mlkg', 'dose por kg'],
    ),
    SheetColumn(
      key: 'cost_per_kg',
      label: r'Custo (R$/kg)',
      type: SheetColumnType.decimal,
      aliases: ['custo', 'custo por kg', 'preco', 'r kg', 'rkg', 'valor'],
    ),
  ],
  templateExamples: [
    ['Ivermectina 1%', 'ivermectina', 0.02, 0.5],
    ['Febre aftosa', '', 0.005, 0.3],
  ],
);

const sanitarioSchema = SheetSchema(
  entity: SheetEntity.sanitario,
  title: 'Aplicações sanitárias',
  sheetName: 'Aplicacoes',
  columns: [
    SheetColumn(
      key: 'animal_number',
      label: 'Nº do animal',
      type: SheetColumnType.integer,
      required: true,
      aliases: ['numero', 'n', 'numero do animal', 'brinco', 'animal'],
    ),
    SheetColumn(
      key: 'dose_name',
      label: 'Dose',
      required: true,
      aliases: ['produto', 'vacina', 'medicamento'],
    ),
    SheetColumn(
      key: 'applied_at',
      label: 'Data',
      type: SheetColumnType.date,
      required: true,
      aliases: ['data da aplicacao', 'aplicado em', 'dt'],
    ),
    SheetColumn(
      key: 'notes',
      label: 'Observação',
      aliases: ['obs', 'observacao', 'notas'],
    ),
    SheetColumn(key: 'lot_name', label: 'Lote', exportOnly: true),
    SheetColumn(key: 'category', label: 'Categoria', exportOnly: true),
  ],
  templateExamples: [
    [1001, 'Ivermectina 1%', '19/08/2026', ''],
    [1002, 'Ivermectina 1%', '19/08/2026', ''],
  ],
);

const dgSchema = SheetSchema(
  entity: SheetEntity.dg,
  title: 'Diagnóstico de gestação',
  sheetName: 'DG',
  columns: [
    SheetColumn(
      key: 'animal_number',
      label: 'Nº do animal',
      type: SheetColumnType.integer,
      required: true,
      aliases: ['numero', 'n', 'numero do animal', 'brinco', 'animal'],
    ),
    SheetColumn(
      key: 'result',
      label: 'Resultado',
      type: SheetColumnType.enumeration,
      required: true,
      enumValues: {
        'pregnant': 'Prenhe',
        'not_pregnant': 'Vazia',
        'doubtful': 'Duvidosa',
      },
      aliases: ['dg', 'diagnostico', 'resultado dg', 'status'],
    ),
    SheetColumn(
      key: 'exam_date',
      label: 'Data do exame',
      type: SheetColumnType.date,
      required: true,
      aliases: ['data', 'data dg', 'exame'],
    ),
    SheetColumn(
      key: 'observation',
      label: 'Observação',
      aliases: ['obs', 'observacao', 'notas'],
    ),
    SheetColumn(key: 'category', label: 'Categoria', exportOnly: true),
  ],
  templateExamples: [
    [1001, 'Prenhe', '19/08/2026', ''],
    [1002, 'Vazia', '19/08/2026', ''],
  ],
);

const lotesSchema = SheetSchema(
  entity: SheetEntity.lotes,
  title: 'Lotes',
  sheetName: 'Lotes',
  columns: [
    SheetColumn(
      key: 'name',
      label: 'Nome',
      required: true,
      aliases: ['lote', 'nome do lote', 'grupo'],
    ),
    SheetColumn(
      key: 'paddock_name',
      label: 'Piquete',
      required: true,
      aliases: ['piquete', 'nome do piquete', 'pasto', 'potreiro'],
    ),
    SheetColumn(
      key: 'animal_count',
      label: 'Animais',
      type: SheetColumnType.integer,
      exportOnly: true,
    ),
    SheetColumn(
      key: 'ua',
      label: 'UA',
      type: SheetColumnType.decimal,
      exportOnly: true,
    ),
  ],
  templateExamples: [
    ['Lote 01', 'Piquete Sul'],
    ['Terneiros', 'Chácara'],
  ],
);

const piquetesSchema = SheetSchema(
  entity: SheetEntity.piquetes,
  title: 'Piquetes',
  sheetName: 'Piquetes',
  columns: [
    SheetColumn(
      key: 'name',
      label: 'Nome',
      required: true,
      aliases: ['piquete', 'nome do piquete', 'pasto', 'potreiro'],
    ),
    SheetColumn(
      key: 'area_ha',
      label: 'Área (ha)',
      type: SheetColumnType.decimal,
      required: true,
      aliases: ['area', 'hectares', 'ha', 'area ha'],
    ),
    SheetColumn(
      key: 'ua_capacity',
      label: 'Capacidade (UA)',
      type: SheetColumnType.decimal,
      required: true,
      aliases: ['capacidade', 'ua', 'lotacao', 'capacidade ua'],
    ),
  ],
  templateExamples: [
    ['Piquete Sul', 12.5, 15],
    ['Chácara', 8, 10],
  ],
);

const gastosSchema = SheetSchema(
  entity: SheetEntity.gastos,
  title: 'Gastos',
  sheetName: 'Gastos',
  columns: [
    SheetColumn(
      key: 'expense_date',
      label: 'Data',
      type: SheetColumnType.date,
      required: true,
      aliases: ['data do gasto', 'dt', 'data'],
    ),
    SheetColumn(
      key: 'paddock_name',
      label: 'Piquete',
      required: true,
      aliases: ['piquete', 'nome do piquete'],
    ),
    SheetColumn(
      key: 'category',
      label: 'Categoria',
      type: SheetColumnType.enumeration,
      required: true,
      enumValues: kExpenseCategoryLabels,
      aliases: ['categ', 'tipo', 'tipo de gasto'],
    ),
    SheetColumn(
      key: 'amount',
      label: r'Valor (R$)',
      type: SheetColumnType.decimal,
      required: true,
      aliases: ['valor', 'custo', 'r', 'total'],
    ),
    SheetColumn(
      key: 'description',
      label: 'Descrição',
      aliases: ['desc', 'descricao', 'obs', 'observacao'],
    ),
  ],
  templateExamples: [
    ['19/08/2026', 'Piquete Sul', 'Manutenção', 350.0, 'Conserto de cerca'],
    ['20/08/2026', 'Chácara', 'Ração/Suplementação', 1200.5, ''],
  ],
);

SheetSchema schemaFor(SheetEntity e) => switch (e) {
      SheetEntity.animais => animaisSchema,
      SheetEntity.doses => dosesSchema,
      SheetEntity.sanitario => sanitarioSchema,
      SheetEntity.dg => dgSchema,
      SheetEntity.lotes => lotesSchema,
      SheetEntity.piquetes => piquetesSchema,
      SheetEntity.gastos => gastosSchema,
    };
