import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../reproducao/data/dg_summary.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';
import 'animal_edit_dialog.dart';
import 'animal_timeline.dart';
import 'baixa_dialog.dart';
import 'mover_animal_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

String _fmtUa(double ua) => ua.toStringAsFixed(1).replaceAll('.', ',');

/// Painel lateral desktop de 380px com o resumo da ficha (Task 2, quick
/// task 260813-p10) — mestre-detalhe em `AnimaisScreen` a partir de
/// `Breakpoints.rail`. Reusa [AnimalTimelineCard] (mesmo widget da ficha,
/// zero duplicação de lógica de eventos) e as mesmas ações/diálogos.
class AnimalDetailPanel extends ConsumerStatefulWidget {
  const AnimalDetailPanel({
    super.key,
    required this.item,
    required this.canEdit,
    required this.onClose,
  });

  final AnimalWithContext item;
  final bool canEdit;
  final VoidCallback onClose;

  @override
  ConsumerState<AnimalDetailPanel> createState() => _AnimalDetailPanelState();
}

class _AnimalDetailPanelState extends ConsumerState<AnimalDetailPanel> {
  AnimalTimelineFilter _filter = AnimalTimelineFilter.tudo;
  bool _showAllEvents = false;

  void _invalidate() {
    ref.invalidate(animalListByPropertyProvider);
    ref.invalidate(animalByIdProvider(widget.item.animal.id));
    ref.invalidate(animalReproStatusByPropertyProvider);
  }

  Future<void> _onEdit() async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => AnimalEditDialog(animal: widget.item.animal),
    );
    if (ok == true) _invalidate();
  }

  Future<void> _onMover() async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverAnimalDialog(animal: widget.item.animal),
    );
    if (result != null && mounted) _invalidate();
  }

  Future<void> _onBaixa() async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => BaixaDialog(animal: widget.item.animal),
    );
    if (ok == true) _invalidate();
  }

  static String _baixaReasonLabel(String? reason) => switch (reason) {
        'sale' => 'Vendido',
        'death' => 'Morto',
        'discard' => 'Descartado',
        _ => 'Arquivado',
      };

  @override
  Widget build(BuildContext context) {
    final animal = widget.item.animal;
    final isActive = animal.deletedAt == null;
    final categoryLabel = kCategoryLabels[animal.category] ?? animal.category;
    final breed = animal.breed;
    final categoryLine = breed == null || breed.trim().isEmpty
        ? categoryLabel
        : '$categoryLabel · $breed';
    final ua = kUaWeights[animal.category] ?? 0.0;

    final reproStatusMap =
        ref.watch(animalReproStatusByPropertyProvider).asData?.value ??
            const <String, AnimalReproStatus>{};
    final reproStatus =
        reproStatusMap[animal.id] ?? AnimalReproStatus.foraDoAtf;

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
                        'Ficha do animal',
                        color: AppColors.onGreenSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full,
                          color: AppColors.onGreen, size: 20),
                      tooltip: 'Abrir ficha',
                      onPressed: () =>
                          context.go(AppRoutes.animalDetail(animal.id)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.onGreen, size: 20),
                      onPressed: widget.onClose,
                    ),
                  ],
                ),
                Text(
                  '#${animal.number}',
                  style: monoStyle(
                    size: 32,
                    weight: FontWeight.w600,
                    color: AppColors.onGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  categoryLine,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.onGreenSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                StatusChip(reproStatus.label, kind: reproStatus.chipKind),
              ],
            ),
          ),
          // Linha de stats
          StatsStrip(
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _PanelStat(label: 'UA', value: _fmtUa(ua)),
                _PanelStat(
                  label: 'Lote',
                  value: widget.item.lotName,
                  mono: false,
                ),
                _PanelStat(
                  label: 'Piquete',
                  value: widget.item.paddockName,
                  mono: false,
                ),
                _PanelStat(
                  label: 'desde',
                  value: _dateFmt.format(animal.createdAt.toLocal()),
                ),
              ],
            ),
          ),
          if (!isActive)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.dangerContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.info_outline,
                        size: 16, color: AppColors.onDangerContainer),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        animal.baixaDate == null
                            ? _baixaReasonLabel(animal.baixaReason)
                            : '${_baixaReasonLabel(animal.baixaReason)} em '
                                '${_dateFmt.format(animal.baixaDate!)}',
                        style: const TextStyle(
                          fontSize: 12,
                          height: 1.35,
                          color: AppColors.onDangerContainer,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
            child: AnimalTimelineFilterChips(
              value: _filter,
              onChanged: (f) => setState(() => _filter = f),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 10),
              child: AnimalTimelineCard(
                animal: animal,
                filter: _filter,
                collapsedCount: 5,
                showAll: _showAllEvents,
                onShowAll: () => setState(() => _showAllEvents = true),
              ),
            ),
          ),
          if (widget.canEdit)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: const BoxDecoration(
                border: Border(top: BorderSide(color: AppColors.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _onEdit,
                      child: const Text('Editar'),
                    ),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _onMover,
                        child: const Text('Mover'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 44,
                      height: 44,
                      child: OutlinedButton(
                        onPressed: _onBaixa,
                        style: OutlinedButton.styleFrom(
                          padding: EdgeInsets.zero,
                          side: BorderSide(
                            color: AppColors.danger.withValues(alpha: 0.30),
                          ),
                          foregroundColor: AppColors.danger,
                        ),
                        child: const Tooltip(
                          message: 'Dar baixa',
                          child: Icon(Icons.arrow_downward,
                              size: 20, color: AppColors.danger),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// "LABEL valor" da linha de stats do painel — [mono] estiliza o valor com
/// [monoStyle] (UA/datas); textos (lote/piquete) usam a fonte padrão.
class _PanelStat extends StatelessWidget {
  const _PanelStat({required this.label, required this.value, this.mono = true});

  final String label;
  final String value;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label ',
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
        Text(
          value,
          style: mono
              ? monoStyle(size: 12.5, weight: FontWeight.w600)
              : const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
