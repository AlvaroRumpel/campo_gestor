import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../../reproducao/data/atf_model.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../reproducao/data/dg_record_model.dart';
import '../../sanitario/presentation/sanitary_history_section.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';
import 'animal_edit_dialog.dart';
import 'baixa_dialog.dart';
import 'mover_animal_dialog.dart';

/// Full animal record screen (Plan 06). Replaces the Plan 04 stub.
///
/// AppBar: '#N — Categoria'. Body: AnimalInfoCard + Histórico Reprodutivo +
/// Histórico Sanitário (SANI-05, D-25 — real section, no longer a Phase 6
/// placeholder). Veterinarian-only edit/baixa actions inside the card footer
/// (T-3-21, T-3-22).
class AnimalDetailScreen extends ConsumerWidget {
  const AnimalDetailScreen({super.key, required this.animalId});
  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final animalAsync = ref.watch(animalByIdProvider(animalId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return animalAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('Animal')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: AppBar(title: const Text('Animal')),
        body: const Center(child: Text('Erro ao carregar animal.')),
      ),
      data: (animal) {
        if (animal == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Animal')),
            body: const Center(child: Text('Animal não encontrado.')),
          );
        }

        final categoryLabel =
            kCategoryLabels[animal.category] ?? animal.category;

        return Scaffold(
          appBar: AppBar(
            title: Text('#${animal.number} — $categoryLabel'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AnimalInfoCard(
                animal: animal,
                canEdit: canEdit,
                onEdit: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AnimalEditDialog(animal: animal),
                  );
                  if (ok == true) {
                    ref.invalidate(animalByIdProvider(animalId));
                  }
                },
                onBaixa: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => BaixaDialog(animal: animal),
                  );
                  if (ok == true) {
                    ref.invalidate(animalByIdProvider(animalId));
                  }
                },
                onMover: () async {
                  final result = await showDialog<Map<String, String>>(
                    context: context,
                    builder: (_) => MoverAnimalDialog(animal: animal),
                  );
                  if (result != null && context.mounted) {
                    final lotName = result['lotName'] ?? '';
                    ref.invalidate(animalByIdProvider(animalId));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Animal movido para $lotName')),
                    );
                  }
                },
              ),
              const SizedBox(height: 16),
              _ReproductiveHistorySection(animalId: animal.id),
              const SizedBox(height: 16),
              AnimalSanitaryHistorySection(animalId: animal.id),
            ],
          ),
        );
      },
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

/// Info card with animal fields + veterinarian-only action buttons.
class AnimalInfoCard extends ConsumerWidget {
  const AnimalInfoCard({
    super.key,
    required this.animal,
    required this.canEdit,
    required this.onEdit,
    required this.onBaixa,
    required this.onMover,
  });

  final Animal animal;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onBaixa;
  final VoidCallback onMover;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    final lotAsync = ref.watch(loteByIdProvider(animal.lotId));
    final paddockId = lotAsync.asData?.value?.paddockId;
    final paddockAsync = paddockId != null
        ? ref.watch(paddockByIdProvider(paddockId))
        : null;

    final isActive = animal.deletedAt == null;

    String statusLabel;
    Color statusBgColor;
    Color statusTextColor;

