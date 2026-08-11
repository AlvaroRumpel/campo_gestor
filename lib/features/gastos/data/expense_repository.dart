import '../../../core/services/supabase_service.dart';
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
