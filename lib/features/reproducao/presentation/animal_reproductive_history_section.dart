import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';

/// dd/MM/yyyy, used only for the DG sub-row date inside the expansion (D-09)
/// — one step more precise than the row's own short `dd/MM` formatter, since
/// a DG sub-row has no other context to imply the year.
final _dgDateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

/// Result→color mapping shared by the collapsed row's summary chip and each
/// DG sub-row chip inside the expansion (D-08/D-09) — extracted to one place
/// so the two presentations cannot drift from each other.
(Color, Color) _dgResultColors(ColorScheme colorScheme, DgResult result) {
  return switch (result) {
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
}

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
              error: (err, st) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Erro ao carregar histórico reprodutivo.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  TextButton(
                    onPressed: () => ref.invalidate(
                      reproductiveHistoryByAnimalProvider(animalId),
                    ),
                    child: const Text('Tentar novamente'),
                  ),
                ],
              ),
              data: (entries) {
                if (entries.isEmpty) {
                  return Text(
                    'Nenhum ATF registrado para este animal.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
      final (bg, fg) = _dgResultColors(colorScheme, lastDgResult);
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

    final bullName = entry.bullName;
    final hasBull = bullName != null && bullName.trim().isNotEmpty;

    final summary = InkWell(
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
            Text('implant. ${dateFmt.format(entry.implantationDate)}'),
            if (hasBull) ...[const Text('·'), Text('touro: $bullName')],
            const Text('·'),
            resultSlot,
            const Text('·'),
            statusBadge,
          ],
        ),
      ),
    );

    // Expand affordance only when there is more than one DG to reveal — a
    // 0- or 1-DG ATF's collapsed row already shows everything there is
    // (D-08, UI-SPEC zero-one-many). This ExpansionTile is the project's
    // first use of the widget; the summary (with its own InkWell) sits in
    // `title`, so a tap on the summary text still navigates while a tap on
    // the chevron (outside the InkWell's bounds) only toggles expansion.
    if (entry.dgRecords.length > 1) {
      return ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: summary,
        children: [for (final dg in entry.dgRecords) _DgSubRow(dg: dg)],
      );
    }

    return summary;
  }
}

/// One DG sub-row inside an ATF's [ExpansionTile] (D-08/D-09) — date, a
/// result chip sharing [_dgResultColors] with the collapsed row's own chip,
/// and the observation when present. The observation is a `Column` sibling
/// of the date/chip `Wrap`, not a member of it, so it gets a bounded width
/// from its ancestor and wraps across lines instead of overflowing at
/// narrow widths (UI-SPEC overflow/long-text backstop).
class _DgSubRow extends StatelessWidget {
  const _DgSubRow({required this.dg});

  final DgRecord dg;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final result = DgResult.fromDb(dg.result)!;
    final (bg, fg) = _dgResultColors(theme.colorScheme, result);
    final observation = dg.observation?.trim();

    return Padding(
      padding: const EdgeInsets.only(left: 16, top: 4, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                _dgDateFmt.format(dg.examDate),
                style: theme.textTheme.bodyMedium,
              ),
              const Text('·'),
              Chip(
                label: Text(result.label),
                backgroundColor: bg,
                labelStyle: TextStyle(color: fg),
                side: BorderSide.none,
              ),
            ],
          ),
          if (observation != null && observation.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text('· $observation', style: theme.textTheme.bodyMedium),
          ],
        ],
      ),
    );
  }
}