    if (isActive) {
      statusLabel = 'Ativo';
      statusBgColor = Colors.green.shade100;
      statusTextColor = Colors.green.shade800;
    } else {
      final reasonLabel = switch (animal.baixaReason) {
        'sale' => 'Vendido',
        'death' => 'Morto',
        'discard' => 'Descartado',
        _ => 'Arquivado',
      };
      final dateStr = animal.baixaDate != null
          ? ' em ${dateFmt.format(animal.baixaDate!)}'
          : '';
      statusLabel = 'Arquivado — $reasonLabel$dateStr';
      statusBgColor = colorScheme.errorContainer;
      statusTextColor = colorScheme.onErrorContainer;
    }

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _KvRow(
              label: 'Número',
              value: Text('#${animal.number}'),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Categoria',
              value: Text(
                  kCategoryLabels[animal.category] ?? animal.category),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Raça',
              value: Text(animal.breed ?? '—'),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Estado corporal',
              value: Text(
                animal.bodyCondition != null
                    ? '${animal.bodyCondition} / 5'
                    : '—',
              ),
            ),
            const SizedBox(height: 8),
            // Lote atual (tappable)
            _KvRow(
              label: 'Lote atual',
              value: lotAsync.when(
                loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, st) => const Text('—'),
                data: (lot) => lot == null
                    ? const Text('—')
                    : InkWell(
                        onTap: () =>
                            context.go(AppRoutes.loteDetail(lot.id)),
                        child: Text(
                          lot.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Piquete atual (tappable)
            _KvRow(
              label: 'Piquete atual',
              value: paddockAsync == null
                  ? const Text('—')
                  : paddockAsync.when(
                      loading: () => const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      error: (e, st) => const Text('—'),
                      data: (paddock) => paddock == null
                          ? const Text('—')
                          : InkWell(
                              onTap: () => context.go(
                                '/piquetes/${paddock.id}',
                              ),
                              child: Text(
                                paddock.name,
                                style: TextStyle(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .primary,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                    ),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Cadastrado em',
              value: Text(dateFmt.format(animal.createdAt.toLocal())),
            ),
            if (animal.observation != null &&
                animal.observation!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _KvRow(label: 'Observação', value: Text(animal.observation!)),
            ],
            const SizedBox(height: 8),
            // Status badge
            _KvRow(
              label: 'Status',
              value: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: statusBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  statusLabel,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: statusTextColor,
                  ),
                ),
              ),
            ),
            // Action buttons (veterinarian only)
            if (canEdit) ...[
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton(
                    onPressed: onEdit,
                    child: const Text('Editar animal'),
                  ),
                  if (isActive) ...[
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: colorScheme.error,
                      ),
                      onPressed: onBaixa,
                      child: const Text('Dar baixa'),
                    ),
                    const SizedBox(width: 8),
                    OutlinedButton.icon(
                      onPressed: onMover,
                      icon: const Icon(Icons.swap_horiz),
                      label: const Text('Mover animal'),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Key-value row: label (fixed width 120) + expanded value widget.
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}

/// Read-only reproductive history list on the animal ficha (REPR-05, D-14).
///
/// One row per ATF the animal participated in — active or closed alike —
/// ordered by insemination date descending, each showing that ATF's most
/// recent DG result. D-13 makes this block strictly read-only: no mutation
/// call, no interactive control, for any role. Same outlined-card shell
/// (rounded 12, outline 38%, colorScheme.surface) as the sanitary history
/// section below it.
class _ReproductiveHistorySection extends ConsumerWidget {
  const _ReproductiveHistorySection({required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final historyAsync = ref.watch(
      reproductiveHistoryByAnimalProvider(animalId),
    );

    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.38),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Histórico Reprodutivo', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            historyAsync.when(
              loading: () => const Center(
                child: Padding(
                  padding: EdgeInsets.symmetric(vertical: 8),
                  child: CircularProgressIndicator(),
                ),
              ),
              error: (err, st) => Text(
                'Erro ao carregar histórico reprodutivo.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Text(
                    'Nenhum ATF registrado para este animal.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color:
                          theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  );
                }
                final dateFmt = DateFormat('dd/MM', 'pt_BR');
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final entry in entries)
                      _ReproductiveHistoryRow(entry: entry, dateFmt: dateFmt),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// One row of [_ReproductiveHistorySection] — D-14 format:
/// "[ATF nome] — insem. [DD/MM] · [último DG] · [status]", navigating to
/// `/atf/:atfId` on tap (D-02).
class _ReproductiveHistoryRow extends StatelessWidget {
  const _ReproductiveHistoryRow({required this.entry, required this.dateFmt});

  final ReproductiveHistoryEntry entry;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final Widget resultSlot;
    final lastDgResult = entry.lastDgResult;
    if (lastDgResult == null) {
      resultSlot = Text('aguardando DG', style: theme.textTheme.bodyMedium);
    } else {
      final (bg, fg) = switch (lastDgResult) {
        DgResult.pregnant => (
            colorScheme.primaryContainer,
            colorScheme.onPrimaryContainer,
          ),
        DgResult.notPregnant => (
            colorScheme.errorContainer,
            colorScheme.onErrorContainer,
          ),
        DgResult.doubtful => (
            colorScheme.tertiaryContainer,
            colorScheme.onTertiaryContainer,
          ),
      };
      resultSlot = Chip(
        label: Text(lastDgResult.label),
        backgroundColor: bg,
        labelStyle: TextStyle(color: fg),
        side: BorderSide.none,
      );
    }

    final statusBadge = entry.atfActive
        ? Chip(
            label: const Text('Ativo'),
            backgroundColor: Colors.transparent,
            side: BorderSide(color: colorScheme.outline),
          )
        : Chip(
            label: const Text('Encerrado'),
            backgroundColor: colorScheme.surfaceContainerHigh,
            side: BorderSide.none,
          );

    return InkWell(
      onTap: () => context.go(AppRoutes.atfDetail(entry.atfBatchId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              '${entry.atfName} — insem. ${dateFmt.format(entry.inseminationDate)}',
              style: theme.textTheme.bodyLarge,
            ),
            const Text('·'),
            resultSlot,
            const Text('·'),
            statusBadge,
          ],
        ),
      ),
    );
  }
}

