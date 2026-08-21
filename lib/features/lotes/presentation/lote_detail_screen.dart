import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../../features/animais/data/animal_constants.dart';
import '../../../features/animais/data/animal_model.dart';
import '../../../features/animais/data/animal_repository.dart';
import '../../../features/animais/presentation/animal_form_dialog.dart';
import '../../../features/auth/data/property_repository.dart';
import '../../../features/piquetes/data/piquete_repository.dart';
import '../../planilhas/data/bulk_repository.dart';
import '../../sanitario/presentation/aplicacao_form_dialog.dart';
import '../../sanitario/presentation/sanitary_history_section.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';
import 'lote_actions.dart';
import 'mover_lote_dialog.dart';

String _fmtUa(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Cores das barras de composição por linha (spec 4.7).
const _compositionColors = [
  AppColors.primary,
  AppColors.greenMid,
  AppColors.greenLight,
];

class LoteDetailScreen extends ConsumerWidget {
  const LoteDetailScreen({super.key, required this.loteId});
  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotAsync = ref.watch(loteByIdProvider(loteId));
    final animalsAsync = ref.watch(animalListByLotProvider(loteId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    final lotForActions = lotAsync.asData?.value;
    return Scaffold(
      appBar: DetailAppBar(
        parentLabel: 'Lotes',
        onBack: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          final paddockId = lotAsync.asData?.value?.paddockId;
          if (paddockId != null) {
            context.go('/piquetes/$paddockId');
          } else {
            context.go(AppRoutes.piquetes);
          }
        },
        actions: [
          if (canEdit && lotForActions != null &&
              lotForActions.deletedAt == null)
            PopupMenuButton<String>(
              iconColor: AppColors.onGreen,
              onSelected: (v) async {
                if (v == 'edit') {
                  await editLotName(context, ref, lotForActions);
                } else if (v == 'archive') {
                  final archived =
                      await archiveLot(context, ref, lotForActions);
                  if (archived && context.mounted) {
                    context.go('/piquetes/${lotForActions.paddockId}');
                  }
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Editar nome')),
                PopupMenuItem(value: 'archive', child: Text('Arquivar lote')),
              ],
            ),
        ],
      ),
      body: lotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: ErrorRetry(
            message: 'Erro ao carregar lote.',
            onRetry: () => ref.invalidate(loteByIdProvider(loteId)),
          ),
        ),
        data: (lot) {
          if (lot == null) {
            return const Center(child: Text('Lote não encontrado.'));
          }
          final activeAnimals = (animalsAsync.asData?.value ?? const <Animal>[])
              .where((a) => a.deletedAt == null)
              .toList();
          final showActions =
              canEdit && lot.deletedAt == null && activeAnimals.isNotEmpty;
          return Column(
            children: [
              _LoteHeader(lot: lot, activeAnimals: activeAnimals),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 96),
                  children: [
                    // MOV-02/SANI-02: ações gated por canEdit + lote ativo +
                    // ao menos 1 animal ativo (D-18: espelho exato do gate de mover)
                    if (showActions) ...[
                      Row(
                        children: [
                          Expanded(
                            child: FilledButton.icon(
                              onPressed: () => _onRegistrar(context, ref),
                              icon: const Icon(
                                Icons.medical_services_outlined,
                                size: 20,
                              ),
                              label: const Text('Aplicação'),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _onMover(
                                context,
                                ref,
                                lot,
                                activeAnimals.length,
                              ),
                              icon: const Icon(Icons.swap_horiz, size: 20),
                              label: const Text('Mover lote'),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                    _ComposicaoCard(animals: activeAnimals),
                    const SizedBox(height: 12),
                    _AnimaisCard(
                      lotId: loteId,
                      animalsAsync: animalsAsync,
                      lot: lot,
                      canEdit: canEdit,
                    ),
                    const SizedBox(height: 12),
                    LoteSanitaryHistorySection(lotId: loteId),
                  ],
                ),
              ),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton.extended(
              onPressed: () async {
                final lot = lotAsync.asData?.value;
                if (lot == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AnimalFormDialog(
                    lotId: loteId,
                    propertyId: lot.propertyId,
                  ),
                );
                if (ok == true) {
                  ref.invalidatePropertyData();
                }
              },
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Animal'),
            )
          : null,
    );
  }

  Future<void> _onMover(
    BuildContext context,
    WidgetRef ref,
    Lot lot,
    int activeCount,
  ) async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverLoteDialog(
        lot: lot,
        activeAnimalCount: activeCount,
      ),
    );
    if (result != null && context.mounted) {
      final paddockName = result['paddockName'] ?? '';
      ref.invalidatePropertyData();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lote movido para $paddockName')),
      );
    }
  }

  Future<void> _onRegistrar(BuildContext context, WidgetRef ref) async {
    await showDialog<void>(
      context: context,
      builder: (_) => AplicacaoFormDialog(
        lotId: loteId,
        onRegistered: (count) {
          if (!context.mounted) return;
          ref.invalidatePropertyData();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sanitaryRegisteredMessage(count))),
          );
        },
      ),
    );
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
}

/// Header verde (spec 4.7): nome 26/700 + "Piquete X · N animais ativos" +
/// badge laranja retangular com a UA total do lote.
class _LoteHeader extends ConsumerWidget {
  const _LoteHeader({required this.lot, required this.activeAnimals});

  final Lot lot;
  final List<Animal> activeAnimals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddockAsync = ref.watch(paddockByIdProvider(lot.paddockId));
    final paddockName = paddockAsync.asData?.value?.name ?? '—';
    final count = activeAnimals.length;
    final ua = calcTotalUa(activeAnimals);

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  lot.name,
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$paddockName · $count ${count == 1 ? 'animal ativo' : 'animais ativos'}',
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.onGreenSecondary,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
            decoration: BoxDecoration(
              color: AppColors.accent,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '${_fmtUa(ua)} UA',
              style: monoStyle(
                size: 15,
                weight: FontWeight.w700,
                color: AppColors.onAccent,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Card Composição: linhas categoria + barra proporcional + "3 · 3,0" mono.
class _ComposicaoCard extends StatelessWidget {
  const _ComposicaoCard({required this.animals});

  final List<Animal> animals;

  @override
  Widget build(BuildContext context) {
    final counts = <String, int>{};
    for (final a in animals) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final present =
        kCategories.where((c) => (counts[c] ?? 0) > 0).toList();
    final total = animals.length;

    return SectionCard(
      title: 'Composição',
      child: present.isEmpty
          ? const Text(
              'Sem animais ativos.',
              style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
            )
          : Column(
              children: [
                for (final (i, cat) in present.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  Row(
                    children: [
                      SizedBox(
                        width: 88,
                        child: Text(
                          kCategoryLabelsPlural[cat]!,
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      Expanded(
                        child: StackedBar(
                          height: 10,
                          segments: [
                            StackedBarSegment(
                              total > 0 ? counts[cat]! / total : 0,
                              _compositionColors[i % _compositionColors.length],
                            ),
                          ],
                        ),
                      ),
                      SizedBox(
                        width: 62,
                        child: Text(
                          '${counts[cat]} · ${_fmtUa(counts[cat]! * (kUaWeights[cat] ?? 0))}',
                          textAlign: TextAlign.right,
                          style: monoStyle(size: 13),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ),
    );
  }
}

/// Card Animais: linhas 48h — nº mono + categoria·raça + EC.
class _AnimaisCard extends ConsumerStatefulWidget {
  const _AnimaisCard({
    required this.lotId,
    required this.animalsAsync,
    required this.lot,
    required this.canEdit,
  });

  final String lotId;
  final AsyncValue<List<Animal>> animalsAsync;
  final Lot lot;
  final bool canEdit;

  @override
  ConsumerState<_AnimaisCard> createState() => _AnimaisCardState();
}

class _AnimaisCardState extends ConsumerState<_AnimaisCard> {
  /// Modo seleção (item 6 dos ajustes 2026-08-20): checkboxes por animal +
  /// "todos" + mover em massa via bulk_upsert_animals (1 chamada atômica).
  bool _selecting = false;
  final Set<String> _selected = {};
  bool _moving = false;

  String get lotId => widget.lotId;

  Future<void> _moveSelected(List<Animal> active) async {
    final lots = (ref.read(loteListByPropertyProvider).asData?.value ??
            const <Lot>[])
        .where((l) => l.id != widget.lot.id)
        .toList();
    if (lots.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nenhum outro lote ativo para receber os animais.')));
      return;
    }
    final dest = await showDialog<Lot>(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text('Mover ${_selected.length} '
            '${_selected.length == 1 ? 'animal' : 'animais'} para:'),
        children: [
          for (final l in lots)
            SimpleDialogOption(
              onPressed: () => Navigator.of(ctx).pop(l),
              child: Text(l.name, style: const TextStyle(fontSize: 15)),
            ),
        ],
      ),
    );
    if (dest == null || !mounted) return;

    setState(() => _moving = true);
    try {
      final rows = [
        for (final a in active)
          if (_selected.contains(a.id))
            {
              'number': a.number,
              'category': a.category,
              'lot_name': dest.name,
            },
      ];
      await ref
          .read(bulkRepositoryProvider)
          .upsertAnimals(widget.lot.propertyId, rows);
      ref.invalidatePropertyData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${rows.length} '
            '${rows.length == 1 ? 'animal movido' : 'animais movidos'} '
            'para ${dest.name}'),
      ));
      setState(() {
        _selecting = false;
        _selected.clear();
      });
    } on BulkImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _moving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = widget.animalsAsync;
    return animalsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: ErrorRetry(
            message: 'Erro ao carregar animais.',
            onRetry: () => ref.invalidate(animalListByLotProvider(lotId)),
          ),
        ),
      ),
      data: (animals) {
        final active = animals.where((a) => a.deletedAt == null).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        if (active.isEmpty) {
          return const Card(
            child: EmptyState(
              icon: Icons.pets_outlined,
              title: 'Nenhum animal neste lote',
              message: 'Use o botão + para adicionar animais individualmente.',
            ),
          );
        }
        return SectionCard(
          title: 'Animais',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (widget.canEdit && widget.lot.deletedAt == null)
                TextButton(
                  onPressed: _moving
                      ? null
                      : () => setState(() {
                            _selecting = !_selecting;
                            _selected.clear();
                          }),
                  child: Text(_selecting ? 'Cancelar' : 'Selecionar'),
                ),
              Text(
                '${active.length}',
                style: monoStyle(size: 12, color: AppColors.textSecondary),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(
            children: [
              if (_selecting)
                Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  decoration: const BoxDecoration(
                    border:
                        Border(bottom: BorderSide(color: AppColors.divider)),
                  ),
                  child: Row(
                    children: [
                      Checkbox(
                        tristate: true,
                        value: _selected.isEmpty
                            ? false
                            : _selected.length == active.length
                                ? true
                                : null,
                        onChanged: (v) => setState(() {
                          if (v ?? false) {
                            _selected.addAll(active.map((a) => a.id));
                          } else {
                            _selected.clear();
                          }
                        }),
                      ),
                      const Text('Selecionar todos',
                          style: TextStyle(fontSize: 14)),
                      const Spacer(),
                      FilledButton.icon(
                        onPressed: _selected.isEmpty || _moving
                            ? null
                            : () => _moveSelected(active),
                        icon: _moving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.swap_horiz, size: 18),
                        label: Text('Mover ${_selected.length}'),
                      ),
                    ],
                  ),
                ),
              for (final (i, a) in active.indexed)
                InkWell(
                  onTap: _selecting
                      ? () => setState(() {
                            if (!_selected.remove(a.id)) _selected.add(a.id);
                          })
                      : () => context.go(AppRoutes.animalDetail(a.id)),
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 48),
                    decoration: i > 0
                        ? const BoxDecoration(
                            border: Border(
                              top: BorderSide(color: AppColors.divider),
                            ),
                          )
                        : null,
                    child: Row(
                      children: [
                        if (_selecting)
                          Checkbox(
                            value: _selected.contains(a.id),
                            onChanged: (v) => setState(() {
                              if (v ?? false) {
                                _selected.add(a.id);
                              } else {
                                _selected.remove(a.id);
                              }
                            }),
                          ),
                        SizedBox(
                          width: 42,
                          child: Text(
                            '${a.number}',
                            style: monoStyle(
                              size: 16,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            [
                              kCategoryLabels[a.category] ?? a.category,
                              if (a.breed != null && a.breed!.isNotEmpty)
                                a.breed!,
                            ].join(' · '),
                            style: const TextStyle(fontSize: 14.5),
                          ),
                        ),
                        if (a.bodyCondition != null)
                          Text(
                            'EC ${a.bodyCondition}',
                            style: monoStyle(
                              size: 12.5,
                              color: AppColors.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
