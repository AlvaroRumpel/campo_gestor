import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../reproducao/data/dg_summary.dart';
import '../../sanitario/presentation/aplicacao_form_dialog.dart';
import '../data/lote_repository.dart';
import 'mover_lote_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

String _fmtUa(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Cores das barras de composição por linha — mesma lista de
/// `lote_detail_screen.dart`'s `_ComposicaoCard`.
const _compositionColors = [
  AppColors.primary,
  AppColors.greenMid,
  AppColors.greenLight,
];

/// Painel lateral desktop de 380px com o resumo do lote (quick task
/// 260813-ugd) — mestre-detalhe em `PiquetesScreen` a partir de
/// `Breakpoints.rail`. Molde: `atf_detail_panel.dart` / `animal_detail_panel.dart`.
/// Reusa as ações existentes de `LoteDetailScreen` (Aplicação / Mover lote).
class LoteDetailPanel extends ConsumerStatefulWidget {
  const LoteDetailPanel({
    super.key,
    required this.item,
    required this.activeAnimals,
    required this.lastApplication,
    required this.canEdit,
    required this.onClose,
  });

  final LotWithPaddockCount item;
  final List<Animal> activeAnimals;
  final DateTime? lastApplication;
  final bool canEdit;
  final VoidCallback onClose;

  @override
  ConsumerState<LoteDetailPanel> createState() => _LoteDetailPanelState();
}

class _LoteDetailPanelState extends ConsumerState<LoteDetailPanel> {
  void _invalidate() => ref.invalidatePropertyData();

  Future<void> _onAplicacao() async {
    final lotId = widget.item.lot.id;
    await showDialog<void>(
      context: context,
      builder: (_) => AplicacaoFormDialog(
        lotId: lotId,
        onRegistered: (count) {
          if (!mounted) return;
          _invalidate();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sanitaryRegisteredMessage(count))),
          );
        },
      ),
    );
  }

  Future<void> _onMover() async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverLoteDialog(
        lot: widget.item.lot,
        activeAnimalCount: widget.activeAnimals.length,
      ),
    );
    if (result != null && mounted) {
      _invalidate();
      final paddockName = result['paddockName'] ?? '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Lote movido para $paddockName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final lot = item.lot;
    final activeAnimals = widget.activeAnimals;
    final ua = calcTotalUa(activeAnimals);
    final total = activeAnimals.length;
    final showActions =
        widget.canEdit && lot.deletedAt == null && activeAnimals.isNotEmpty;

    final reproStatusMap =
        ref.watch(animalReproStatusByPropertyProvider).asData?.value ??
            const <String, AnimalReproStatus>{};

    final counts = <String, int>{};
    for (final a in activeAnimals) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final present = kCategories.where((c) => (counts[c] ?? 0) > 0).toList();

    final sortedAnimals = [...activeAnimals]
      ..sort((a, b) => a.number.compareTo(b.number));

    return Container(
      width: 380,
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header verde
          Container(
            color: AppColors.primary,
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: OverlineLabel(
                        'Lote',
                        color: AppColors.onGreenSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full,
                          color: AppColors.onGreen, size: 20),
                      tooltip: 'Abrir lote',
                      onPressed: () =>
                          context.push(AppRoutes.loteDetail(lot.id)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.onGreen, size: 20),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            lot.name,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: AppColors.onGreen,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.paddockName} · $total '
                            '${total == 1 ? 'animal ativo' : 'animais ativos'}',
                            style: const TextStyle(
                              fontSize: 13.5,
                              color: AppColors.onGreenSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
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
              ],
            ),
          ),
          if (showActions)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _onAplicacao,
                      icon: const Icon(Icons.medical_services_outlined, size: 20),
                      label: const Text('Aplicação'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _onMover,
                      icon: const Icon(Icons.swap_horiz, size: 20),
                      label: const Text('Mover lote'),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineLabel('Composição'),
                  const SizedBox(height: 8),
                  if (present.isEmpty)
                    const Text(
                      'Sem animais ativos.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: AppColors.textSecondary,
                      ),
                    )
                  else
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
                              '${counts[cat]} · '
                              '${_fmtUa(counts[cat]! * (kUaWeights[cat] ?? 0))}',
                              textAlign: TextAlign.right,
                              style: monoStyle(size: 13),
                            ),
                          ),
                        ],
                      ),
                    ],
                  const SizedBox(height: 16),
                  const OverlineLabel('Animais'),
                  const SizedBox(height: 8),
                  for (final a in sortedAnimals.take(6))
                    _AnimalRow(animal: a, reproStatus: reproStatusMap[a.id]),
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.animais),
                    child: Text('Ver os $total na lista de animais'),
                  ),
                ],
              ),
            ),
          ),
          if (widget.lastApplication != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'última aplicação ',
                    style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                  ),
                  Text(
                    _dateFmt.format(widget.lastApplication!),
                    style: monoStyle(size: 12.5, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Uma linha "#número · categoria · raça" da lista de animais do painel.
class _AnimalRow extends StatelessWidget {
  const _AnimalRow({required this.animal, required this.reproStatus});

  final Animal animal;
  final AnimalReproStatus? reproStatus;

  @override
  Widget build(BuildContext context) {
    final categoryLabel = kCategoryLabels[animal.category] ?? animal.category;
    final breed = animal.breed;
    final line = breed == null || breed.trim().isEmpty
        ? categoryLabel
        : '$categoryLabel · $breed';
    final showRepro =
        reproStatus != null && reproStatus != AnimalReproStatus.foraDoAtf;

    return InkWell(
      onTap: () => context.go(AppRoutes.animalDetail(animal.id)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                '${animal.number}',
                style: monoStyle(size: 15, weight: FontWeight.w700),
              ),
            ),
            Expanded(
              child: Text(
                line,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 13.5),
              ),
            ),
            if (showRepro) ...[
              StatusChip(reproStatus!.label, kind: reproStatus!.chipKind),
              const SizedBox(width: 6),
            ],
            if (animal.bodyCondition != null)
              Text(
                'EC ${animal.bodyCondition}',
                style: monoStyle(size: 12.5, color: AppColors.textSecondary),
              ),
          ],
        ),
      ),
    );
  }
}
