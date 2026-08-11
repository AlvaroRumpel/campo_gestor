import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_providers.dart';
import '../../../core/services/supabase_service.dart';
import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import 'expense_calculations.dart';
import 'expense_model.dart';

/// CRUD repository for expenses (GAST-01, GAST-02).
///
/// All Supabase access flows through SupabaseService — this file must NEVER
/// import supabase_flutter directly (T-3-09). Expense writes go through the
/// `expenses` table endpoint directly, not an RPC: single-row single-entity
/// writes are fully covered by the `owner_vet_can_insert_expense` /
/// `owner_vet_can_update_expense` RLS policies (D-25).
class ExpenseRepository {
  ExpenseRepository(this._service);
  final SupabaseService _service;

  /// Expenses for [paddockId], ordered by `expense_date` descending with
  /// `created_at` descending as the tie-breaker (D-19, the G-05-4 lesson).
  /// Excludes soft-deleted rows unless [includeArchived] is true — one query
  /// shape with one filter switch, not a second method (D-19, D-22).
  Future<List<Expense>> fetchExpensesByPaddock(
    String paddockId, {
    bool includeArchived = false,
  }) async {
    var query = _service.client
        .from('expenses')
        .select()
        .eq('paddock_id', paddockId);
    if (!includeArchived) {
      query = query.isFilter('deleted_at', null);
    }
    final rows = await query
        .order('expense_date', ascending: false)
        .order('created_at', ascending: false);
    return (rows as List)
        .map((r) => Expense.fromJson(r as Map<String, dynamic>))
        .toList();
  }

