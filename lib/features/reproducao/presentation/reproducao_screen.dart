import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/data/property_repository.dart';
import '../data/atf_repository.dart';
import 'atf_detail_panel.dart';
import 'atf_form_dialog.dart';
import 'reproducao_table_view.dart';

/// ATF list screen (`/reproducao` shell branch, D-01), redesign spec 4.8.
///
/// Separates active from closed ATFs via the "Ativos N" / "Encerrados N"
/// filter chips (D-01, D-03). A partir do breakpoint de rail, tabela densa +
/// [AtfDetailPanel] mestre-detalhe (quick task 260813-r4s).
class ReproducaoScreen extends ConsumerStatefulWidget {
  const ReproducaoScreen({super.key});

  @override
  ConsumerState<ReproducaoScreen> createState() => _ReproducaoScreenState();
}

class _ReproducaoScreenState extends ConsumerState<ReproducaoScreen> {
  bool _showEncerrados = false;
  String? _selectedAtfId;

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

  Future<void> _openCreateForm(SelectedProperty property) async {
    final newId = await showAdaptiveForm<String>(
      context: context,
      builder: (_) => AtfFormDialog(propertyId: property.id),
    );
    if (newId != null && mounted) {
      context.go(AppRoutes.atfDetail(newId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final atfsAsync = ref.watch(atfListByPropertyProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final currentProperty = currentPropAsync.asData?.value;
    final canEdit = _canEdit(currentProperty, membersAsync.asData?.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.rail;

        return Scaffold(
          appBar: const CampoAppBar(title: 'Reprodução'),
          body: atfsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => const Center(
              child: Text(
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
              ),
            ),
            data: (atfs) {
              final ativos = atfs.where((s) => s.atf.active).toList();
              final encerrados = atfs.where((s) => !s.atf.active).toList();
              final shown = _showEncerrados ? encerrados : ativos;

              if (!isDesktop) {
                // <1024px: byte-a-byte o comportamento atual, sem alteração.
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(14, 8, 14, 4),
                      child: Row(
                        children: [
                          AtfScopeChip(
                            label: 'Ativos',
                            count: ativos.length,
                            selected: !_showEncerrados,
                            onTap: () =>
                                setState(() => _showEncerrados = false),
                          ),
                          const SizedBox(width: 8),
                          AtfScopeChip(
                            label: 'Encerrados',
                            count: encerrados.length,
                            selected: _showEncerrados,
                            onTap: () =>
                                setState(() => _showEncerrados = true),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: shown.isEmpty
                          ? (atfs.isEmpty
                              ? const EmptyState(
                                  icon: Icons.favorite_border,
                                  title: 'Nenhum ATF cadastrado',
                                  message:
                                      'Crie um ATF para iniciar um ciclo reprodutivo.',
                                )
                              : _showEncerrados
                                  ? const EmptyState(
                                      icon: Icons.favorite_border,
                                      title: 'Nenhum ATF encerrado',
                                      message:
                                          'ATFs encerrados aparecem aqui como histórico.',
                                    )
                                  : const EmptyState(
                                      icon: Icons.favorite_border,
                                      title: 'Nenhum ATF ativo',
                                      message:
                                          "Toque em 'Encerrados' para ver o histórico.",
                                    ))
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(vertical: 6),
                              itemCount: shown.length,
                              itemBuilder: (context, i) =>
                                  _AtfCard(summary: shown[i]),
                            ),
                    ),
                  ],
                );
              }

              // >=1024px: tabela densa + painel lateral mestre-detalhe.
              final selected =
                  shown.where((s) => s.atf.id == _selectedAtfId).firstOrNull;

              return Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: ReproducaoTableView(
                      ativos: ativos,
                      encerrados: encerrados,
                      shown: shown,
                      showEncerrados: _showEncerrados,
                      onShowEncerradosChanged: (v) =>
                          setState(() => _showEncerrados = v),
                      selectedId: selected?.atf.id,
                      onSelect: (id) => setState(() => _selectedAtfId = id),
                      canEdit: canEdit,
                      onCreate: currentProperty == null
                          ? () {}
                          : () => _openCreateForm(currentProperty),
                    ),
                  ),
                  if (selected != null)
                    AtfDetailPanel(
                      key: ValueKey(selected.atf.id),
                      summary: selected,
                      onClose: () => setState(() => _selectedAtfId = null),
                    ),
                ],
              );
            },
          ),
          floatingActionButton:
              (!isDesktop && canEdit && currentProperty != null)
                  ? FloatingActionButton.extended(
                      icon: const Icon(Icons.add),
                      label: const Text('Novo ATF'),
                      onPressed: () => _openCreateForm(currentProperty),
                    )
                  : null,
        );
      },
    );
  }
}

