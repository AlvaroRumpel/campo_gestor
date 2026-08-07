import 'package:freezed_annotation/freezed_annotation.dart';

part 'dose_model.freezed.dart';
part 'dose_model.g.dart';

/// A cadastrable dose (SANI-01) — a commercial product with a dosage per kg
/// of live weight, and an optional cost per kg.
///
/// D-14: `activeIngredient` is optional so different commercial products
/// sharing an ingredient can be grouped without forcing the field on a user
/// who does not know it.
/// D-11: `costPerKg` stays null when unknown — never defaulted to zero, so
/// "R$ 0,00" never reaches a screen for a dose without a known price.
@freezed
sealed class Dose with _$Dose {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Dose({
    required String id,
    required String propertyId,
    required String name,
    String? activeIngredient,
    required double dosagePerKg,
    double? costPerKg,
    required DateTime createdAt,
    DateTime? deletedAt,
  }) = _Dose;

  const Dose._();

  factory Dose.fromJson(Map<String, dynamic> json) => _$DoseFromJson(json);

  bool get isArchived => deletedAt != null;

  /// Dropdown item label: name alone, or "name — ingredient" when the
  /// active ingredient is present and non-empty.
  String get displayLabel => (activeIngredient == null || activeIngredient!.isEmpty)
      ? name
      : '$name — $activeIngredient';
}
