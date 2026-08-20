// Grade editável de animais — modo "Grade" da tela /animais (desktop, vet).
// Salva via bulk_upsert_animals com só as linhas alteradas.
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../lotes/data/lote_model.dart';
import '../data/bulk_repository.dart';
import '../domain/sheet_schema.dart';
import 'editable_grid.dart';

/// GridChanges → payload do RPC. Toda linha leva `number` + `category`
/// (a RPC exige categoria; number identifica o animal no upsert); `lot_id`
/// escolhido no dropdown vira `lot_name`.
List<Map<String, dynamic>> animalChangesToRows(
  List<GridChange> changes,
  List<AnimalWithContext> animals,
  List<Lot> lots,
) {
  final byId = {for (final aw in animals) aw.animal.id: aw.animal};
  final lotNameById = {for (final l in lots) l.id: l.name};
  return [
    for (final ch in changes)
      if (byId[ch.rowId] case final Animal a)
        {
          'number': a.number,
          'category': (ch.values['category'] as String?) ?? a.category,
          for (final e in ch.values.entries)
            if (e.key == 'lot_id')
              'lot_name': lotNameById[e.value]
            else if (e.key == 'body_condition')
              // dropdown 1–5 trafega String no grid; RPC espera int
              'body_condition':
                  e.value == null ? null : int.tryParse(e.value.toString())
            else if (e.key != 'category')
              e.key: e.value,
        },
  ];
}

class AnimaisGridView extends ConsumerWidget {
  const AnimaisGridView({
    super.key,
    required this.animals,
    required this.lots,
    required this.propertyId,
  });

  /// Animais visíveis (filtros da tela aplicados), sem baixa.
  final List<AnimalWithContext> animals;
  final List<Lot> lots;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active =
        animals.where((aw) => aw.animal.deletedAt == null).toList();
    final columns = [
      const GridColumn(
        key: 'number',
        label: 'Nº',
        width: 96,
        editable: false,
        mono: true,
      ),
      const GridColumn(
        key: 'category',
        label: 'Categoria',
        width: 150,
        type: SheetColumnType.enumeration,
        options: kCategoryLabels,
      ),
      GridColumn(
        key: 'breed',
        label: 'Raça',
        width: 170,
        suggestions: {
          for (final aw in animals)
            if (aw.animal.breed != null &&
                aw.animal.breed!.trim().isNotEmpty)
              aw.animal.breed!.trim(),
        }.toList()
          ..sort(),
      ),
      const GridColumn(
        key: 'body_condition',
        label: 'ECC',
        width: 90,
        type: SheetColumnType.enumeration,
        options: {'1': '1', '2': '2', '3': '3', '4': '4', '5': '5'},
        mono: true,
      ),
      GridColumn(
        key: 'lot_id',
        label: 'Lote',
        width: 180,
        type: SheetColumnType.enumeration,
        options: {for (final l in lots) l.id: l.name},
      ),
      const GridColumn(
        key: 'observation',
        label: 'Observação',
        width: 200,
        flex: true,
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.surfaceVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.content_paste,
                        size: 14, color: AppColors.textSecondary),
                    SizedBox(width: 6),
                    Text(
                      'Ctrl+V cola células copiadas do Excel',
                      style: TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Tab / Enter avançam · Esc cancela a célula',
                style:
                    TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
        Expanded(
          child: EditableGrid(
            columns: columns,
            rows: [
              for (final aw in active)
                GridRow(
                  id: aw.animal.id,
                  values: {
                    'number': aw.animal.number,
                    'category': aw.animal.category,
                    'breed': aw.animal.breed,
                    'body_condition': aw.animal.bodyCondition?.toString(),
                    'lot_id': aw.animal.lotId,
                    'observation': aw.animal.observation,
                  },
                ),
            ],
            changeNoun: 'animais',
            validator: (key, value, row) {
              if (key == 'category' && value == null) {
                return 'Categoria é obrigatória';
              }
              if (key == 'lot_id' && value == null) {
                return 'Lote é obrigatório';
              }
              return null;
            },
            onSave: (changes) async {
              final rows = animalChangesToRows(changes, active, lots);
              try {
                final res = await ref
                    .read(bulkRepositoryProvider)
                    .upsertAnimals(propertyId, rows);
                ref.invalidatePropertyData();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('${res.updated + res.created} animais '
                        'atualizados'),
                  ));
                }
              } on BulkImportException catch (e) {
                if (context.mounted) {
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
