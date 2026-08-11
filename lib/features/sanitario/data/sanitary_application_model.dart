import 'package:freezed_annotation/freezed_annotation.dart';

part 'sanitary_application_model.freezed.dart';
part 'sanitary_application_model.g.dart';

/// One frozen animal entry inside `sanitary_applications.composition_snapshot`
/// (D-02) — the four keys `register_sanitary_application` writes into each
/// array element. Number and category are frozen because the animal row is
/// editable; UA is frozen because `kUaWeights` can change later.
@freezed
sealed class SanitaryCompositionEntry with _$SanitaryCompositionEntry {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SanitaryCompositionEntry({
    required String animalId,
    required int number,
    required String category,
    required double ua,
  }) = _SanitaryCompositionEntry;

  factory SanitaryCompositionEntry.fromJson(Map<String, dynamic> json) =>
      _$SanitaryCompositionEntryFromJson(json);
}

/// A frozen row from `sanitary_applications` (D-01..D-09) — either a
/// registration or a reversal of one (D-27..D-29). Every field below is
/// captured at write time by `register_sanitary_application`/
/// `reverse_sanitary_application` and never re-reads the animal, lot or
/// dose's current state (D-03, D-04) — a sanitary history surface must never
/// re-fetch an animal's current number/category/lot to decorate this row.
@freezed
sealed class SanitaryApplication with _$SanitaryApplication {
  const SanitaryApplication._();

  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory SanitaryApplication({
    required String id,
    required String propertyId,
    required String lotId,
    required String lotName,
    // Phase 7 (D-30): the paddock attribution frozen at write time by
    // `register_sanitary_application`, added to the `expenses`-adjacent
    // migration (`20260813_07_expenses_module.sql`) alongside this phase's
    // `expenses` table. Added here — not in the migration's own plan
    // (07-01), which is SQL-only — because the Dart model must catch up to
    // an already-authored NOT NULL column before `buildUnifiedExpenseItems`
    // (07-04) can filter sanitary rows by paddock at all.
    required String paddockId,
    required String paddockName,
    required String doseId,
    required String doseName,
    required double dosagePerKg,
    required double dosagePerUa,
    double? costPerKg,
    double? costPerUa,
    required DateTime appliedAt,
    required String appliedBy,
    required int animalCount,
    required double totalUa,
    required double totalVolume,
    double? totalCost,
    required int skippedCount,
    String? notes,
    String? reversesApplicationId,
    @Default(<SanitaryCompositionEntry>[])
    List<SanitaryCompositionEntry> compositionSnapshot,
    required DateTime createdAt,
  }) = _SanitaryApplication;

  factory SanitaryApplication.fromJson(Map<String, dynamic> json) =>
      _$SanitaryApplicationFromJson(json);

  /// True when this row itself reverses another (D-27) — NOT whether this
  /// row has since BEEN reversed. That second fact only exists relative to
  /// the surrounding list (a later row may point back at this one) and is
  /// never derivable from a single row alone; see [reversedApplicationIds]
  /// and [visibleApplications].
  bool get isReversal => reversesApplicationId != null;
}

/// Sorts [rows] by `appliedAt` descending, with `createdAt` descending as the
/// tie-breaker so two applications on the same date have a stable, repeatable
/// order across reloads (D-06; the same lesson as Phase 5's G-05-4). Returns
/// a new list — does not mutate [rows].
List<SanitaryApplication> sortByAppliedAtDesc(
  List<SanitaryApplication> rows,
) {
  final sorted = List<SanitaryApplication>.of(rows);
  sorted.sort((a, b) {
    final byAppliedAt = b.appliedAt.compareTo(a.appliedAt);
    if (byAppliedAt != 0) return byAppliedAt;
    return b.createdAt.compareTo(a.createdAt);
  });
  return sorted;
}

/// Every non-null [SanitaryApplication.reversesApplicationId] found in
/// [rows] — the set of application ids that have themselves been reversed.
Set<String> reversedApplicationIds(List<SanitaryApplication> rows) {
  return {
    for (final row in rows)
      if (row.reversesApplicationId != null) row.reversesApplicationId!,
  };
}

/// The single implementation of the "Mostrar estornadas" toggle (D-29),
/// shared by the global applications list, the lote section and the animal
/// ficha.
///
/// When [showReversed] is false, drops both the reversal rows themselves and
/// the original rows they reverse — a total computed over the result can
/// never double-count a voided application. When [showReversed] is true,
/// every row is returned unchanged.
List<SanitaryApplication> visibleApplications(
  List<SanitaryApplication> rows, {
  required bool showReversed,
}) {
  if (showReversed) return rows;
  final reversedIds = reversedApplicationIds(rows);
  return rows
      .where((row) => !row.isReversal && !reversedIds.contains(row.id))
      .toList();
}
