import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';
import 'lote_form_dialog.dart';

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
      error: (err, st) => const Center(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('Erro ao carregar.'),
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
            onEdit: () => _openEditDialog(ctx, ref, lots[i]),
          ),
        );
      },
    );
  }

  Future<void> _openEditDialog(
      BuildContext context, WidgetRef ref, Lot lot) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => LoteFormDialog(
        paddockId: paddockId,
        propertyId: propertyId,
        existing: lot,
      ),
    );
    if (ok == true) {
      ref.invalidate(loteListByPaddockProvider(paddockId));
    }
  }
}

class _EmptyLotsState extends StatelessWidget {
  const _EmptyLotsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.group_work_outlined,
              size: 48,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum lote neste piquete',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um lote para começar a registrar animais.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
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
  });

  final Lot lot;
  final bool canEdit;
  final VoidCallback onEdit;

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
                },
                itemBuilder: (_) => const [
                  PopupMenuItem(value: 'edit', child: Text('Editar nome')),
                ],
              )
            : null,
        onTap: () => context.go(AppRoutes.loteDetail(lot.id)),
      ),
    );
  }
}
