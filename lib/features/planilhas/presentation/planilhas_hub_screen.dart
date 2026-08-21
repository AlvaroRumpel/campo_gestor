// Hub Planilhas (/planilhas, fase 14 GRID-03) — todas as entidades da
// fazenda editáveis em grade estilo Excel, com export e import por entidade,
// num único lugar. Grades derivam colunas do SheetSchema (GRID-01); escrita
// só via RPCs bulk_* (convenção do CLAUDE.md).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_repository.dart';
import '../../auth/data/property_repository.dart';
import '../../gastos/data/expense_model.dart';
import '../../gastos/data/expense_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../../sanitario/data/dose_repository.dart';
import '../data/bulk_repository.dart';
import '../domain/sheet_schema.dart';
import 'animais_grid_view.dart';
import 'doses_grid_view.dart';
import 'editable_grid.dart';
import 'export_button.dart';

final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

/// Entidades do hub, na ordem dos chips. Sanitário/DG ficam de fora da
/// edição (aplicações são imutáveis; DG vive no detalhe do IATF) — o hub
/// aponta para as telas próprias.
const _hubEntities = [
  SheetEntity.animais,
  SheetEntity.lotes,
  SheetEntity.piquetes,
  SheetEntity.doses,
  SheetEntity.gastos,
];

class PlanilhasHubScreen extends ConsumerStatefulWidget {
  const PlanilhasHubScreen({super.key});

  @override
  ConsumerState<PlanilhasHubScreen> createState() =>
      _PlanilhasHubScreenState();
}

