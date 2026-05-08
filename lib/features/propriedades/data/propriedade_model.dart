import 'package:freezed_annotation/freezed_annotation.dart';

part 'propriedade_model.freezed.dart';
part 'propriedade_model.g.dart';

/// Full domain model for a rural property.
///
/// D-05: `owner` is free-text (NOT a FK to auth.users) — veterinarian registers
/// the owner's name without requiring an account.
/// D-11: soft-delete via `deletedAt`; hard DELETE is not granted by RLS.
@freezed
sealed class Property with _$Property {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Property({
    required String id,
    required String name,
    String? owner,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Property;

  factory Property.fromJson(Map<String, dynamic> json) =>
      _$PropertyFromJson(json);
}
