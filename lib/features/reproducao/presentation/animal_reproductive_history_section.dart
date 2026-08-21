import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../data/iatf_model.dart';
import '../data/iatf_repository.dart';
import '../data/dg_record_model.dart';

/// dd/MM/yyyy, used only for the DG sub-row date inside the expansion (D-09)
/// — one step more precise than the row's own short `dd/MM` formatter, since
/// a DG sub-row has no other context to imply the year.
final _dgDateFmt = DateFormat('dd/MM/yyyy', 'pt_BR');

/// Result→StatusChip kind, shared by the collapsed row's summary chip and
/// each DG sub-row chip inside the expansion (D-08/D-09) — one place so the
/// two presentations cannot drift. Prenhe verde / Vazia vermelho / Duvidosa
/// laranja, o mesmo semáforo do DG em massa.
StatusKind _dgResultKind(DgResult result) => switch (result) {
      DgResult.pregnant => StatusKind.positive,
      DgResult.notPregnant => StatusKind.danger,
      DgResult.doubtful => StatusKind.warning,
    };

/// Read-only reproductive history list on the animal ficha (REPR-05, D-14).
///
/// One row per IATF the animal participated in — active or closed alike —
/// ordered by insemination date descending, each showing that IATF's most
/// recent DG result. D-13 makes this block strictly read-only: no mutation
/// call, no interactive control, for any role. Same `SectionCard` shell as
/// the sanitary history section beside it (VIS-01).
///
/// D-11/D-37 contract: this widget takes nothing but an animal id and
/// resolves its own provider, so the ficha can compose it without passing
/// any data from outside — symmetric to [AnimalSanitaryHistorySection].
class AnimalReproductiveHistorySection extends ConsumerWidget {
  const AnimalReproductiveHistorySection({super.key, required this.animalId});

  final String animalId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final historyAsync = ref.watch(
      reproductiveHistoryByAnimalProvider(animalId),
    );

    return SectionCard(
      title: 'Histórico Reprodutivo',
      child: historyAsync.when(
        loading: () => const Center(
          child: Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: CircularProgressIndicator(),
          ),
        ),
        error: (err, st) => ErrorRetry(
          message: 'Erro ao carregar histórico reprodutivo.',
          onRetry: () => ref.invalidate(
            reproductiveHistoryByAnimalProvider(animalId),
          ),
        ),
        data: (entries) {
          if (entries.isEmpty) {
            return const Text(
              'Nenhum IATF registrado para este animal.',
              style: TextStyle(
                fontSize: 13.5,
                color: AppColors.textSecondary,
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
    );
  }
}

/// One row of [AnimalReproductiveHistorySection] — D-14 format:
/// "[IATF nome] — insem. [DD/MM] · [último DG] · [status]", navigating to
/// `/iatf/:iatfId` on tap (D-02).
class _ReproductiveHistoryRow extends StatelessWidget {
  const _ReproductiveHistoryRow({required this.entry, required this.dateFmt});

  final ReproductiveHistoryEntry entry;
  final DateFormat dateFmt;

  @override
  Widget build(BuildContext context) {
    final Widget resultSlot;
    final lastDgResult = entry.lastDgResult;
    if (lastDgResult == null) {
      resultSlot = const Text(
        'aguardando DG',
        style: TextStyle(fontSize: 13.5, color: AppColors.textSecondary),
      );
    } else {
      resultSlot =
          StatusChip(lastDgResult.label, kind: _dgResultKind(lastDgResult));
    }

    final statusBadge = entry.iatfActive
        ? const StatusChip('Ativo', kind: StatusKind.positive)
        : const StatusChip('Encerrado', kind: StatusKind.neutral);

    final bullName = entry.bullName;
    final hasBull = bullName != null && bullName.trim().isNotEmpty;

    final summary = InkWell(
      onTap: () => context.go(AppRoutes.iatfDetail(entry.iatfBatchId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Wrap(
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            Text(
              '${entry.iatfName} — insem. ${dateFmt.format(entry.inseminationDate)}',
              style: const TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
              ),
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
    // 0- or 1-DG IATF's collapsed row already shows everything there is
    // (D-08, UI-SPEC zero-one-many). The summary (with its own InkWell) sits
    // in `title`, so a tap on the summary text still navigates while a tap
    // on the chevron (outside the InkWell's bounds) only toggles expansion.
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

/// One DG sub-row inside an IATF's [ExpansionTile] (D-08/D-09) — date, a
/// result chip sharing [_dgResultKind] with the collapsed row's own chip,
/// and the observation when present. The observation is a `Column` sibling
/// of the date/chip `Wrap`, not a member of it, so it gets a bounded width
/// from its ancestor and wraps across lines instead of overflowing at
/// narrow widths (UI-SPEC overflow/long-text backstop).
class _DgSubRow extends StatelessWidget {
  const _DgSubRow({required this.dg});

  final DgRecord dg;

  @override
  Widget build(BuildContext context) {
    final result = DgResult.fromDb(dg.result)!;
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
                style: monoStyle(size: 12.5),
              ),
              const Text('·'),
              StatusChip(result.label, kind: _dgResultKind(result)),
            ],
          ),
          if (observation != null && observation.isNotEmpty) ...[
            const SizedBox(height: 2),
            Text(
              '· $observation',
              style: const TextStyle(
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
