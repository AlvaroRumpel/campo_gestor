import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';
import 'lote_actions.dart';

/// Renders the lots list (or empty state) under a paddock card.
///
/// Used by [PaddockDetailScreen]. Named `LotsSection` (public) because
/// it is imported from a different file — Dart files cannot export
/// underscore-prefixed classes across files.
class LotsSection extends ConsumerWidget {
  const LotsSection({
    super.key,
    required this.paddockId,
    required this.canEdit,
    required this.propertyId,
  });

  final String paddockId;
  final bool canEdit;
  final String propertyId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotsAsync = ref.watch(loteListByPaddockProvider(paddockId));

    return lotsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (err, st) => Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ErrorRetry(
            message: 'Erro ao carregar.',
            onRetry: () => ref.invalidate(loteListByPaddockProvider(paddockId)),
          ),
        ),
      ),
      data: (lots) {
        if (lots.isEmpty) {
          return const _EmptyLotsState();
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: lots.length,
          separatorBuilder: (ctx, idx) => const SizedBox(height: 8),
          itemBuilder: (ctx, i) => _LotCard(
            lot: lots[i],
            canEdit: canEdit,
            onEdit: () => editLotName(ctx, ref, lots[i]),
            onArchive: () => archiveLot(ctx, ref, lots[i]),
          ),
        );
      },
    );
  }
}

class _EmptyLotsState extends StatelessWidget {
  const _EmptyLotsState();

  @override
  Widget build(BuildContext context) {
    return const EmptyState(
      icon: Icons.group_work_outlined,
      title: 'Nenhum lote neste piquete',
      message: 'Crie um lote para começar a registrar animais.',
    );
  }
}

String _composeSummary(List<Animal> animals) {
  final active = animals.where((a) => a.deletedAt == null).toList();
  if (active.isEmpty) return 'Sem animais';
  final counts = <String, int>{};
  for (final a in active) {
    counts[a.category] = (counts[a.category] ?? 0) + 1;
  }
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  final top = entries
      .take(2)
      .map((e) => '${e.value} ${kCategoryLabelsPlural[e.key]}')
      .join(' · ');
  final more = entries.length > 2 ? ' (+${entries.length - 2})' : '';
  final ua = calcTotalUa(active);
  return '$top$more · ${ua.toStringAsFixed(1).replaceAll('.', ',')} UA';
}

class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.lot,
    required this.canEdit,
    required this.onEdit,
    required this.onArchive,
  });

  final Lot lot;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const Icon(Icons.group_work_outlined),
        title: Text(lot.name),
        subtitle: Consumer(
          builder: (ctx, ref, _) {
            final asyncAnimals = ref.watch(animalListByLotProvider(lot.id));
            return Text(
              asyncAnimals.when(
                data: _composeSummary,
                loading: () => '—',
                error: (e, _) => 'Erro',
              ),
            );
          },
        ),
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'archive') onArchive();
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar nome')),
                  PopupMenuItem(
                      value: 'archive', child: Text('Arquivar lote')),
                ],
              )
            : null,
        onTap: () => context.go(AppRoutes.loteDetail(lot.id)),
      ),
    );
  }
}
