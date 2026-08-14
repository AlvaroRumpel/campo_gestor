import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../../features/animais/data/animal_constants.dart';
import '../../../features/animais/data/animal_model.dart';
import '../../../features/animais/data/animal_repository.dart';
import '../../../features/auth/data/property_repository.dart';
import '../../../features/gastos/data/expense_repository.dart';
import '../../../features/lotes/data/lote_repository.dart';
import '../../../features/lotes/presentation/lote_detail_panel.dart';
import '../../../features/lotes/presentation/lote_form_dialog.dart';
import '../../../features/lotes/presentation/lotes_list_view.dart';
import '../../../features/lotes/presentation/lotes_table_view.dart';
import '../../../features/lotes/presentation/mover_lote_dialog.dart';
import '../../../features/sanitario/data/sanitary_application_repository.dart';
import '../../../features/sanitario/data/sanitary_calculations.dart';
import '../data/piquete_model.dart';
import '../data/piquete_repository.dart';
import 'paddock_form_dialog.dart';
import 'piquetes_board_view.dart';

String _fmt1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// /piquetes — segmented control alterna entre a lista de piquetes (spec 4.5)
/// e a lista de lotes da propriedade (spec 4.6). Estado local, sem rota nova.
class PiquetesScreen extends ConsumerStatefulWidget {
  const PiquetesScreen({super.key});

  @override
  ConsumerState<PiquetesScreen> createState() => _PiquetesScreenState();
}

class _PiquetesScreenState extends ConsumerState<PiquetesScreen> {
  bool _showLots = false;
  String? _selectedLotId;

