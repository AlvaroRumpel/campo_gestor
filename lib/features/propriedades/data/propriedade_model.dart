import 'package:freezed_annotation/freezed_annotation.dart';

part 'propriedade_model.freezed.dart';
part 'propriedade_model.g.dart';

/// Data class for a rural property (propriedade).
///
/// D-05: `proprietario` is a free-text field (NOT a FK to auth.users) so that
/// the veterinário can register the owner's name without requiring an account.
/// D-11: soft-delete via `deleted_at`; hard DELETE is not granted by RLS.
@freezed
@JsonSerializable(fieldRename: FieldRename.snake)
sealed class Propriedade with _$Propriedade {
  const factory Propriedade({
    required String id,
    required String nome,
    required String proprietario,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Propriedade;

  factory Propriedade.fromJson(Map<String, dynamic> json) =>
      _$PropriedadeFromJson(json);
}
