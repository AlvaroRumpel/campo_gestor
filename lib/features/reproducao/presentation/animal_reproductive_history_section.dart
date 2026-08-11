import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';

/// Read-only reproductive history list on the animal ficha (REPR-05, D-14).
///
/// One row per ATF the animal participated in — active or closed alike —
/// ordered by insemination date descending, each showing that ATF's most
/// recent DG result. D-13 makes this block strictly read-only: no mutation
/// call, no interactive control, for any role. Same outlined-card shell
/// (rounded 12, outline 38%, colorScheme.surface) as the sanitary history
/// section beside it.
///
/// D-11/D-37 contract: this widget takes nothing but an animal id and
/// resolves its own provider, so the ficha can compose it without passing
/// any data from outside — symmetric to [AnimalSanitaryHistorySection].
class AnimalReproductiveHistorySection extends ConsumerWidget {
  const AnimalReproductiveHistorySection({super.key, required this.animalId});

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

/// One row of [AnimalReproductiveHistorySection] — D-14 format:
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
