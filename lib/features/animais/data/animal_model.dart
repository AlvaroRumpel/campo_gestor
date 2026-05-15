import 'package:freezed_annotation/freezed_annotation.dart';

part 'animal_model.freezed.dart';
part 'animal_model.g.dart';

@freezed
sealed class Animal with _$Animal {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Animal({
    required String id,
    required String propertyId,
    required String lotId,
    required String category,
    required int number,
    String? breed,
    int? bodyCondition,
    String? observation,
    String? baixaReason,
    DateTime? baixaDate,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Animal;

  factory Animal.fromJson(Map<String, dynamic> json) => _$AnimalFromJson(json);
}

/// Animal joined with current lot.name + paddock.{id,name} for AnimaisScreen.
/// Built from the embedded-resource select; not a Supabase row by itself.
class AnimalWithContext {
  const AnimalWithContext({
    required this.animal,
    required this.lotName,
    required this.paddockId,
    required this.paddockName,
  });
  final Animal animal;
  final String lotName;
  final String paddockId;
  final String paddockName;
}
