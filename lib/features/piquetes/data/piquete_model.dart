import 'package:freezed_annotation/freezed_annotation.dart';

part 'piquete_model.freezed.dart';
part 'piquete_model.g.dart';

@freezed
sealed class Paddock with _$Paddock {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Paddock({
    required String id,
    required String propertyId,
    required String name,
    required double areaHa,
    required double uaCapacity,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Paddock;

  factory Paddock.fromJson(Map<String, dynamic> json) =>
      _$PaddockFromJson(json);
}