class _PlanilhasHubScreenState extends ConsumerState<PlanilhasHubScreen> {
  SheetEntity _entity = SheetEntity.animais;

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    // Gastos: proprietário também escreve (D-23); resto é vet-only.
    if (_entity == SheetEntity.gastos) {
      return role == 'veterinarian' || role == 'owner';
    }
    return role == 'veterinarian';
  }

  @override
  Widget build(BuildContext context) {
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final property = currentPropAsync.asData?.value;
    final canEdit = _canEdit(property, membersAsync.asData?.value);
    final schema = schemaFor(_entity);

    return LayoutBuilder(builder: (context, constraints) {
      final isDesktop = constraints.maxWidth >= Breakpoints.rail;
      return Scaffold(
        appBar: const CampoAppBar(title: 'Planilhas'),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
              child: Row(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          for (final e in _hubEntities) ...[
                            ChoiceChip(
                              label: Text(schemaFor(e).title),
                              selected: _entity == e,
                              onSelected: (_) =>
                                  setState(() => _entity = e),
                            ),
                            const SizedBox(width: 8),
                          ],
                        ],
                      ),
                    ),
                  ),
                  if (property != null) ...[
                    _buildExportButton(property),
                    const SizedBox(width: 10),
                    if (canEdit)
                      OutlinedButton.icon(
                        onPressed: () => context
                            .push(AppRoutes.importarFor(_entity.name)),
                        icon: const Icon(Icons.upload_outlined, size: 20),
                        label: const Text('Importar'),
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Text(
                    schema.title,
                    style: const TextStyle(
                        fontSize: 24, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Clique numa célula para editar · Ctrl+V cola do Excel '
                      '· Tab/Enter avançam',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: !isDesktop
                  ? const EmptyState(
                      icon: Icons.grid_on,
                      title: 'Edição em grade é para telas maiores',
                      message:
                          'Use um computador para editar em grade. Export e '
                          'import funcionam por aqui.',
                    )
                  : !canEdit
                      ? const EmptyState(
                          icon: Icons.lock_outline,
                          title: 'Somente leitura',
                          message:
                              'Seu papel nesta fazenda não permite edição em '
                              'massa. Use o botão Exportar.',
                        )
                      : property == null
                          ? const Center(child: CircularProgressIndicator())
                          : _buildGrid(property),
            ),
          ],
        ),
      );
    });
  }

  // -------------------------------------------------------------------
  // Export
  // -------------------------------------------------------------------

  Widget _buildExportButton(SelectedProperty property) {
    final schema = schemaFor(_entity);
    final fileName = exportFileName(_entity.name, property.name);
    switch (_entity) {
      case SheetEntity.animais:
        final animals =
            ref.watch(animalListByPropertyProvider).asData?.value ?? const [];
        return ExportButton(schema: schema, fileName: fileName, rows: [
          for (final aw in animals)
            if (aw.animal.deletedAt == null)
              {
                'number': aw.animal.number,
                'category':
                    kCategoryLabels[aw.animal.category] ?? aw.animal.category,
                'breed': aw.animal.breed,
                'body_condition': aw.animal.bodyCondition,
                'lot_name': aw.lotName,
                'observation': aw.animal.observation,
                'paddock_name': aw.paddockName,
                'ua': kUaWeights[aw.animal.category],
              },
        ]);
      case SheetEntity.lotes:
        final lots = ref
                .watch(loteWithPaddockListByPropertyProvider)
                .asData
                ?.value ??
            const [];
        final animals =
            ref.watch(animalListByPropertyProvider).asData?.value ?? const [];
        return ExportButton(schema: schema, fileName: fileName, rows: [
          for (final l in lots)
            {
              'name': l.lot.name,
              'paddock_name': l.paddockName,
              'animal_count': l.activeAnimalCount,
              'ua': calcTotalUa([
                for (final aw in animals)
                  if (aw.animal.deletedAt == null &&
                      aw.animal.lotId == l.lot.id)
                    aw.animal,
              ]),
            },
        ]);
      case SheetEntity.piquetes:
        final paddocks =
            ref.watch(paddockListProvider).asData?.value ?? const <Paddock>[];
        return ExportButton(schema: schema, fileName: fileName, rows: [
          for (final p in paddocks)
            {
              'name': p.name,
              'area_ha': p.areaHa,
              'ua_capacity': p.uaCapacity,
            },
        ]);
      case SheetEntity.doses:
        final doses =
            ref.watch(doseListByPropertyProvider).asData?.value ?? const [];
        return ExportButton(schema: schema, fileName: fileName, rows: [
          for (final d in doses)
            {
              'name': d.name,
              'active_ingredient': d.activeIngredient,
              'dosage_per_kg': d.dosagePerKg,
              'cost_per_kg': d.costPerKg,
            },
        ]);
      case SheetEntity.gastos:
        final items = ref
                .watch(unifiedExpenseListByPropertyProvider)
                .asData
                ?.value ??
            const <ExpenseListItem>[];
        final paddocks =
            ref.watch(paddockListProvider).asData?.value ?? const <Paddock>[];
        final paddockName = {for (final p in paddocks) p.id: p.name};
        return ExportButton(schema: schema, fileName: fileName, rows: [
          for (final item in items)
            if (item case ManualExpenseItem(:final expense))
              {
                'expense_date': expense.expenseDate,
                'paddock_name': paddockName[expense.paddockId],
                'category': kExpenseCategoryLabelFor(expense.category),
                'amount': expense.amount,
                'description': expense.description,
              },
        ]);
      case SheetEntity.sanitario || SheetEntity.dg:
        return const SizedBox.shrink();
    }
  }

  // -------------------------------------------------------------------
  // Grades
  // -------------------------------------------------------------------

  Widget _buildGrid(SelectedProperty property) {
    switch (_entity) {
      case SheetEntity.animais:
        final animals =
            ref.watch(animalListByPropertyProvider).asData?.value ?? const [];
        final lots =
            ref.watch(loteListByPropertyProvider).asData?.value ?? const [];
        return AnimaisGridView(
          animals: animals,
          lots: lots,
          propertyId: property.id,
        );
      case SheetEntity.doses:
        final doses =
            ref.watch(doseListByPropertyProvider).asData?.value ?? const [];
        return DosesGridView(doses: doses, propertyId: property.id);
      case SheetEntity.lotes:
        return _lotesGrid(property);
      case SheetEntity.piquetes:
        return _piquetesGrid(property);
      case SheetEntity.gastos:
        return _gastosGrid(property);
      case SheetEntity.sanitario || SheetEntity.dg:
        return const SizedBox.shrink();
    }
  }

  Future<void> _saveBulk(
    Future<({int created, int updated})> Function() call,
    String noun,
  ) async {
    try {
      final res = await call();
      ref.invalidatePropertyData();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${res.created + res.updated} $noun salvos'),
        ));
      }
    } on BulkImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
      rethrow;
    }
  }

  Widget _lotesGrid(SelectedProperty property) {
    final lots =
        ref.watch(loteWithPaddockListByPropertyProvider).asData?.value ??
            const [];
    final paddocks =
        ref.watch(paddockListProvider).asData?.value ?? const <Paddock>[];
    final columns = gridColumnsFromSchema(
      lotesSchema,
      overrides: {
        'paddock_name': GridColumn(
          key: 'paddock_name',
          label: 'Piquete',
          width: 200,
          type: SheetColumnType.enumeration,
          options: {for (final p in paddocks) p.name: p.name},
        ),
      },
      flexKey: 'name',
    );
    return EditableGrid(
      columns: columns,
      rows: [
        for (final l in lots)
          GridRow(id: l.lot.id, values: {
            'name': l.lot.name,
            'paddock_name': l.paddockName,
          }),
      ],
      changeNoun: 'lotes',
      validator: (key, value, row) =>
          key == 'name' && (value == null || '$value'.trim().isEmpty)
              ? 'Nome é obrigatório'
              : null,
      onSave: (changes) => _saveBulk(
        () => ref.read(bulkRepositoryProvider).upsertLots(property.id, [
          for (final ch in changes) {'id': ch.rowId, ...ch.values},
        ]),
        'lotes',
      ),
    );
  }

  Widget _piquetesGrid(SelectedProperty property) {
    final paddocks =
        ref.watch(paddockListProvider).asData?.value ?? const <Paddock>[];
    final columns = gridColumnsFromSchema(piquetesSchema, flexKey: 'name');
    return EditableGrid(
      columns: columns,
      rows: [
        for (final p in paddocks)
          GridRow(id: p.id, values: {
            'name': p.name,
            'area_ha': p.areaHa,
            'ua_capacity': p.uaCapacity,
          }),
      ],
      changeNoun: 'piquetes',
      validator: (key, value, row) {
        if (key == 'name' && (value == null || '$value'.trim().isEmpty)) {
          return 'Nome é obrigatório';
        }
        if ((key == 'area_ha' || key == 'ua_capacity') &&
            value is double &&
            value <= 0) {
          return 'Deve ser maior que zero';
        }
        return null;
      },
      onSave: (changes) => _saveBulk(
        () => ref.read(bulkRepositoryProvider).upsertPaddocks(property.id, [
          for (final ch in changes) {'id': ch.rowId, ...ch.values},
        ]),
        'piquetes',
      ),
    );
  }

  Widget _gastosGrid(SelectedProperty property) {
    final items =
        ref.watch(unifiedExpenseListByPropertyProvider).asData?.value ??
            const <ExpenseListItem>[];
    final paddocks =
        ref.watch(paddockListProvider).asData?.value ?? const <Paddock>[];
    final paddockName = {for (final p in paddocks) p.id: p.name};
    final manual = [
      for (final item in items)
        if (item case ManualExpenseItem(:final expense)) expense,
    ];
    final columns = gridColumnsFromSchema(
      gastosSchema,
      overrides: {
        'paddock_name': GridColumn(
          key: 'paddock_name',
          label: 'Piquete',
          width: 190,
          type: SheetColumnType.enumeration,
          options: {for (final p in paddocks) p.name: p.name},
        ),
      },
      flexKey: 'description',
    );
    return EditableGrid(
      columns: columns,
      rows: [
        for (final e in manual)
          GridRow(id: e.id, values: {
            'expense_date': e.expenseDate,
            'paddock_name': paddockName[e.paddockId],
            'category': e.category,
            'amount': e.amount,
            'description': e.description,
          }),
      ],
      changeNoun: 'gastos',
      validator: (key, value, row) =>
          key == 'amount' && value is double && value <= 0
              ? 'Valor deve ser maior que zero'
              : null,
      onSave: (changes) => _saveBulk(
        () => ref.read(bulkRepositoryProvider).upsertExpenses(property.id, [
          for (final ch in changes)
            {
              'id': ch.rowId,
              for (final e in ch.values.entries)
                e.key: e.value is DateTime
                    ? _dateOnlyFmt.format(e.value as DateTime)
                    : e.value,
            },
        ]),
        'gastos',
      ),
    );
  }
}

/// Label pt-BR de categoria de gasto (fallback: a própria chave).
String kExpenseCategoryLabelFor(String key) =>
    gastosSchema.byKey('category')?.enumValues[key] ?? key;
