import '../../features/auth/data/property_repository.dart';
import '../providers/current_property_provider.dart';

/// D-23: the project's first two-role permission gate. `gasto` is the farm
/// owner's own financial data, so both `'owner'` and `'veterinarian'` may
/// manage it — unlike every other role gate in this codebase (`PiquetesScreen`,
/// `PaddockDetailScreen`, `SanitarioScreen`, `AnimaisScreen`), which are all
/// the same vet-only check. The database enum is
/// `role_enum ('owner','veterinarian','reader')`; the real enforcement is the
/// `owner_vet_can_insert_expense` / `owner_vet_can_update_expense` RLS
/// policies (07-01) — this predicate only decides whether a control renders.
/// Per project convention, a denied role sees the control **absent**, never
/// disabled.
///
/// Do NOT replace `PaddockDetailScreen._canEdit` with this function and do
/// NOT add `'owner'` to `_canEdit`: it guards the vet-only "Novo lote" FAB,
/// and the two gates are meant to coexist on the same screen (D-23).
bool canManageExpenses(
  SelectedProperty? current,
  List<PropertyMembership>? members,
) {
  if (current == null || members == null) return false;
  final role = members
      .where((m) => m.property.id == current.id)
      .map((m) => m.role)
      .firstOrNull;
  return role == 'veterinarian' || role == 'owner';
}
