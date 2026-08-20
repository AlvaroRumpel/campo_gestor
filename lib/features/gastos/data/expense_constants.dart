// D-01/D-03: the category vocabulary is a Dart constant with no database
// CHECK constraint behind it, so adding or renaming a category is a Flutter
// deploy with zero migration — the accepted cost is that a raw PATCH can
// store a value outside this list (see T-07-10, expense_model.dart degrades
// gracefully by showing the raw key rather than crashing).
//
// Needs `flutter/material.dart` for `IconData` (D-05) — the one structural
// deviation from `animal_constants.dart`, which is pure Dart.
import 'package:flutter/material.dart';

/// The 8 expense categories, fixed order: operação first, structural second,
/// `outros` last (D-02, D-06).
const List<String> kExpenseCategories = <String>[
  'racao_suplementacao',
  'sanidade_medicamentos',
  'mao_de_obra',
  'manutencao',
  'pastagem_adubacao',
  'combustivel',
  'arrendamento',
  'reproducao',
  'outros',
];

/// pt-BR label per category key.
const Map<String, String> kExpenseCategoryLabels = <String, String>{
  'racao_suplementacao': 'Ração/Suplementação',
  'sanidade_medicamentos': 'Sanidade/Medicamentos',
  'mao_de_obra': 'Mão de obra',
  'manutencao': 'Manutenção',
  'pastagem_adubacao': 'Pastagem/Adubação',
  'combustivel': 'Combustível',
  'arrendamento': 'Arrendamento',
  'reproducao': 'Reprodução',
  'outros': 'Outros',
};

/// Icon per category key (RESEARCH Assumption A1). Cosmetic and swappable
/// with zero schema or logic impact — no per-category colour is defined
/// (D-05); icons render in the default icon colour.
const Map<String, IconData> kExpenseCategoryIcons = <String, IconData>{
  'racao_suplementacao': Icons.grass,
  'sanidade_medicamentos': Icons.medical_services,
  'mao_de_obra': Icons.engineering,
  'manutencao': Icons.construction,
  'pastagem_adubacao': Icons.eco,
  'combustivel': Icons.local_gas_station,
  'arrendamento': Icons.description,
  'reproducao': Icons.favorite_outline,
  'outros': Icons.more_horiz,
};

/// The sanitary pseudo-category (D-32) — the unified list filter treats it
/// alongside the 8 real ones. Kept OUT of [kExpenseCategories] so the
/// expense form dropdown can never offer it.
const String kSanitaryPseudoCategory = 'sanitario';
const String kSanitaryPseudoCategoryLabel = 'Sanitário';
const IconData kSanitaryCategoryIcon = Icons.medical_services;

/// [kExpenseCategories] plus [kSanitaryPseudoCategory] — for the list filter
/// only (D-07). The form dropdown must keep using [kExpenseCategories].
const List<String> kExpenseFilterCategories = <String>[
  ...kExpenseCategories,
  kSanitaryPseudoCategory,
];
