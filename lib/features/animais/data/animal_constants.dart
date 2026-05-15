import 'animal_model.dart';

/// Ordered list of valid animal categories.
const List<String> kCategories = <String>[
  'vaca',
  'novilha',
  'terneiro',
  'terneira',
  'touro',
  'boi',
  'novilho',
];

/// Singular labels in pt-BR for each category.
const Map<String, String> kCategoryLabels = <String, String>{
  'vaca': 'Vaca',
  'novilha': 'Novilha',
  'terneiro': 'Terneiro',
  'terneira': 'Terneira',
  'touro': 'Touro',
  'boi': 'Boi',
  'novilho': 'Novilho',
};

/// Plural labels in pt-BR for each category.
const Map<String, String> kCategoryLabelsPlural = <String, String>{
  'vaca': 'Vacas',
  'novilha': 'Novilhas',
  'terneiro': 'Terneiros',
  'terneira': 'Terneiras',
  'touro': 'Touros',
  'boi': 'Bois',
  'novilho': 'Novilhos',
};

/// UA weights per category. Source: REQUIREMENTS.md Business Rules table.
const Map<String, double> kUaWeights = <String, double>{
  'vaca': 1.0,
  'novilha': 0.75,
  'terneiro': 0.5,
  'terneira': 0.5,
  'touro': 1.5,
  'boi': 1.5,
  'novilho': 0.75,
};

/// Hardcoded breed list (D-14). Not stored in DB — stored as text on the animal row.
const List<String> kBreeds = <String>[
  'Nelore',
  'Angus',
  'Brahman',
  'Gir',
  'Guzerá',
  'Tabapuã',
  'Canchim',
  'Brangus',
  'Simental',
  'Charolês',
  'Limousin',
  'Hereford',
  'Girolando',
  'Wagyu',
  'Caracu',
  'Sindi',
  'Pé-duro/Curraleiro',
];

/// Baixa (discharge) reasons. DB values: 'sale', 'death', 'discard' (D-17).
enum BaixaReason {
  sale,
  death,
  discard;

  /// Value stored in the `baixa_reason` text column.
  String get dbValue => switch (this) {
        BaixaReason.sale => 'sale',
        BaixaReason.death => 'death',
        BaixaReason.discard => 'discard',
      };

  /// Display label in pt-BR.
  String get label => switch (this) {
        BaixaReason.sale => 'Venda',
        BaixaReason.death => 'Morte',
        BaixaReason.discard => 'Descarte',
      };

  /// Parse from DB string. Returns null for unknown/null values.
  static BaixaReason? fromDb(String? v) => switch (v) {
        'sale' => BaixaReason.sale,
        'death' => BaixaReason.death,
        'discard' => BaixaReason.discard,
        _ => null,
      };
}

/// Calculates total Unidade Animal (UA) for a collection of animals.
///
/// Uses [kUaWeights] to resolve each animal's category weight.
/// Unknown categories contribute 0.0 to the total.
double calcTotalUa(Iterable<Animal> animals) =>
    animals.fold(0.0, (sum, a) => sum + (kUaWeights[a.category] ?? 0.0));