  @override
  Widget build(BuildContext context) {
    // Reset the mestre-detalhe lote selection when the active property
    // actually changes — guarded so the first resolve (null -> A) is a
    // no-op.
    ref.listen(currentPropertyProvider, (prev, next) {
      final prevId = prev?.value?.id;
      final nextId = next.value?.id;
      if (prevId == null || nextId == null || prevId == nextId) return;
      setState(() => _selectedLotId = null);
    });

    final paddocksAsync = ref.watch(paddockListProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final lotsAsync = ref.watch(loteWithPaddockListByPropertyProvider);
    final animalsAsync = ref.watch(animalListByPropertyProvider);

    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    final paddockCount = paddocksAsync.asData?.value.length ?? 0;
    final lotCount = lotsAsync.asData?.value.length ?? 0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.rail;

        final Widget body = isDesktop
            ? _buildDesktop(
                context,
                paddocks: paddocksAsync.asData?.value ?? const <Paddock>[],
                lots: lotsAsync.asData?.value ??
                    const <LotWithPaddockCount>[],
                animals: animalsAsync.asData?.value ??
                    const <AnimalWithContext>[],
                canEdit: canEdit,
                paddockCount: paddockCount,
                lotCount: lotCount,
                currentProp: currentPropAsync.asData?.value,
              )
            : Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: _SegmentButton(
                            label: 'Piquetes',
                            count: paddockCount,
                            selected: !_showLots,
                            onTap: () => setState(() => _showLots = false),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _SegmentButton(
                            label: 'Lotes',
                            count: lotCount,
                            selected: _showLots,
                            onTap: () => setState(() => _showLots = true),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _showLots
                        ? const LotesListView()
                        : paddocksAsync.when(
                            loading: () => const Center(
                              child: CircularProgressIndicator(),
                            ),
                            error: (err, _) => Center(
                              child: ErrorRetry(
                                message: 'Erro ao carregar piquetes.',
                                onRetry: () =>
                                    ref.invalidate(paddockListProvider),
                              ),
                            ),
                            data: (paddocks) {
                              if (paddocks.isEmpty) {
                                return const EmptyState(
                                  icon: Icons.fence_outlined,
                                  title: 'Nenhum piquete cadastrado',
                                  message:
                                      'Adicione piquetes para começar a organizar os lotes da fazenda.',
                                );
                              }
                              return ListView.separated(
                                padding:
                                    const EdgeInsets.fromLTRB(14, 4, 14, 96),
                                itemCount: paddocks.length,
                                separatorBuilder: (_, _) =>
                                    const SizedBox(height: 10),
                                itemBuilder: (context, i) => _PaddockCard(
                                  paddock: paddocks[i],
                                  lotsAsync: lotsAsync,
                                  animalsAsync: animalsAsync,
                                  canEdit: canEdit,
                                  onEdit: () => _openForm(
                                    context,
                                    paddock: paddocks[i],
                                  ),
                                  onDelete: () =>
                                      _confirmDelete(context, paddocks[i]),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              );

        return Scaffold(
          appBar: const CampoAppBar(title: 'Piquetes'),
          body: body,
          floatingActionButton: canEdit && !_showLots
              ? FloatingActionButton.extended(
                  onPressed: () => _openForm(context),
                  icon: const Icon(Icons.add, size: 22),
                  label: const Text('Piquete'),
                )
              : null,
        );
      },
    );
  }

  /// Branch mestre-detalhe desktop (>=Breakpoints.rail): quadro de piquetes
  /// (PiquetesBoardView) ou tabela de lotes (LotesTableView), com
  /// LoteDetailPanel opcional servindo as duas abas. Deriva os agregados a
  /// partir dos providers que a tela já observa — zero método novo de
  /// repositório.
  Widget _buildDesktop(
    BuildContext context, {
    required List<Paddock> paddocks,
    required List<LotWithPaddockCount> lots,
    required List<AnimalWithContext> animals,
    required bool canEdit,
    required int paddockCount,
    required int lotCount,
    required SelectedProperty? currentProp,
  }) {
    final animalsByLot = <String, List<Animal>>{};
    for (final ctx in animals) {
      if (ctx.animal.deletedAt != null) continue;
      (animalsByLot[ctx.animal.lotId] ??= []).add(ctx.animal);
    }

    final overloadedPaddockIds = <String>{};
    for (final p in paddocks) {
      final ua = calcTotalUa(
        animals
            .where((c) => c.animal.deletedAt == null && c.paddockId == p.id)
            .map((c) => c.animal),
      );
      if (p.uaCapacity > 0 && ua / p.uaCapacity >= 1.0) {
        overloadedPaddockIds.add(p.id);
      }
    }

    final applicationsAsync =
        ref.watch(sanitaryApplicationListByPropertyProvider);
    final lastApplicationByLot = <String, DateTime>{};
    for (final app in applicationsAsync.asData?.value ?? const []) {
      final existing = lastApplicationByLot[app.lotId];
      if (existing == null || app.appliedAt.isAfter(existing)) {
        lastApplicationByLot[app.lotId] = app.appliedAt;
      }
    }

    final selected = lots.where((l) => l.lot.id == _selectedLotId).firstOrNull;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: _showLots
              ? LotesTableView(
                  lots: lots,
                  animalsByLot: animalsByLot,
                  paddocks: paddocks,
                  overloadedPaddockIds: overloadedPaddockIds,
                  lastApplicationByLot: lastApplicationByLot,
                  paddockCount: paddockCount,
                  lotCount: lotCount,
                  showLots: _showLots,
                  onShowLotsChanged: (v) => setState(() => _showLots = v),
                  selectedId: _selectedLotId,
                  onSelect: (id) => setState(() => _selectedLotId = id),
                  canEdit: canEdit,
                  onCreate: () => _onCreateLot(context, paddocks, currentProp),
                )
              : PiquetesBoardView(
                  paddocks: paddocks,
                  lots: lots,
                  animalsByLot: animalsByLot,
                  onShowLotsChanged: (v) => setState(() => _showLots = v),
                  selectedLotId: _selectedLotId,
                  onSelectLot: (id) => setState(() => _selectedLotId = id),
                  onMoveLot: (item, target) => _onDropLot(context, item, target),
                  canEdit: canEdit,
                ),
        ),
        if (selected != null)
          LoteDetailPanel(
            key: ValueKey(selected.lot.id),
            item: selected,
            activeAnimals: animalsByLot[selected.lot.id] ?? const <Animal>[],
            lastApplication: lastApplicationByLot[selected.lot.id],
            canEdit: canEdit,
            onClose: () => setState(() => _selectedLotId = null),
          ),
      ],
    );
  }

  /// Soltar um card de lote em outra coluna do quadro: abre o
  /// MoverLoteDialog existente com o piquete de destino pré-selecionado —
  /// a tela nunca chama o repositório de lotes diretamente, o diálogo é o
  /// único caminho de escrita.
  Future<void> _onDropLot(
    BuildContext context,
    LotWithPaddockCount item,
    Paddock target,
  ) async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverLoteDialog(
        lot: item.lot,
        activeAnimalCount: item.activeAnimalCount,
        initialPaddock: target,
      ),
    );
    if (result == null || !context.mounted) return;
    ref.invalidate(loteWithPaddockListByPropertyProvider);
    ref.invalidate(animalListByPropertyProvider);
    ref.invalidate(paddockListProvider);
    final paddockName = result['paddockName'] ?? '';
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Lote movido para $paddockName')),
    );
  }

  /// "Novo lote" no cabeçalho da tabela desktop: escolhe o piquete (a aba
  /// Lotes não tem piquete no contexto) e encadeia no LoteFormDialog
  /// existente — sem rota nem diálogo de formulário novo.
  Future<void> _onCreateLot(
    BuildContext context,
    List<Paddock> paddocks,
    SelectedProperty? currentProp,
  ) async {
    if (currentProp == null || paddocks.isEmpty) return;
    final paddockId = await showDialog<String>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: const Text('Em qual piquete?'),
        children: [
          for (final p in paddocks)
            SimpleDialogOption(
              onPressed: () => Navigator.pop(ctx, p.id),
              child: Text(p.name),
            ),
        ],
      ),
    );
    if (paddockId == null || !context.mounted) return;
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => LoteFormDialog(
        paddockId: paddockId,
        propertyId: currentProp.id,
      ),
    );
    if (ok == true) {
      ref.invalidate(loteWithPaddockListByPropertyProvider);
    }
  }

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }

  Future<void> _openForm(BuildContext context, {Paddock? paddock}) async {
    final result = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => PaddockFormDialog(existing: paddock),
    );
    if (result == true) {
      ref.invalidate(paddockListProvider);
    }
  }

  Future<void> _confirmDelete(BuildContext context, Paddock paddock) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover piquete'),
        content: Text(
          'Tem certeza que deseja remover "${paddock.name}"?',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onDanger,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(paddockRepositoryProvider).softDeletePaddock(paddock.id);
      ref.invalidate(paddockListProvider);
    }
  }
}

