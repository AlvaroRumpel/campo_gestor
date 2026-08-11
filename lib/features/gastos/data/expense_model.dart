import 'package:freezed_annotation/freezed_annotation.dart';

import '../../sanitario/data/sanitary_application_model.dart';
import 'expense_constants.dart';

part 'expense_model.freezed.dart';
part 'expense_model.g.dart';

/// A manual expense row (GAST-01) tied to a paddock and a category from
/// `expense_constants.dart`'s `kExpenseCategories`.
@freezed
sealed class Expense with _$Expense {
  // ignore: invalid_annotation_target
  @JsonSerializable(fieldRename: FieldRename.snake)
  const factory Expense({
    required String id,
    required String propertyId,
    required String paddockId,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
    required String createdBy,
    String? updatedBy,
    required DateTime createdAt,
    required DateTime updatedAt,
    DateTime? deletedAt,
  }) = _Expense;

  factory Expense.fromJson(Map<String, dynamic> json) =>
      _$ExpenseFromJson(json);
}

/// Unifies manual expenses with read-only sanitary-application rows into one
/// list the paddock "Gastos" screen renders (D-32). Wraps the existing
/// [SanitaryApplication] model unchanged — no parallel sanitary type is
/// declared here.
@freezed
sealed class ExpenseListItem with _$ExpenseListItem {
  const factory ExpenseListItem.manual(Expense expense) = ManualExpenseItem;
  const factory ExpenseListItem.sanitary(SanitaryApplication application) =
      SanitaryExpenseItem;
}

/// The date each union variant is sorted and filtered by: a manual expense's
/// `expenseDate`, or a sanitary application's `appliedAt`.
DateTime dateOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.expenseDate,
      SanitaryExpenseItem(:final application) => application.appliedAt,
    };

/// The single place a null sanitary cost becomes a number (Claude's
/// Discretion resolution to D-11 Phase 6): a manual expense always has an
/// `amount`, but a sanitary row's `totalCost` can be null, and here it
/// contributes `0.0` to any sum built on top of this accessor. The row still
/// counts toward `itemCount` — the UI renders "—" rather than a currency
/// figure for it, it does not disappear from the list. `.abs()` is
/// deliberate: `reverse_sanitary_application` writes negated totals, and
/// although reversed rows are filtered out upstream (D-33) the absolute
/// value keeps this accessor correct in isolation.
double amountOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.amount,
      SanitaryExpenseItem(:final application) =>
        application.totalCost?.abs() ?? 0.0,
    };

/// The category key used by the list filter — a manual expense's own
/// category, or the sanitary pseudo-category key (D-32).
String categoryKeyOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.category,
      SanitaryExpenseItem() => kSanitaryPseudoCategory,
    };

DateTime _createdAtOf(ExpenseListItem item) => switch (item) {
      ManualExpenseItem(:final expense) => expense.createdAt,
      SanitaryExpenseItem(:final application) => application.createdAt,
    };

/// Sorts [items] by [dateOf] descending, with [_createdAtOf] descending as
/// the tie-breaker so two items on the same date have a stable, repeatable
/// order across reloads (D-19; the same lesson as Phase 5's G-05-4). Returns
/// a new list — does not mutate [items].
List<ExpenseListItem> sortExpenseItemsDesc(List<ExpenseListItem> items) {
  final sorted = List<ExpenseListItem>.of(items);
  sorted.sort((a, b) {
    final byDate = dateOf(b).compareTo(dateOf(a));
    if (byDate != 0) return byDate;
    return _createdAtOf(b).compareTo(_createdAtOf(a));
  });
  return sorted;
}
