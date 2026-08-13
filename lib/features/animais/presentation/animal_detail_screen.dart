import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_repository.dart';
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
        body: const Center(child: Text('Erro ao carregar animal.')),
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
          body: ListView(
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
                      onShowAll: () => setState(() => _showAllEvents = true),
                    ),
                  ],
                ),
              ),
            ],
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
                side: const BorderSide(color: Color(0x4DA32D14)),
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
  const _StateCard({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final observation = animal.observation?.trim();
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
                    if (animal.bodyCondition != null)
                      // FittedBox: EcMeter tem largura fixa (~150px) e a
                      // coluna esmaga a 360px de viewport.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: EcMeter(score: animal.bodyCondition!),
                      )
                    else
                      const Text('—',
                          style: TextStyle(color: AppColors.textSecondary)),
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
                    Text(
                      observation == null || observation.isEmpty
                          ? '—'
                          : observation,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
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
