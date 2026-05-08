import 'package:freezed_annotation/freezed_annotation.dart';

part 'piquete_model.freezed.dart';
part 'piquete_model.g.dart';

@freezed
sealed class Piquete with _$Piquete {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Piquete({
    required String id,
    required String propriedadeId,
    required String nome,
    required double areaHa,
    required double capacidadeUa,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Piquete;

  factory Piquete.fromJson(Map<String, dynamic> json) =>
      _$PiqueteFromJson(json);
}
