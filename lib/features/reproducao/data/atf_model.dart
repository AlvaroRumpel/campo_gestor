import 'package:freezed_annotation/freezed_annotation.dart';

import 'dg_record_model.dart';

part 'atf_model.freezed.dart';
part 'atf_model.g.dart';

@freezed
sealed class AtfBatch with _$AtfBatch {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory AtfBatch({
    required String id,
    required String propertyId,
    required String name,
    required DateTime implantationDate,
    required DateTime inseminationDate,

    /// "HH:mm:ss" vindo da coluna `time` (ajustes 2026-08-20, item 3).
    String? inseminationTime,
    String? bullAnimalId,
    String? bullName,
    String? observation,
    required bool active,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _AtfBatch;

  factory AtfBatch.fromJson(Map<String, dynamic> json) =>
      _$AtfBatchFromJson(json);
}

/// A row from `animal_atf_memberships` joined with
/// `animals(number, category, deleted_at)`.
///
/// Built from the embedded-resource select; not a Supabase row by itself —
/// mirrors [AnimalWithContext]'s convention in `animal_model.dart`.
class AtfMembershipView {
  const AtfMembershipView({
    required this.membershipId,
    required this.atfBatchId,
    required this.animalId,
    required this.active,
    required this.animalNumber,
    required this.animalCategory,
    required this.animalDeleted,
  });
  final String membershipId;
  final String atfBatchId;
  final String animalId;
  final bool active;
  final int animalNumber;
  final String animalCategory;

  /// True when the member animal itself was archived by a baixa, as opposed
  /// to the membership merely being deactivated because the ATF was closed
  /// (G-05-2). `active` alone cannot distinguish the two cases.
  final bool animalDeleted;
}

/// One entry in an animal's reproductive history (REPR-05, D-14, D-09/D-10).
///
/// One row per ATF the animal participated in — active or closed memberships
/// alike — carrying that ATF's most recent DG result. Built from
/// `animal_atf_memberships` joined with `atf_batches(id, name,
/// insemination_date, active, implantation_date, bull_name)` plus a grouped
/// `dg_records` query; not a Supabase row by itself.
class ReproductiveHistoryEntry {
  const ReproductiveHistoryEntry({
    required this.atfBatchId,
    required this.atfName,
    required this.inseminationDate,
    required this.atfActive,
    required this.lastDgResult,
    required this.lastDgDate,
    required this.dgRecords,
    this.bullName,
    required this.implantationDate,
  });
  final String atfBatchId;
  final String atfName;
  final DateTime inseminationDate;
  final bool atfActive;

  /// Null means "aguardando DG" — the animal is in this ATF but has no DG yet.
  /// This is the collapsed-row summary — always the [isLaterDg] winner of
  /// [dgRecords], never replaced by the full list below (D-10).
  final DgResult? lastDgResult;
  final DateTime? lastDgDate;

  /// All DGs for this animal in this ATF, ordered most-recent-first per the
  /// single [isLaterDg] rule (D-09, D-10). Empty (never null) when the ATF
  /// has no DG for this animal yet.
  final List<DgRecord> dgRecords;

  /// Bull label already resolved on the ATF batch (Phase 5, WR-01); null when
  /// the ATF has no named bull.
  final String? bullName;
  final DateTime implantationDate;
}
