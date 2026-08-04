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

/// A row from `animal_atf_memberships` joined with `animals(number, category)`.
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
  });
  final String membershipId;
  final String atfBatchId;
  final String animalId;
  final bool active;
  final int animalNumber;
  final String animalCategory;
}

/// One entry in an animal's reproductive history (REPR-05, D-14).
///
/// One row per ATF the animal participated in — active or closed memberships
/// alike — carrying that ATF's most recent DG result. Built from
/// `animal_atf_memberships` joined with `atf_batches(id, name,
/// insemination_date, active)` plus a grouped `dg_records` query; not a
/// Supabase row by itself.
class ReproductiveHistoryEntry {
  const ReproductiveHistoryEntry({
    required this.atfBatchId,
    required this.atfName,
    required this.inseminationDate,
    required this.atfActive,
    required this.lastDgResult,
    required this.lastDgDate,
  });
  final String atfBatchId;
  final String atfName;
  final DateTime inseminationDate;
  final bool atfActive;

  /// Null means "aguardando DG" — the animal is in this ATF but has no DG yet.
  final DgResult? lastDgResult;
  final DateTime? lastDgDate;
}
