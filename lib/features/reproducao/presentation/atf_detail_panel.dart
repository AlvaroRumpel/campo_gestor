import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Painel lateral desktop de 380px com o resumo do ciclo ATF (quick task
/// 260813-r4s) — mestre-detalhe em `ReproducaoScreen` a partir de
/// `Breakpoints.rail`. Molde: `animal_detail_panel.dart`.
class AtfDetailPanel extends ConsumerWidget {
  const AtfDetailPanel({super.key, required this.summary, required this.onClose});

  final AtfSummary summary;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atf = summary.atf;
    final dg = summary.dgSummary;
    final hasPending = atf.active && dg.pending > 0;
    // Same rule as ReproducaoTableView/_AtfCard: closed ATFs report zero
    // active memberships, so the denominator never falls below the DG total.
    final denominador = math.max(summary.animalCount, dg.total);
    final bullName = atf.bullName;
    final hasBull = bullName != null && bullName.trim().isNotEmpty;

    final activeMemberships =
        ref.watch(atfActiveMembershipsProvider(atf.id)).asData?.value ??
            const [];
    final dgRecords =
        ref.watch(dgRecordsByAtfProvider(atf.id)).asData?.value ?? const [];
    final dgAnimalIds = dgRecords.map((r) => r.animalId).toSet();
    final semDg = activeMemberships
        .where((m) => !m.animalDeleted && !dgAnimalIds.contains(m.animalId))
        .toList();

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
                        'Ciclo ATF',
                        color: AppColors.onGreenSecondary,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.open_in_full,
                          color: AppColors.onGreen, size: 20),
                      tooltip: 'Abrir ciclo',
                      onPressed: () =>
                          context.go(AppRoutes.atfDetail(atf.id)),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close,
                          color: AppColors.onGreen, size: 20),
                      onPressed: onClose,
                    ),
                  ],
                ),
                Text(
                  atf.name,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.onGreen,
                  ),
                ),
                const SizedBox(height: 8),
                if (!atf.active)
                  const StatusChip('Encerrado', kind: StatusKind.neutral)
                else if (hasPending)
                  StatusChip(
                    dg.pending == 1
                        ? '1 DG pendente'
                        : '${dg.pending} DGs pendentes',
                    kind: StatusKind.warning,
                  )
                else if (dg.total > 0)
                  const StatusChip('Completo', kind: StatusKind.positive),
              ],
            ),
          ),
          // Linha de stats
          StatsStrip(
            child: Wrap(
              spacing: 16,
              runSpacing: 6,
              children: [
                _PanelStat(label: 'fêmeas', value: '${summary.animalCount}'),
                _PanelStat(label: 'DGs feitos', value: '${dg.total}'),
                _PanelStat(
                  label: 'prenhez',
                  value: dg.percent == null ? '—' : '${dg.percent}%',
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
                  const OverlineLabel('Protocolo'),
                  const SizedBox(height: 8),
                  _PanelStat(
                    label: 'implante',
                    value: _dateFmt.format(atf.implantationDate),
                  ),
                  const SizedBox(height: 6),
                  _PanelStat(
                    label: 'inseminação',
                    value: _dateFmt.format(atf.inseminationDate),
                  ),
                  if (hasBull) ...[
                    const SizedBox(height: 6),
                    _PanelStat(label: 'touro', value: bullName, mono: false),
                  ],
                  const SizedBox(height: 16),
                  StackedBar(
                    height: 8,
                    segments: denominador == 0
                        ? const []
                        : [
                            StackedBarSegment(
                              dg.pregnant / denominador,
                              AppColors.primary,
                            ),
                            StackedBarSegment(
                              (dg.total - dg.pregnant) / denominador,
                              AppColors.accent,
                            ),
                          ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${dg.total} / $denominador DGs',
                    style: monoStyle(size: 12, color: AppColors.textSecondary),
                  ),
                  if (semDg.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    OverlineLabel('Sem DG (${dg.pending})'),
                    const SizedBox(height: 8),
                    for (final m in semDg.take(6)) _SemDgRow(m),
                    if (semDg.length > 6)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          'e mais ${semDg.length - 6}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textTertiary,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
          // Rodapé
          Container(
            padding: const EdgeInsets.all(12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: () => context.go(AppRoutes.atfDetail(atf.id)),
                child: Text(
                  hasPending ? 'Continuar DGs (${dg.pending})' : 'Abrir ciclo',
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Uma linha "#numero · Categoria" da lista "Sem DG" (assunção 9).
class _SemDgRow extends StatelessWidget {
  const _SemDgRow(this.membership);

  final AtfMembershipView membership;

  @override
  Widget build(BuildContext context) {
    final categoryLabel =
        kCategoryLabels[membership.animalCategory] ?? membership.animalCategory;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Text(
            '#${membership.animalNumber}',
            style: monoStyle(size: 13, weight: FontWeight.w700),
          ),
          const SizedBox(width: 6),
          Text(
            '· $categoryLabel',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
        ],
      ),
    );
  }
}

/// "LABEL valor" da linha de stats do painel — [mono] estiliza o valor com
/// [monoStyle] (números/datas); textos (touro) usam a fonte padrão. Mirrors
/// `animal_detail_panel.dart`'s `_PanelStat`.
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