/// One ATF card (D-04, spec 4.8). Percentages come exclusively from
/// [DgSummary] — no local percentage arithmetic beyond bar fractions.
class _AtfCard extends StatelessWidget {
  const _AtfCard({required this.summary});

  final AtfSummary summary;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM');
    final atf = summary.atf;
    final dg = summary.dgSummary;

    final hasPending = atf.active && dg.pending > 0;
    // Closed ATFs report zero active memberships — fall back to the DG total
    // so "N / M DGs feitos" never shows a denominator below the numerator.
    final denominator = math.max(summary.animalCount, dg.total);
    final percent = dg.percent;

    final metaTail = atf.bullName != null
        ? TextSpan(text: ' · touro: ${atf.bullName}')
        : TextSpan(
            children: [
              const TextSpan(text: ' · '),
              TextSpan(
                text: '${summary.animalCount}',
                style: monoStyle(size: 12.5, weight: FontWeight.w600),
              ),
              const TextSpan(text: ' animais'),
            ],
          );

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Material(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.go(AppRoutes.atfDetail(atf.id)),
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (hasPending)
                  const SizedBox(
                    width: 4,
                    child: ColoredBox(color: AppColors.accent),
                  ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                atf.name,
                                style: const TextStyle(
                                  fontSize: 17.5,
                                  fontWeight: FontWeight.w700,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            if (!atf.active)
                              const StatusChip('Encerrado',
                                  kind: StatusKind.neutral)
                            else if (hasPending)
                              StatusChip(
                                dg.pending == 1
                                    ? '1 DG pendente'
                                    : '${dg.pending} DGs pendentes',
                                kind: StatusKind.warning,
                              )
                            else if (dg.total > 0)
                              const StatusChip('Completo',
                                  kind: StatusKind.positive),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (percent == null)
                          const Text(
                            '— · aguardando DG',
                            style: TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          )
                        else
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text.rich(
                                TextSpan(
                                  children: [
                                    TextSpan(
                                      text: '$percent',
                                      style: monoStyle(
                                        size: 34,
                                        weight: FontWeight.w700,
                                        color: AppColors.primary,
                                        height: 1,
                                      ),
                                    ),
                                    TextSpan(
                                      text: '%',
                                      style: monoStyle(
                                        size: 16,
                                        weight: FontWeight.w700,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Padding(
                                padding: EdgeInsets.only(bottom: 2),
                                child: Text(
                                  'prenhez',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    '${dg.total} / $denominator',
                                    style: monoStyle(
                                      size: 14,
                                      weight: FontWeight.w600,
                                    ),
                                  ),
                                  const Text(
                                    'DGs feitos',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      color: AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        const SizedBox(height: 10),
                        StackedBar(
                          height: 6,
                          segments: denominator == 0
                              ? const []
                              : [
                                  StackedBarSegment(
                                    dg.pregnant / denominator,
                                    AppColors.primary,
                                  ),
                                  StackedBarSegment(
                                    (dg.total - dg.pregnant) / denominator,
                                    AppColors.accent,
                                  ),
                                ],
                        ),
                        const SizedBox(height: 10),
                        Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 12.5,
                              color: AppColors.textSecondary,
                            ),
                            children: [
                              const TextSpan(text: 'impl. '),
                              TextSpan(
                                text: dateFmt.format(atf.implantationDate),
                                style: monoStyle(
                                  size: 12.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(text: ' · insem. '),
                              TextSpan(
                                text: dateFmt.format(atf.inseminationDate),
                                style: monoStyle(
                                  size: 12.5,
                                  weight: FontWeight.w600,
                                ),
                              ),
                              metaTail,
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (hasPending) ...[
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppColors.surfaceVariant,
                                foregroundColor: AppColors.primaryDarkText,
                                textStyle: const TextStyle(
                                  fontFamily: AppFonts.ui,
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              icon: const Icon(Icons.fact_check_outlined,
                                  size: 20),
                              label: const Text('Continuar DGs'),
                              onPressed: () =>
                                  context.go(AppRoutes.atfDetail(atf.id)),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