/// Botão do segmented control h42 r12 — label + contagem mono 11.5.
class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(12),
          border: selected ? null : Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onGreen : AppColors.ink,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: monoStyle(
                size: 11.5,
                color: selected
                    ? AppColors.onGreenSecondary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Card de piquete (spec 4.5): título + chip semáforo, 4 stats, barra de
/// lotação e rodapé lotes/animais + gasto do mês.
class _PaddockCard extends ConsumerWidget {
  const _PaddockCard({
    required this.paddock,
    required this.lotsAsync,
    required this.animalsAsync,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });

  final Paddock paddock;
  final AsyncValue<List<LotWithPaddockCount>> lotsAsync;
  final AsyncValue<List<AnimalWithContext>> animalsAsync;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAnimals = (animalsAsync.asData?.value ?? const [])
        .where((c) => c.animal.deletedAt == null && c.paddockId == paddock.id)
        .toList();
    final uaAtual = calcTotalUa(activeAnimals.map((c) => c.animal));
    final ratio = paddock.uaCapacity > 0 ? uaAtual / paddock.uaCapacity : 0.0;
    final uaHa = paddock.areaHa > 0 ? uaAtual / paddock.areaHa : 0.0;
    final over = ratio >= 1.0;
    final lotCount = (lotsAsync.asData?.value ?? const [])
        .where((l) => l.lot.paddockId == paddock.id)
        .length;
    final expenseAsync =
        ref.watch(paddockMonthExpenseTotalProvider(paddock.id));

    final (chipLabel, chipKind) = over
        ? ('Superlotado', StatusKind.danger)
        : ratio >= 0.9
            ? ('No limite', StatusKind.warning)
            : ('Folga', StatusKind.positive);

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go('/piquetes/${paddock.id}'),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      paddock.name,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  StatusChip(chipLabel, kind: chipKind),
                  if (canEdit)
                    SizedBox(
                      width: 32,
                      height: 32,
                      child: PopupMenuButton<String>(
                        padding: EdgeInsets.zero,
                        iconSize: 20,
                        onSelected: (v) {
                          if (v == 'edit') onEdit();
                          if (v == 'delete') onDelete();
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(
                              'Remover',
                              style: TextStyle(color: AppColors.danger),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _Stat(value: _fmt1(paddock.areaHa), label: 'hectares'),
                  _Stat(value: _fmt1(uaAtual), label: 'UA atual'),
                  _Stat(
                    value: _fmt1(paddock.uaCapacity),
                    label: 'capacidade',
                    valueColor: AppColors.textTertiary,
                  ),
                  _Stat(
                    value: _fmt1(uaHa),
                    label: 'UA/ha',
                    valueColor: over ? AppColors.danger : null,
                    alignEnd: true,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              CapacityBar(current: uaAtual, capacity: paddock.uaCapacity),
              const SizedBox(height: 10),
              Row(
                children: [
                  const Icon(
                    Icons.group_work_outlined,
                    size: 18,
                    color: AppColors.textSecondary,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      '$lotCount ${lotCount == 1 ? 'lote' : 'lotes'} · '
                      '${activeAnimals.length} ${activeAnimals.length == 1 ? 'animal' : 'animais'}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ),
                  ...expenseAsync.when(
                    data: (total) => [
                      Text(
                        formatCurrencyBrl(total),
                        style: monoStyle(size: 13, weight: FontWeight.w600),
                      ),
                      const Text(
                        ' no mês',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                    loading: () => const [SizedBox.shrink()],
                    error: (e, _) => const [
                      Text(
                        '—',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.value,
    required this.label,
    this.valueColor,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final Color? valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment:
            alignEnd ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          Text(
            value,
            style: monoStyle(
              size: 16,
              weight: FontWeight.w600,
              color: valueColor ?? AppColors.ink,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11.5,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
