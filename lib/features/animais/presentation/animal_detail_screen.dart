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
import '../../lotes/data/lote_repository.dart';
import '../../reproducao/data/atf_model.dart';
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

/// Ficha do animal — timeline (spec 4.4, tela core).
///
/// Header verde com hero `#N` + badge UA circular + tiles glass Lote/Piquete;
/// barra de ações (vet only); card de estado (EC + observação); timeline
/// única mesclando eventos reprodutivos e sanitários (spec 3.11), lida dos
/// providers já existentes das features reproducao/sanitario.
class AnimalDetailScreen extends ConsumerStatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId});
  final String animalId;

  @override
  ConsumerState<AnimalDetailScreen> createState() =>
      _AnimalDetailScreenState();
}

class _AnimalDetailScreenState extends ConsumerState<AnimalDetailScreen> {
  AnimalTimelineFilter _filter = AnimalTimelineFilter.tudo;
  bool _showAllEvents = false;

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

  Future<void> _onEdit(Animal animal) async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => AnimalEditDialog(animal: animal),
    );
    if (ok == true) {
      ref.invalidate(animalByIdProvider(widget.animalId));
    }
  }

  Future<void> _onBaixa(Animal animal) async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => BaixaDialog(animal: animal),
    );
    if (ok == true) {
      ref.invalidate(animalByIdProvider(widget.animalId));
    }
  }

  Future<void> _onMover(Animal animal) async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverAnimalDialog(animal: animal),
    );
    if (result != null && mounted) {
      final lotName = result['lotName'] ?? '';
      ref.invalidate(animalByIdProvider(widget.animalId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Animal movido para $lotName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalAsync = ref.watch(animalByIdProvider(widget.animalId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final propertyName = currentPropAsync.asData?.value?.name;
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    final appBar = DetailAppBar(
      parentLabel: 'Animais',
      contextPill:
          propertyName == null ? null : FarmContextPill(name: propertyName),
    );

    return animalAsync.when(
      loading: () => Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: appBar,
        body: Center(
          child: ErrorRetry(
            message: 'Erro ao carregar animal.',
            onRetry: () =>
                ref.invalidate(animalByIdProvider(widget.animalId)),
          ),
        ),
      ),
      data: (animal) {
        if (animal == null) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: Text('Animal não encontrado.')),
          );
        }

        final isActive = animal.deletedAt == null;

        return Scaffold(
          appBar: appBar,
          body: LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= Breakpoints.rail) {
                return _DesktopFicha(
                  key: const Key('ficha-desktop'),
                  animal: animal,
                  canEdit: canEdit,
                  filter: _filter,
                  showAllEvents: _showAllEvents,
                  onFilterChanged: (f) => setState(() => _filter = f),
                  onShowAll: () => setState(() => _showAllEvents = true),
                  onEdit: () => _onEdit(animal),
                  onMover: () => _onMover(animal),
                  onBaixa: () => _onBaixa(animal),
                );
              }
              return ListView(
                padding: EdgeInsets.zero,
                children: [
                  _GreenHeader(animal: animal),
                  Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (!isActive) ...[
                          _BaixaBanner(animal: animal),
                          const SizedBox(height: 12),
                        ],
                        if (canEdit) ...[
                          _ActionBar(
                            isActive: isActive,
                            onEdit: () => _onEdit(animal),
                            onMover: () => _onMover(animal),
                            onBaixa: () => _onBaixa(animal),
                          ),
                          const SizedBox(height: 12),
                        ],
                        _StateCard(animal: animal),
                        const SizedBox(height: 12),
                        AnimalTimelineFilterChips(
                          value: _filter,
                          onChanged: (f) => setState(() => _filter = f),
                        ),
                        const SizedBox(height: 10),
                        AnimalTimelineCard(
                          animal: animal,
                          filter: _filter,
                          showAll: _showAllEvents,
                          onShowAll: () =>
                              setState(() => _showAllEvents = true),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header verde (spec 4.4)
// ---------------------------------------------------------------------------

class _GreenHeader extends ConsumerWidget {
  const _GreenHeader({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryLabel = kCategoryLabels[animal.category] ?? animal.category;
    final ua = kUaWeights[animal.category] ?? 0.0;
    final lotAsync = ref.watch(loteWithPaddockByIdProvider(animal.lotId));
    final lotData = lotAsync.asData?.value;

    // "raça · EC n/5 · desde dd/MM/yyyy" — números/datas em mono (regra 3).
    final metaSpans = <InlineSpan>[
      if (animal.breed != null && animal.breed!.trim().isNotEmpty)
        TextSpan(text: animal.breed),
      if (animal.bodyCondition != null)
        TextSpan(children: [
          const TextSpan(text: 'EC '),
          TextSpan(
            text: '${animal.bodyCondition}/5',
            style: monoStyle(size: 14, color: AppColors.onGreenSecondary),
          ),
        ]),
      TextSpan(children: [
        const TextSpan(text: 'desde '),
        TextSpan(
          text: _dateFmt.format(animal.createdAt.toLocal()),
          style: monoStyle(size: 14, color: AppColors.onGreenSecondary),
        ),
      ]),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${animal.number}',
                      style: monoStyle(
                        size: 44,
                        weight: FontWeight.w600,
                        color: AppColors.onGreen,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onGreenSecondary,
                        ),
                        children: [
                          for (var i = 0; i < metaSpans.length; i++) ...[
                            if (i > 0) const TextSpan(text: ' · '),
                            metaSpans[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UaBadge(ua: ua),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassTile(
                  label: 'Lote',
                  value: lotData?.lot.name ?? '—',
                  onTap: lotData == null
                      ? null
                      : () =>
                          context.go(AppRoutes.loteDetail(lotData.lot.id)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassTile(
                  label: 'Piquete',
                  value: lotData?.paddockName ?? '—',
                  onTap: lotData == null
                      ? null
                      : () => context
                          .go('/piquetes/${lotData.lot.paddockId}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge UA circular 66px laranja (spec 3.10).
class _UaBadge extends StatelessWidget {
  const _UaBadge({required this.ua});

  final double ua;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _fmtUa(ua),
            style: monoStyle(
              size: 19,
              weight: FontWeight.w700,
              color: AppColors.onAccent,
            ),
          ),
          const Text(
            'UA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra de ações (vet only)
// ---------------------------------------------------------------------------

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isActive,
    required this.onEdit,
    required this.onMover,
    required this.onBaixa,
  });

  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onMover;
  final VoidCallback onBaixa;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Editar'),
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onMover,
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: const Text('Mover'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              onPressed: onBaixa,
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
                    size: 22, color: AppColors.danger),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de estado (EC + observação)
// ---------------------------------------------------------------------------

class _StateCard extends StatelessWidget {
  const _StateCard({required this.animal, this.vertical = false});

  final Animal animal;

  /// Empilha EC + observação em coluna, em vez do padrão lado a lado
  /// (contexto desktop de 340px, Task 1 quick task 260813-q69). Nenhum
  /// texto/rótulo/estilo muda — só o eixo.
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    final observation = animal.observation?.trim();
    final ecWidget = animal.bodyCondition != null
        // FittedBox: EcMeter tem largura fixa (~150px) e a coluna esmaga a
        // 360px de viewport.
        ? FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: EcMeter(score: animal.bodyCondition!),
          )
        : const Text('—', style: TextStyle(color: AppColors.textSecondary));
    final observationWidget = Text(
      observation == null || observation.isEmpty ? '—' : observation,
      style: const TextStyle(
        fontSize: 13.5,
        height: 1.4,
        color: AppColors.ink,
      ),
    );

    if (vertical) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const OverlineLabel('Estado corporal'),
              const SizedBox(height: 8),
              ecWidget,
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              const OverlineLabel('Observação'),
              const SizedBox(height: 6),
              observationWidget,
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineLabel('Estado corporal'),
                    const SizedBox(height: 8),
                    ecWidget,
                  ],
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineLabel('Observação'),
                    const SizedBox(height: 6),
                    observationWidget,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Banner de baixa (D-12..D-15, SC-4) — anuncia algo que já aconteceu.
// ---------------------------------------------------------------------------

class _BaixaBanner extends StatelessWidget {
  const _BaixaBanner({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final reasonLabel = switch (animal.baixaReason) {
      'sale' => 'Vendido',
      'death' => 'Morto',
      'discard' => 'Descartado',
      _ => 'Arquivado',
    };
    final dateStr = animal.baixaDate != null
        ? ' em ${_dateFmt.format(animal.baixaDate!)}'
        : '';
    final observation = animal.observation;
    final hasObservation =
        observation != null && observation.trim().isNotEmpty;
    final text = hasObservation
        ? '$reasonLabel$dateStr — $observation'
        : '$reasonLabel$dateStr';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 20, color: AppColors.onDangerContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.onDangerContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Desktop (>= Breakpoints.rail, quick task 260813-q69) — header horizontal +
// corpo em duas colunas (contexto 340px / timeline até 760px). Reusa a
// timeline, o card de estado e os diálogos de ação já existentes; nenhuma
// segunda implementação de eventos.
// ---------------------------------------------------------------------------

class _DesktopFicha extends StatelessWidget {
  const _DesktopFicha({
    super.key,
    required this.animal,
    required this.canEdit,
    required this.filter,
    required this.showAllEvents,
    required this.onFilterChanged,
    required this.onShowAll,
    required this.onEdit,
    required this.onMover,
    required this.onBaixa,
  });

  final Animal animal;
  final bool canEdit;
  final AnimalTimelineFilter filter;
  final bool showAllEvents;
  final ValueChanged<AnimalTimelineFilter> onFilterChanged;
  final VoidCallback onShowAll;
  final VoidCallback onEdit;
  final VoidCallback onMover;
  final VoidCallback onBaixa;

  @override
  Widget build(BuildContext context) {
    final isActive = animal.deletedAt == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _WideHeader(
          animal: animal,
          canEdit: canEdit,
          onEdit: onEdit,
          onMover: onMover,
          onBaixa: onBaixa,
        ),
        Expanded(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 340,
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (!isActive) ...[
                        _BaixaBanner(animal: animal),
                        const SizedBox(height: 12),
                      ],
                      _StateCard(animal: animal, vertical: true),
                      const SizedBox(height: 12),
                      _ReproCard(animal: animal),
                    ],
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.topLeft,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 760),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AnimalTimelineFilterChips(
                            value: filter,
                            onChanged: onFilterChanged,
                          ),
                          const SizedBox(height: 10),
                          AnimalTimelineCard(
                            animal: animal,
                            filter: filter,
                            showAll: showAllEvents,
                            onShowAll: onShowAll,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Header verde horizontal do desktop: hero `#N` + categoria/raça + EC/desde
/// à esquerda, badge de status repro + stats UA/Lote/Piquete + ações à
/// direita — tudo em uma linha, quebrando em [Wrap] para não estourar perto
/// de 1024px.
class _WideHeader extends ConsumerWidget {
  const _WideHeader({
    required this.animal,
    required this.canEdit,
    required this.onEdit,
    required this.onMover,
    required this.onBaixa,
  });

  final Animal animal;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onMover;
  final VoidCallback onBaixa;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryLabel = kCategoryLabels[animal.category] ?? animal.category;
    final breed = animal.breed;
    final categoryLine = breed == null || breed.trim().isEmpty
        ? categoryLabel
        : '$categoryLabel · $breed';
    final ua = kUaWeights[animal.category] ?? 0.0;
    final isActive = animal.deletedAt == null;

    final reproStatusMap =
        ref.watch(animalReproStatusByPropertyProvider).asData?.value ??
            const <String, AnimalReproStatus>{};
    final reproStatus =
        reproStatusMap[animal.id] ?? AnimalReproStatus.foraDoAtf;

    final lotAsync = ref.watch(loteWithPaddockByIdProvider(animal.lotId));
    final lotData = lotAsync.asData?.value;

    // "EC n/5 · na fazenda desde dd/MM/yyyy" — omite EC quando ausente.
    final subtitleSpans = <InlineSpan>[
      if (animal.bodyCondition != null)
        TextSpan(children: [
          const TextSpan(text: 'EC '),
          TextSpan(
            text: '${animal.bodyCondition}/5',
            style: monoStyle(size: 13.5, color: AppColors.onGreenSecondary),
          ),
        ]),
      TextSpan(children: [
        const TextSpan(text: 'na fazenda desde '),
        TextSpan(
          text: _dateFmt.format(animal.createdAt.toLocal()),
          style: monoStyle(size: 13.5, color: AppColors.onGreenSecondary),
        ),
      ]),
    ];

    return Container(
      color: AppColors.primary,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '#${animal.number}',
                  style: monoStyle(
                    size: 52,
                    weight: FontWeight.w600,
                    color: AppColors.onGreen,
                    height: 1.05,
                  ),
                ),
                Text(
                  categoryLine,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.onGreen,
                  ),
                ),
                const SizedBox(height: 2),
                Text.rich(
                  TextSpan(
                    style: const TextStyle(
                      fontSize: 13.5,
                      color: AppColors.onGreenSecondary,
                    ),
                    children: [
                      for (var i = 0; i < subtitleSpans.length; i++) ...[
                        if (i > 0) const TextSpan(text: ' · '),
                        subtitleSpans[i],
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          // Flexible (não um Wrap "solto"): dentro de um Row, um filho
          // não-flex recebe largura de main-axis ilimitada e nunca quebra
          // sozinho — é preciso um flex para o Wrap ganhar uma largura
          // máxima real e passar a quebrar linha perto de 1024px.
          Flexible(
            child: Wrap(
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 16,
              runSpacing: 8,
              children: [
                StatusChip(reproStatus.label, kind: reproStatus.chipKind),
                _HeaderStat(label: 'UA', value: _fmtUa(ua)),
                _HeaderStat(
                  label: 'Lote',
                  value: lotData?.lot.name ?? '—',
                  mono: false,
                  maxWidth: 150,
                  onTap: lotData == null
                      ? null
                      : () =>
                          context.go(AppRoutes.loteDetail(lotData.lot.id)),
                ),
                _HeaderStat(
                  label: 'Piquete',
                  value: lotData?.paddockName ?? '—',
                  mono: false,
                  maxWidth: 150,
                  onTap: lotData == null
                      ? null
                      : () =>
                          context.go('/piquetes/${lotData.lot.paddockId}'),
                ),
                if (canEdit)
                  Wrap(
                    spacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      FilledButton.icon(
                        onPressed: onEdit,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.onGreen,
                          foregroundColor: AppColors.primary,
                        ),
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        label: const Text('Editar'),
                      ),
                      if (isActive) ...[
                        OutlinedButton.icon(
                          onPressed: onMover,
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppColors.onGreen,
                            side: BorderSide(
                              color:
                                  AppColors.onGreen.withValues(alpha: 0.45),
                            ),
                          ),
                          icon: const Icon(Icons.swap_horiz, size: 18),
                          label: const Text('Mover'),
                        ),
                        SizedBox(
                          width: 40,
                          height: 40,
                          child: OutlinedButton(
                            onPressed: onBaixa,
                            style: OutlinedButton.styleFrom(
                              padding: EdgeInsets.zero,
                              foregroundColor: AppColors.onGreen,
                              side: BorderSide(
                                color: AppColors.onGreen
                                    .withValues(alpha: 0.45),
                              ),
                            ),
                            child: const Tooltip(
                              message: 'Dar baixa',
                              child: Icon(Icons.arrow_downward,
                                  size: 20, color: AppColors.onGreen),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// "LABEL / valor" de uma stat do header desktop — [mono] estiliza o valor
/// com [monoStyle] (UA); textos (lote/piquete) usam a fonte padrão. Navegável
/// quando [onTap] é informado, mesma convenção do [GlassTile] mobile.
/// [maxWidth], quando informado, trunca o valor com reticências — nomes de
/// lote/piquete são texto livre e não podem crescer o header sem limite.
class _HeaderStat extends StatelessWidget {
  const _HeaderStat({
    required this.label,
    required this.value,
    this.mono = true,
    this.onTap,
    this.maxWidth,
  });

  final String label;
  final String value;
  final bool mono;
  final VoidCallback? onTap;
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    Widget valueText = Text(
      value,
      overflow: TextOverflow.ellipsis,
      maxLines: 1,
      style: mono
          ? monoStyle(
              size: 15,
              weight: FontWeight.w600,
              color: AppColors.onGreen,
            )
          : const TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w600,
              color: AppColors.onGreen,
            ),
    );
    if (maxWidth != null) {
      valueText = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth!),
        child: valueText,
      );
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label.toUpperCase(),
          style: const TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
            color: AppColors.onGreenSecondary,
          ),
        ),
        const SizedBox(height: 2),
        valueText,
      ],
    );
    if (onTap == null) return content;
    return InkWell(onTap: onTap, child: content);
  }
}

/// Card de reprodução da coluna de contexto desktop — o mesmo
/// `reproductiveHistoryByAnimalProvider` que a timeline já observa (zero
/// request extra) e o mesmo `animalReproStatusByPropertyProvider` do header.
/// Não re-mapeia [DgResult]: quem comunica prenhe/vazia/duvidosa é o badge,
/// que já vem pronto de [AnimalReproStatus].
class _ReproCard extends ConsumerWidget {
  const _ReproCard({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reproStatusMap =
        ref.watch(animalReproStatusByPropertyProvider).asData?.value ??
            const <String, AnimalReproStatus>{};
    final reproStatus =
        reproStatusMap[animal.id] ?? AnimalReproStatus.foraDoAtf;

    final historyAsync =
        ref.watch(reproductiveHistoryByAnimalProvider(animal.id));
    final entries =
        historyAsync.asData?.value ?? const <ReproductiveHistoryEntry>[];
    // O primeiro ciclo ativo, senão o primeiro da lista (ordenada por
    // inseminação desc).
    final entry = entries.isEmpty
        ? null
        : entries.firstWhere((e) => e.atfActive, orElse: () => entries.first);

    return SectionCard(
      title: 'Reprodução',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          StatusChip(reproStatus.label, kind: reproStatus.chipKind),
          const SizedBox(height: 10),
          if (entry == null)
            const Text(
              'Sem histórico reprodutivo.',
              style: TextStyle(color: AppColors.textSecondary),
            )
          else ...[
            Text(
              'ATF ${entry.atfName} · '
              '${entry.atfActive ? 'ciclo ativo' : 'ciclo encerrado'}',
              style: const TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: AppColors.ink,
              ),
            ),
            const SizedBox(height: 4),
            Text.rich(
              TextSpan(
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
                children: [
                  const TextSpan(text: 'insem. '),
                  TextSpan(
                    text: _dateFmt.format(entry.inseminationDate),
                    style: monoStyle(size: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            if (entry.bullName != null &&
                entry.bullName!.trim().isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                'touro: ${entry.bullName}',
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
            const SizedBox(height: 2),
            entry.lastDgDate != null
                ? Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(text: 'última DG '),
                        TextSpan(
                          text: _dateFmt.format(entry.lastDgDate!),
                          style: monoStyle(
                              size: 13, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  )
                : const Text(
                    'aguardando DG',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondary,
                    ),
                  ),
          ],
        ],
      ),
    );
  }
}
