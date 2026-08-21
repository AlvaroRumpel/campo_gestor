import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../reproducao/data/iatf_repository.dart';
import '../../reproducao/data/dg_summary.dart';
import '../../planilhas/domain/sheet_schema.dart';
import '../../planilhas/presentation/export_button.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import 'animais_filters.dart';
import 'animal_edit_dialog.dart';
import 'baixa_dialog.dart';
import 'mover_animal_dialog.dart';

/// Tabela densa desktop de Animais (Task 3, quick task 260813-p10) —
/// mestre-detalhe a partir de `Breakpoints.rail`. Larguras de coluna
/// declaradas uma vez e reusadas pelo cabeçalho e pelas linhas.
const _kColNumber = 72.0;
const _kColUa = 64.0;
const _kColRepro = 130.0;
const _kColCadastro = 84.0;
const _kColMenu = 44.0;
const _kFlexCategoria = 2;
const _kFlexRaca = 2;
const _kFlexLote = 2;
const _kFlexPiquete = 2;
const _kFlexObs = 3;

final _dateFmtShort = DateFormat('dd/MM/yy');

String _fmtUa(double ua) => ua.toStringAsFixed(1).replaceAll('.', ',');

String _baixaLabel(String? reason) => switch (reason) {
      'sale' => 'Vendido',
      'death' => 'Morte',
      'discard' => 'Descarte',
      _ => 'Arquivado',
    };

class AnimaisTableView extends ConsumerWidget {
  const AnimaisTableView({
    super.key,
    required this.filtered,
    required this.base,
    required this.propertyAnimals,
    required this.allLots,
    required this.paddocks,
    required this.query,
    required this.category,
    required this.lotId,
    required this.paddockId,
    required this.showArchived,
    required this.onQueryChanged,
    required this.onCategoryChanged,
    required this.onLotChanged,
    required this.onPaddockChanged,
    required this.onShowArchivedChanged,
    required this.canEdit,
    required this.selectedId,
    required this.onSelect,
    required this.onCreate,
    required this.sortDescending,
    required this.onToggleSort,
    required this.propertyName,
    this.onImport,
    this.body,
    this.gridMode = false,
    this.onGridModeChanged,
  });

  final List<AnimalWithContext> filtered;
  final List<AnimalWithContext> base;

  /// Conjunto completo da propriedade (Task 3, 260813-p10) — não filtrado
  /// por busca/lote/piquete/arquivado, ao contrário de [filtered]/[base].
  /// Fonte dos totais do cabeçalho e dos rótulos "Ativos {n}"/"Com baixa
  /// {n}", que precisam ser estáveis independente do escopo selecionado
  /// (o comBaixa da spec é "no conjunto completo da propriedade", não no
  /// [base] já filtrado pelo toggle de arquivados).
  final List<AnimalWithContext> propertyAnimals;
  final Map<String, String> allLots;
  final List<Paddock> paddocks;
  final String query;
  final String? category;
  final String? lotId;
  final String? paddockId;
  final bool showArchived;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String?> onCategoryChanged;
  final ValueChanged<String?> onLotChanged;
  final ValueChanged<String?> onPaddockChanged;
  final ValueChanged<bool> onShowArchivedChanged;
  final bool canEdit;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final VoidCallback onCreate;
  final bool sortDescending;
  final VoidCallback onToggleSort;
  final String propertyName;

  /// Abre o fluxo de importação — null quando o usuário não pode editar.
  final VoidCallback? onImport;

  /// Corpo alternativo (grade editável) que substitui tabela+rodapé.
  final Widget? body;
  final bool gridMode;

  /// null = toggle lista/grade não aparece (mobile ou sem permissão).
  final ValueChanged<bool>? onGridModeChanged;

  Future<void> _handleRowAction(
    BuildContext context,
    WidgetRef ref,
    String action,
    Animal animal,
  ) async {
    switch (action) {
      case 'editar':
        final ok = await showAdaptiveForm<bool>(
          context: context,
          builder: (_) => AnimalEditDialog(animal: animal),
        );
        if (ok == true) _invalidateAfterAction(ref, animal.id);
      case 'mover':
        final result = await showAdaptiveForm<Map<String, String>>(
          context: context,
          builder: (_) => MoverAnimalDialog(animal: animal),
        );
        if (result != null) _invalidateAfterAction(ref, animal.id);
      case 'baixa':
        final ok = await showAdaptiveForm<bool>(
          context: context,
          builder: (_) => BaixaDialog(animal: animal),
        );
        if (ok == true) _invalidateAfterAction(ref, animal.id);
    }
  }

  void _invalidateAfterAction(WidgetRef ref, String animalId) =>
      ref.invalidatePropertyData();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reproStatusMap =
        ref.watch(animalReproStatusByPropertyProvider).asData?.value ??
            const <String, AnimalReproStatus>{};

