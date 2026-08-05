import 'dg_record_model.dart';

/// Result of aggregating a list of [DgRecord]s into the % prenhez indicator
/// (REPR-04, 05-UI-SPEC.md `## Copywriting Contract`).
///
/// [total] is the number of distinct animals with at least one DG — the
/// denominator (D-17: `doubtful` and `not_pregnant` both count here).
/// [pregnant] is the numerator — only the most-recent-per-animal `pregnant`
/// results (D-12, D-17). [pending] is the composition count minus [total],
/// clamped at zero (D-20: a shrunk composition never reports negative pending).
class DgSummary {
  const DgSummary({
    required this.pregnant,
    required this.total,
    required this.pending,
  });
  final int pregnant;
  final int total;
  final int pending;

  /// Null when [total] is zero — encodes 05-UI-SPEC E10's "zero DGs renders
  /// '— · aguardando DG', never '0%'" decision and guards the division by zero.
  int? get percent => total == 0 ? null : (pregnant / total * 100).round();
}

/// Returns true when [candidate] supersedes [current] as an animal's (or an
/// ATF's) latest DG.
///
/// The tie-breaker is the vet-entered exam date (A-DG-ORDER, resolved by the
/// veterinarian 2026-08-05 in 05-UAT.md test 4, G-05-4): the record with the
/// greater `examDate` wins, regardless of insertion order. `createdAt` is
/// only the secondary tie-break, for the rare case of an exact same-date
/// exam, so a same-day correction still supersedes the record it corrects.
/// This is the ONE place the rule lives — three independent copies
/// previously drifted and one was lost from tracking docs entirely.
bool isLaterDg(DgRecord candidate, DgRecord current) {
  final cmp = candidate.examDate.compareTo(current.examDate);
  if (cmp != 0) return cmp > 0;
  return candidate.createdAt.isAfter(current.createdAt);
}

/// Aggregates [records] into a [DgSummary] (REPR-04).
///
/// Reduces to one record per `animalId`, keeping the one that wins under
/// [isLaterDg] (D-12, G-05-4 — the vet-entered `examDate` is authoritative,
/// with `createdAt` as the same-date tie-break). A DG record whose animal is
/// no longer in [compositionCount] still counts toward
/// [DgSummary.total]/[DgSummary.pregnant] (D-20 — a baixa'd animal that
/// already had a DG).
DgSummary summarizeDg(
  List<DgRecord> records, {
  required int compositionCount,
}) {
  final byAnimal = <String, DgRecord>{};
  for (final r in records) {
    final current = byAnimal[r.animalId];
    if (current == null || isLaterDg(r, current)) {
      byAnimal[r.animalId] = r;
    }
  }
  final pregnant = byAnimal.values
      .where((r) => DgResult.fromDb(r.result) == DgResult.pregnant)
      .length;
  final total = byAnimal.length;
  return DgSummary(
    pregnant: pregnant,
    total: total,
    pending: (compositionCount - total).clamp(0, compositionCount),
  );
}

/// Formats [summary] per 05-UI-SPEC.md's Copywriting Contract, exactly as
/// written there (REPR-04, D-18, E10).
String formatPrenhez(DgSummary summary) {
  final percent = summary.percent;
  if (percent == null) return '— · aguardando DG';
  if (summary.pending == 0) {
    return '$percent% prenhez (${summary.pregnant}/${summary.total} DG)';
  }
  // A-UI-E10: singular/plural conditional for the pendentes clause.
  final pendenteWord = summary.pending == 1 ? 'pendente' : 'pendentes';
  return '$percent% prenhez (${summary.pregnant}/${summary.total} DG · '
      '${summary.pending} $pendenteWord)';
}
