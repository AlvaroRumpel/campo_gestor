import 'package:freezed_annotation/freezed_annotation.dart';

part 'dg_record_model.freezed.dart';
part 'dg_record_model.g.dart';

@freezed
sealed class DgRecord with _$DgRecord {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory DgRecord({
    required String id,
    required String propertyId,
    required String iatfBatchId,
    required String animalId,
    required String result,
    required DateTime examDate,
    String? observation,
    required DateTime createdAt,
  }) = _DgRecord;

  factory DgRecord.fromJson(Map<String, dynamic> json) =>
      _$DgRecordFromJson(json);
}

/// The three possible DG (diagnóstico de gestação) outcomes (REPR-03, D-10).
///
/// [dbValue] is the raw string stored in `dg_records.result`; [label] is the
/// pt-BR display text. Mirrors the [BaixaReason] shape in
/// `lib/features/animais/data/animal_constants.dart`.
enum DgResult {
  pregnant,
  notPregnant,
  doubtful;

  /// Value stored in the `dg_records.result` text column.
  String get dbValue => switch (this) {
        DgResult.pregnant => 'pregnant',
        DgResult.notPregnant => 'not_pregnant',
        DgResult.doubtful => 'doubtful',
      };

  /// Display label in pt-BR (redesign spec 3.4: Prenhe / Vazia / Duvidosa).
  String get label => switch (this) {
        DgResult.pregnant => 'Prenhe',
        DgResult.notPregnant => 'Vazia',
        DgResult.doubtful => 'Duvidosa',
      };

  /// Parse from DB string. Returns null for unknown/null values.
  static DgResult? fromDb(String? v) => switch (v) {
        'pregnant' => DgResult.pregnant,
        'not_pregnant' => DgResult.notPregnant,
        'doubtful' => DgResult.doubtful,
        _ => null,
      };
}
