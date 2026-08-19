import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/ui.dart';
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
            onEdit: () => _openEditDialog(ctx, ref, lots[i]),
            onArchive: () => _archiveLot(ctx, ref, lots[i]),
          ),
        );
      },
    );
  }

  Future<void> _openEditDialog(
      BuildContext context, WidgetRef ref, Lot lot) async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => LoteFormDialog(
        paddockId: paddockId,
        propertyId: propertyId,
        existing: lot,
      ),
    );
    if (ok == true) {
      ref.invalidatePropertyData();
    }
  }

  /// Arquivar lote — único caminho de UI para softDeleteLot, exigido para
  /// esvaziar um piquete antes de removê-lo (QA 2026-08-19, item 1).
  /// trg_lots_archive_guard (20260814_10) bloqueia no banco; aqui a checagem
  /// serve para explicar antes, e o catch de 23514 cobre a corrida.
  Future<void> _archiveLot(
      BuildContext context, WidgetRef ref, Lot lot) async {
    final animals = await ref.read(animalListByLotProvider(lot.id).future);
    if (!context.mounted) return;
    final active = animals.where((a) => a.deletedAt == null).length;
    final messenger = ScaffoldMessenger.of(context);
    if (active > 0) {
      messenger.showSnackBar(SnackBar(content: Text(_blockedMessage(active))));
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Arquivar "${lot.name}"?'),
        content: const Text(
          'O lote sai das listas da propriedade. O piquete fica livre para '
          'ser removido.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Arquivar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    try {
      await ref.read(loteRepositoryProvider).softDeleteLot(lot.id);
      ref.invalidatePropertyData();
    } on PostgrestException catch (e) {
      ref.invalidatePropertyData();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            e.code == '23514'
                ? _blockedMessage(1)
                : 'Não foi possível arquivar o lote. Tente novamente.',
          ),
        ),
      );
    }
  }

  static String _blockedMessage(int count) => Intl.plural(
        count,
        one: 'Lote tem 1 animal ativo. Mova ou dê baixa antes de arquivar.',
        other: 'Lote tem $count animais ativos. Mova ou dê baixa antes de '
            'arquivar.',
        locale: 'pt_BR',
      );
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
