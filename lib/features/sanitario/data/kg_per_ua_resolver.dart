import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../propriedades/data/propriedade_repository.dart';

/// The active property's kg/UA factor (D-12), falling back to 400 while the
/// property or its full row has not resolved. `currentPropertyProvider` only
/// carries id+name (`SelectedProperty`); the full `Property.kgPerUa` lives in
/// `propertyListProvider` — this joins them. Shared by every sanitary screen
/// that needs the factor (WR-05) instead of three copy-pasted methods.
double resolveActiveKgPerUa(WidgetRef ref) {
  final selected = ref.watch(currentPropertyProvider).asData?.value;
  if (selected == null) return 400;
  final properties = ref.watch(propertyListProvider).asData?.value ?? const [];
  final match = properties.where((p) => p.id == selected.id);
  return match.isNotEmpty ? match.first.kgPerUa : 400;
}
