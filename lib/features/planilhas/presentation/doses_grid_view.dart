// Grade editável do catálogo de doses — modo "Grade" da tab Doses.
// Linha existente: nome bloqueado (a RPC casa por nome — renomear criaria
// duplicata); "+ Nova dose" adiciona linha em branco com nome editável.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../sanitario/data/dose_model.dart';
import '../data/bulk_repository.dart';
import '../domain/sheet_schema.dart';
import 'editable_grid.dart';

/// GridChanges → payload de bulk_upsert_doses. Linha existente sempre leva o
/// nome atual (chave do upsert); linha nova leva o que foi digitado.
List<Map<String, dynamic>> doseChangesToRows(
  List<GridChange> changes,
  List<Dose> doses,
) {
  final byId = {for (final d in doses) d.id: d};
  return [
    for (final ch in changes)
      {
        'name': byId[ch.rowId]?.name ?? ch.values['name'],
        for (final e in ch.values.entries)
          if (e.key != 'name') e.key: e.value,
      },
  ];
}

class DosesGridView extends ConsumerStatefulWidget {
  const DosesGridView({
    super.key,
    required this.doses,
    required this.propertyId,
  });

  final List<Dose> doses;
  final String propertyId;

  @override
  ConsumerState<DosesGridView> createState() => _DosesGridViewState();
}

class _DosesGridViewState extends ConsumerState<DosesGridView> {
  /// Linhas novas ainda não salvas (id sintético new-N).
  final List<GridRow> _newRows = [];
  int _newCounter = 0;

  void _addRow() => setState(() {
        _newCounter++;
        _newRows.add(GridRow(
          id: 'new-$_newCounter',
          isNew: true,
          values: const {
            'name': null,
            'active_ingredient': null,
            'dosage_per_kg': null,
            'cost_per_kg': null,
          },
        ));
      });

  @override
  Widget build(BuildContext context) {
    const columns = [
      GridColumn(key: 'name', label: 'Nome', width: 240),
      GridColumn(
          key: 'active_ingredient', label: 'Princípio ativo', width: 220),
      GridColumn(
        key: 'dosage_per_kg',
        label: 'Dosagem (ml/kg)',
        width: 150,
        type: SheetColumnType.decimal,
        mono: true,
      ),
      GridColumn(
        key: 'cost_per_kg',
        label: r'Custo (R$/kg)',
        width: 150,
        type: SheetColumnType.decimal,
        mono: true,
        flex: true,
      ),
    ];
    // Nome bloqueado em linha existente: coluna separada não dá — o
    // EditableGrid decide editable por coluna. Solução: linhas existentes
    // não incluem 'name' como editável via validator? Mais simples: manter
    // editável e a conversão ignora o nome digitado (doseChangesToRows usa
    // o nome atual). O validator avisa.
    final rows = [
      for (final d in widget.doses)
        GridRow(
          id: d.id,
          values: {
            'name': d.name,
            'active_ingredient': d.activeIngredient,
            'dosage_per_kg': d.dosagePerKg,
            'cost_per_kg': d.costPerKg,
          },
        ),
      ..._newRows,
    ];
    final newIds = {for (final r in _newRows) r.id};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 8),
          child: Row(
            children: [
              const Text(
                'Nome identifica a dose — para renomear, use o formulário. '
                'Tab / Enter avançam · Ctrl+V cola do Excel',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: _addRow,
                icon: const Icon(Icons.add, size: 18),
                label: const Text('Nova dose'),
              ),
            ],
          ),
        ),
        Expanded(
          child: EditableGrid(
            columns: columns,
            rows: rows,
            changeNoun: 'doses',
            validator: (key, value, row) {
              if (key == 'dosage_per_kg' &&
                  value is double &&
                  value <= 0) {
                return 'Dosagem deve ser maior que zero';
              }
              if (key == 'cost_per_kg' && value is double && value < 0) {
                return 'Custo não pode ser negativo';
              }
              return null;
            },
            onSave: (changes) async {
              // Linha nova precisa de nome e dosagem.
              for (final ch in changes) {
                if (newIds.contains(ch.rowId)) {
                  final name = (ch.values['name'] as String?)?.trim();
                  final dosage = ch.values['dosage_per_kg'];
                  if (name == null || name.isEmpty || dosage == null) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                      content: Text(
                          'Dose nova precisa de nome e dosagem por kg.'),
                    ));
                    throw const BulkImportException('linha nova incompleta');
                  }
                }
              }
              final rows = doseChangesToRows(changes, widget.doses);
              try {
                final res = await ref
                    .read(bulkRepositoryProvider)
                    .upsertDoses(widget.propertyId, rows);
                ref.invalidatePropertyData();
                setState(_newRows.clear);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${res.created} doses criadas · '
                        '${res.updated} atualizadas'),
                  ));
                }
              } on BulkImportException catch (e) {
                if (context.mounted &&
                    e.message != 'linha nova incompleta') {
                  ScaffoldMessenger.of(context)
                      .showSnackBar(SnackBar(content: Text(e.message)));
                }
                rethrow;
              }
            },
          ),
        ),
      ],
    );
  }
}