    final ativosCount =
        propertyAnimals.where((aw) => aw.animal.deletedAt == null).length;
    final comBaixaCount =
        propertyAnimals.where((aw) => aw.animal.deletedAt != null).length;
    final totalUa = calcTotalUa(
      propertyAnimals
          .where((aw) => aw.animal.deletedAt == null)
          .map((aw) => aw.animal),
    );

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header da tela
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Animais',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '$ativosCount ativos · ${_fmtUa(totalUa)} UA · '
                        '$comBaixaCount com baixa',
                        style: monoStyle(
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 300,
                  child: TextField(
                    onChanged: onQueryChanged,
                    decoration: const InputDecoration(
                      hintText: 'Buscar por número ou lote',
                      prefixIcon: Icon(Icons.search,
                          size: 20, color: AppColors.textSecondary),
                    ),
                  ),
                ),
                if (onGridModeChanged != null) ...[
                  const SizedBox(width: 10),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(
                        value: false,
                        icon: Icon(Icons.view_list_outlined, size: 18),
                        tooltip: 'Lista',
                      ),
                      ButtonSegment(
                        value: true,
                        icon: Icon(Icons.grid_on, size: 18),
                        tooltip: 'Editar em grade',
                      ),
                    ],
                    selected: {gridMode},
                    showSelectedIcon: false,
                    onSelectionChanged: (sel) =>
                        onGridModeChanged!(sel.first),
                  ),
                ],
                const SizedBox(width: 10),
                ExportButton(
                  schema: animaisSchema,
                  fileName: exportFileName('animais', propertyName),
                  rows: [
                    for (final aw in filtered)
                      {
                        'number': aw.animal.number,
                        'category': aw.animal.category,
                        'breed': aw.animal.breed,
                        'body_condition': aw.animal.bodyCondition,
                        'lot_name': aw.lotName,
                        'observation': aw.animal.observation,
                        'paddock_name': aw.paddockName,
                        'ua': kUaWeights[aw.animal.category],
                      },
                  ],
                ),
                if (canEdit && onImport != null) ...[
                  const SizedBox(width: 10),
                  OutlinedButton.icon(
                    onPressed: onImport,
                    icon: const Icon(Icons.upload_outlined, size: 20),
                    label: const Text('Importar'),
                  ),
                ],
                if (canEdit) ...[
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Novo animal'),
                  ),
                ],
              ],
            ),
          ),
          // Linha de filtros
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                _ScopeChip(
                  label: 'Ativos $ativosCount',
                  selected: !showArchived,
                  onTap: () => onShowArchivedChanged(false),
                ),
                const SizedBox(width: 8),
                _ScopeChip(
                  label: 'Com baixa $comBaixaCount',
                  selected: showArchived,
                  onTap: () => onShowArchivedChanged(true),
                ),
                const SizedBox(width: 10),
                const SizedBox(
                    height: 22, child: VerticalDivider(width: 1)),
                const SizedBox(width: 10),
                FilterMenuChip(
                  addLabel: '+ Categoria',
                  selectedLabel:
                      category == null ? null : kCategoryLabels[category],
                  entries: kCategoryLabels,
                  onSelected: onCategoryChanged,
                  onCleared: () => onCategoryChanged(null),
                ),
                const SizedBox(width: 8),
                FilterMenuChip(
                  addLabel: '+ Lote',
                  selectedLabel: lotId == null ? null : allLots[lotId],
                  entries: allLots,
                  onSelected: onLotChanged,
                  onCleared: () => onLotChanged(null),
                ),
                const SizedBox(width: 8),
                FilterMenuChip(
                  addLabel: '+ Piquete',
                  selectedLabel: paddockId == null
                      ? null
                      : paddocks
                          .where((p) => p.id == paddockId)
                          .map((p) => p.name)
                          .firstOrNull,
                  entries: {for (final p in paddocks) p.id: p.name},
                  onSelected: onPaddockChanged,
                  onCleared: () => onPaddockChanged(null),
                ),
                const Spacer(),
                Text(
                  '${filtered.length} resultados',
                  style:
                      monoStyle(size: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (body != null)
            Expanded(child: body!)
          else ...[
          // Cabeçalho da tabela
          Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                InkWell(
                  onTap: onToggleSort,
                  child: SizedBox(
                    width: _kColNumber,
                    child: Row(
                      children: [
                        const _HeaderText('Nº'),
                        const SizedBox(width: 2),
                        Icon(
                          sortDescending
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 12,
                          color: AppColors.primaryDarkText,
                        ),
                      ],
                    ),
                  ),
                ),
                const Expanded(
                    flex: _kFlexCategoria, child: _HeaderText('CATEGORIA')),
                const Expanded(
                    flex: _kFlexRaca, child: _HeaderText('RAÇA')),
                const Expanded(
                    flex: _kFlexLote, child: _HeaderText('LOTE')),
                const Expanded(
                    flex: _kFlexPiquete, child: _HeaderText('PIQUETE')),
                const Expanded(
                    flex: _kFlexObs, child: _HeaderText('OBSERVAÇÃO')),
                const SizedBox(
                  width: _kColUa,
                  child: _HeaderText('UA', align: TextAlign.right),
                ),
                const SizedBox(width: 12),
                const SizedBox(
                  width: _kColRepro - 12,
                  child: _HeaderText('REPRODUÇÃO'),
                ),
                const SizedBox(
                  width: _kColCadastro,
                  child: _HeaderText('CADASTRO', align: TextAlign.right),
                ),
                const SizedBox(width: _kColMenu),
              ],
            ),
          ),
          // Linhas
          Expanded(
            child: filtered.isEmpty
                ? const EmptyState(
                    icon: Icons.pets_outlined,
                    title: 'Nenhum animal encontrado',
                    message: 'Ajuste a busca ou os filtros para ver animais.',
                  )
                : ListView.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, i) => _buildRow(
                      context,
                      ref,
                      filtered[i],
                      reproStatusMap,
                    ),
                  ),
          ),
          // Rodapé
          Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            alignment: Alignment.centerRight,
            child: Text(
              '1–${filtered.length} de ${base.length}',
              style: monoStyle(size: 11.5, color: AppColors.textSecondary),
            ),
          ),
          ],
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    AnimalWithContext aw,
    Map<String, AnimalReproStatus> reproStatusMap,
  ) {
    final a = aw.animal;
    final isArchived = a.deletedAt != null;
    final selected = a.id == selectedId;
    final categoryLabel = kCategoryLabels[a.category] ?? a.category;
    final ua = kUaWeights[a.category] ?? 0.0;
    final reproStatus = reproStatusMap[a.id] ?? AnimalReproStatus.foraDoIatf;
    final breed = a.breed;
    final breedLabel =
        breed == null || breed.trim().isEmpty ? '—' : breed;

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.rowSelected : null,
        border: Border(
          left: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kColNumber,
            child: Text(
              '#${a.number}',
              overflow: TextOverflow.ellipsis,
              style: monoStyle(size: 15, weight: FontWeight.w700).copyWith(
                decoration:
                    isArchived ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Expanded(
            flex: _kFlexCategoria,
            child: Text(categoryLabel, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexRaca,
            child: Text(breedLabel, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexLote,
            child: Text(aw.lotName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexPiquete,
            child: Text(aw.paddockName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexObs,
            child: Tooltip(
              message: a.observation ?? '',
              waitDuration: const Duration(milliseconds: 600),
              child: Text(
                (a.observation == null || a.observation!.trim().isEmpty)
                    ? '—'
                    : a.observation!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ),
          SizedBox(
            width: _kColUa,
            child: Text(
              _fmtUa(ua),
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColRepro,
            child: isArchived
                ? StatusChip(
                    'Baixa · ${_baixaLabel(a.baixaReason)}',
                    kind: StatusKind.danger,
                  )
                : reproStatus == AnimalReproStatus.foraDoIatf
                    ? const Text('—',
                        style: TextStyle(color: AppColors.textTertiary))
                    : StatusChip(
                        reproStatus.label,
                        kind: reproStatus.chipKind,
                      ),
          ),
          SizedBox(
            width: _kColCadastro,
            child: Text(
              _dateFmtShort.format(a.createdAt.toLocal()),
              textAlign: TextAlign.right,
              style: monoStyle(size: 12),
            ),
          ),
          SizedBox(
            width: _kColMenu,
            child: canEdit
                ? PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert,
                        size: 18, color: AppColors.textSecondary),
                    onSelected: (action) =>
                        _handleRowAction(context, ref, action, a),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                          value: 'editar', child: Text('Editar')),
                      if (!isArchived) ...[
                        const PopupMenuItem(
                            value: 'mover', child: Text('Mover')),
                        const PopupMenuItem(
                            value: 'baixa', child: Text('Dar baixa')),
                      ],
                    ],
                  )
                : null,
          ),
        ],
      ),
    );

    return InkWell(
      hoverColor: AppColors.rowHover,
      onTap: () => onSelect(a.id),
      child: Opacity(opacity: isArchived ? 0.5 : 1, child: row),
    );
  }
}

/// Chip de escopo "Ativos {n}" / "Com baixa {n}" — não é um [FilterMenuChip]
/// (sem popup, sem estado removível), é um toggle binário simples.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.positiveChipBg : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.chipBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color:
                  selected ? AppColors.primaryDarkText : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Texto de coluna do cabeçalho da tabela: mono 10.5px w700, caixa alta,
/// `letterSpacing 0.8`.
class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.align = TextAlign.left});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.primaryDarkText,
      ),
    );
  }
}
