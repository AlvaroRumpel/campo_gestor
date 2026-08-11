import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../reproducao/presentation/animal_reproductive_history_section.dart';
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
              if (animal.deletedAt != null) ...[
                _BaixaBanner(animal: animal),
                const SizedBox(height: 16),
              ],
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
              AnimalReproductiveHistorySection(animalId: animal.id),
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

    // D-01: one embedded-select read instead of the old lote -> piquete
    // waterfall (loteByIdProvider then a derived paddockByIdProvider watch).
    final lotAsync = ref.watch(loteWithPaddockByIdProvider(animal.lotId));

    final isActive = animal.deletedAt == null;

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
                data: (lotWithPaddock) => lotWithPaddock == null
                    ? const Text('—')
                    : InkWell(
                        onTap: () => context
                            .go(AppRoutes.loteDetail(lotWithPaddock.lot.id)),
                        child: Text(
                          lotWithPaddock.lot.name,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
              ),
            ),
            const SizedBox(height: 8),
            // Piquete atual (tappable) — same AsyncValue as "Lote atual"
            // above; no separate watch (D-01 kills the waterfall).
            _KvRow(
              label: 'Piquete atual',
              value: lotAsync.when(
                loading: () => const SizedBox(
                  height: 16,
                  width: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (e, st) => const Text('—'),
                data: (lotWithPaddock) => lotWithPaddock == null
                    ? const Text('—')
                    : InkWell(
                        onTap: () => context.go(
                          '/piquetes/${lotWithPaddock.lot.paddockId}',
                        ),
                        child: Text(
                          lotWithPaddock.paddockName,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.primary,
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

/// Full-width banner announcing a baixa (D-12, D-13, D-14, D-15, SC-4).
///
/// First child of the ficha's `ListView`, above [AnimalInfoCard], only when
/// `animal.deletedAt != null`. Stateless — unlike [_EncerrarBanner]
/// (`atf_detail_screen.dart`), this banner has no dismiss/action affordance:
/// it announces something that already happened (the animal left the herd),
/// not an invitation to act. Data comes entirely from the `animal` the ficha
/// already has in hand — zero extra request.
class _BaixaBanner extends StatelessWidget {
  const _BaixaBanner({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

    // Moved from AnimalInfoCard's old status switch (D-13) — not duplicated.
    final reasonLabel = switch (animal.baixaReason) {
      'sale' => 'Vendido',
      'death' => 'Morto',
      'discard' => 'Descartado',
      _ => 'Arquivado',
    };
    final dateStr =
        animal.baixaDate != null ? ' em ${dateFmt.format(animal.baixaDate!)}' : '';
    final observation = animal.observation;
    final hasObservation = observation != null && observation.trim().isNotEmpty;
    final text = hasObservation
        ? '$reasonLabel$dateStr — $observation'
        : '$reasonLabel$dateStr';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: colorScheme.onErrorContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: colorScheme.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

/// Key-value row: label + value, adaptive to available width (D-21, SC-5).
///
/// First row-level width breakpoint in the codebase — `LayoutBuilder`
/// reading `constraints.maxWidth`, not `MediaQuery`, because this row sits
/// inside `Card > Padding > Column` inside a `ListView`: on wider viewports
/// the app's adaptive shell narrows the content column below screen width,
/// so the local constraint (not the window) is the correct signal. Locked
/// threshold: below 400px the label stacks above the value (full width);
/// at/above 400px it keeps the existing 120px-label row layout unchanged.
/// Do not wrap this row in `Wrap` or `IntrinsicWidth` — either breaks the
/// constraint this `LayoutBuilder` measures. Pattern is reusable as-is for
/// any future leaf-widget width breakpoint in this project.
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    final labelText = Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color:
                Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
          ),
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final stacked = constraints.maxWidth < 400;
        if (stacked) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              labelText,
              const SizedBox(height: 2),
              value,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(width: 120, child: labelText),
            const SizedBox(width: 8),
            Expanded(child: value),
          ],
        );
      },
    );
  }
}

