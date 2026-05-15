import 'package:freezed_annotation/freezed_annotation.dart';

part 'lote_model.freezed.dart';
part 'lote_model.g.dart';

@freezed
sealed class Lot with _$Lot {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Lot({
    required String id,
    required String propertyId,
    required String paddockId,
    required String name,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Lot;

  factory Lot.fromJson(Map<String, dynamic> json) => _$LotFromJson(json);
}