  /// Create an expense. Blank [description] is sent as null, never an empty
  /// string — the nullable column is what lets the "omit the row" rendering
  /// rule downstream work (D-04), mirroring `createDose`'s handling of
  /// `activeIngredient`. [expenseDate] is serialized as a bare `yyyy-MM-dd`
  /// date string because the column is `date`, not `timestamptz`. Never sends
  /// `created_by`/`updated_by` — the column default and the BEFORE UPDATE
  /// trigger own those (D-27).
  Future<Expense> createExpense({
    required String propertyId,
    required String paddockId,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    final trimmedDescription = description?.trim();
    final row = await _service.client.from('expenses').insert({
      'property_id': propertyId,
      'paddock_id': paddockId,
      'category': category,
      'amount': amount,
      'expense_date': expenseDate.toIso8601String().split('T').first,
      'description':
          (trimmedDescription == null || trimmedDescription.isEmpty)
              ? null
              : trimmedDescription,
    }).select().single();
    return Expense.fromJson(row);
  }

  /// Update an expense's editable fields only (D-22) — never `paddock_id`,
  /// never `property_id`, never `created_by`.
  Future<Expense> updateExpense({
    required String id,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    final trimmedDescription = description?.trim();
    final row = await _service.client
        .from('expenses')
        .update({
          'category': category,
          'amount': amount,
          'expense_date': expenseDate.toIso8601String().split('T').first,
          'description':
              (trimmedDescription == null || trimmedDescription.isEmpty)
                  ? null
                  : trimmedDescription,
        })
        .eq('id', id)
        .select()
        .single();
    return Expense.fromJson(row);
  }

  /// Soft-delete: set deleted_at = now(). There is no hard-delete method —
  /// `expenses` has no DELETE policy and removal is a `deleted_at` UPDATE
  /// only (D-22).
  ///
  /// `.select().single()` forces a thrown error when RLS or a stale/wrong id
  /// silently matches zero rows — PostgREST otherwise answers 2xx on a 0-row
  /// UPDATE, the exact silent no-op class fixed server-side for the dose
  /// UPDATE policy in `20260812_06_fix_dose_update_policy.sql` (G-06-2).
  /// Apply `.select().single()` to every write in this class without
  /// exception.
  Future<void> archiveExpense(String id) async {
    await _service.client
        .from('expenses')
        .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', id)
        .select()
        .single();
  }

  /// Restore an archived expense: set deleted_at = null.
  Future<void> restoreExpense(String id) async {
    await _service.client
        .from('expenses')
        .update({'deleted_at': null})
        .eq('id', id)
        .select()
        .single();
  }
}

/// Merges [expenses] (manual, this phase's table) with the [applications]
/// (Phase 6, read-only) attributed to [paddockId] into one date-ordered list
/// (D-29, D-30, D-32, D-33). Pure function — no Supabase, no Riverpod. Does
/// not mutate either input list.
List<ExpenseListItem> buildUnifiedExpenseItems({
  required List<Expense> expenses,
  required List<SanitaryApplication> applications,
  required String paddockId,
}) {
  // 1. Drop reversal rows AND the originals they reverse first (D-33) — the
  //    existing Phase 6 helper, so a total built on top can never
  //    double-count a voided application. Do not reimplement this filter.
  final visible = visibleApplications(applications, showReversed: false);

  // 2. Keep only applications whose paddockId equals the argument. This
  //    reads the FROZEN column written at registration time by
  //    `register_sanitary_application` (D-30). Joining through
  //    `lots.paddock_id` is forbidden here: a lot moved in September would
  //    retroactively change August's total, which is the exact bug class
  //    the Phase 6 snapshot model exists to prevent.
  final matched = visible.where((a) => a.paddockId == paddockId);

  // 3-4. Wrap and sort (D-19). Returns a new list; never mutates the
  //      arguments.
  final items = <ExpenseListItem>[
    for (final expense in expenses) ExpenseListItem.manual(expense),
    for (final application in matched) ExpenseListItem.sanitary(application),
  ];
  return sortExpenseItemsDesc(items);
}

final expenseRepositoryProvider = Provider<ExpenseRepository>(
  (ref) => ExpenseRepository(ref.watch(supabaseServiceProvider)),
);

// D-18 ceiling: both list providers below sum client-side over the
// already-loaded list. If this list ever becomes paginated, the total
// silently becomes "total of this page" — the upgrade path is a
// server-side `SUM()` RPC, not before.
//
// Both list providers are the invalidation targets every write path in
// 07-05 and 07-06 must call after a successful mutation.

/// The unified manual+sanitary list for [paddockId], excluding archived
/// manual expenses. `sanitaryApplicationListByPropertyProvider` resolves
/// `currentPropertyProvider` internally, so this provider takes only the
/// paddock id — consuming widgets never pass a property id (established
/// project rule). Adds no new method to `SanitaryApplicationRepository`;
/// the property-wide fetch already exists and the paddock filter is
/// client-side.
final unifiedExpenseListByPaddockProvider =
    FutureProvider.family<List<ExpenseListItem>, String>((
  ref,
  paddockId,
) async {
  final expenses = await ref
      .watch(expenseRepositoryProvider)
      .fetchExpensesByPaddock(paddockId);
  final applications =
      await ref.watch(sanitaryApplicationListByPropertyProvider.future);
  return buildUnifiedExpenseItems(
    expenses: expenses,
    applications: applications,
    paddockId: paddockId,
  );
});

/// Identical to [unifiedExpenseListByPaddockProvider] but includes archived
/// manual expenses — the "Mostrar excluídos" toggle's data source. A sibling
/// provider rather than a family parameter keeps the toggle a pure provider
/// swap, exactly as `archivedDoseListByPropertyProvider` does (D-22).
/// Sanitary rows are unaffected — they are immutable and never soft-deleted.
final unifiedExpenseListWithDeletedByPaddockProvider =
    FutureProvider.family<List<ExpenseListItem>, String>((
  ref,
  paddockId,
) async {
  final expenses = await ref
      .watch(expenseRepositoryProvider)
      .fetchExpensesByPaddock(paddockId, includeArchived: true);
  final applications =
      await ref.watch(sanitaryApplicationListByPropertyProvider.future);
  return buildUnifiedExpenseItems(
    expenses: expenses,
    applications: applications,
    paddockId: paddockId,
  );
});

/// The current-month total for [paddockId], derived from the same
/// [unifiedExpenseListByPaddockProvider] data the list screen reads, so the
/// paddock card's figure and the screen's opening figure are the same
/// number by construction (D-09, D-15) — this resolves the CONTEXT.md
/// discretion item asking whether the card reuses the screen's provider.
final paddockMonthExpenseTotalProvider =
    FutureProvider.family<double, String>((ref, paddockId) async {
  final items = await ref
      .watch(unifiedExpenseListByPaddockProvider(paddockId).future);
  return totalAmount(
    filterByDateRange(items, currentMonthRange(DateTime.now())),
  );
});
