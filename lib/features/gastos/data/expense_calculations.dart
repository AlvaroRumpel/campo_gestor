// Pure expense calculation helpers (GAST-01/GAST-02). Dependency-free — no
// flutter/material.dart, no supabase_flutter, no Riverpod — so these run as
// plain `flutter_test` unit tests with zero widget or network setup (D-18,
// D-36).
//
// Currency display reuses `formatCurrencyBrl` from `sanitary_calculations.dart`
// rather than redefining it or introducing `NumberFormat.currency` — the
// existing helper avoids a non-breaking-space that makes exact-string
// assertions environment-dependent (see that file's own comment).
import 'expense_constants.dart';
import 'expense_model.dart';

export '../../sanitario/data/sanitary_calculations.dart'
    show formatCurrencyBrl;

/// Pure-Dart substitute for `package:flutter/material.dart`'s
/// `DateTimeRange` — this module must stay Flutter-free (D-18, D-36), and
/// `DateTimeRange` itself only exists behind `material.dart`. Same two-field
/// shape; the presentation layer (07-06) converts the `DateTimeRange` that
/// `showDateRangePicker` returns into one of these at the boundary.
class ExpenseDateRange {
  const ExpenseDateRange({required this.start, required this.end});
  final DateTime start;
  final DateTime end;
}

/// D-18 ceiling: this sum runs over the already-loaded list. If the list
/// ever becomes paginated, this total silently becomes "total of this
/// page" — upgrade to a server-side `SUM()`/RPC at that point, not before.
double totalAmount(Iterable<ExpenseListItem> items) =>
    items.fold(0.0, (sum, item) => sum + amountOf(item));

int itemCount(Iterable<ExpenseListItem> items) => items.length;

DateTime _dateOnly(DateTime dt) => DateTime(dt.year, dt.month, dt.day);

/// Both endpoints inclusive, comparing date-only values so a timestamp late
/// on the end day is not dropped.
List<ExpenseListItem> filterByDateRange(
  List<ExpenseListItem> items,
  ExpenseDateRange range,
) {
  final start = _dateOnly(range.start);
  final end = _dateOnly(range.end);
  return items.where((item) {
    final date = _dateOnly(dateOf(item));
    return !date.isBefore(start) && !date.isAfter(end);
  }).toList();
}

/// A null [categoryKey] means no filter; [kSanitaryPseudoCategory] selects
/// sanitary rows; any other key compares against [categoryKeyOf] (D-07,
/// D-32).
List<ExpenseListItem> filterByCategory(
  List<ExpenseListItem> items,
  String? categoryKey,
) {
  if (categoryKey == null) return items;
  return items.where((item) => categoryKeyOf(item) == categoryKey).toList();
}

/// The five period presets of D-16, pt-BR labelled.
enum ExpensePeriodPreset {
  mesAtual,
  mesPassado,
  ultimos3Meses,
  ano,
  personalizado;

  String get label => switch (this) {
        ExpensePeriodPreset.mesAtual => 'Mês atual',
        ExpensePeriodPreset.mesPassado => 'Mês passado',
        ExpensePeriodPreset.ultimos3Meses => 'Últimos 3 meses',
        ExpensePeriodPreset.ano => 'Ano',
        ExpensePeriodPreset.personalizado => 'Personalizado',
      };
}

/// One calendar month's total, produced by [lastMonthsTotals].
class MonthTotal {
  const MonthTotal({
    required this.year,
    required this.month,
    required this.total,
  });
  final int year;
  final int month;
  final double total;
}

/// Buckets [items] into [months] calendar months ending at `now`'s month,
/// oldest first. A month with no matching item still appears with `total:
/// 0` — the caller's bar chart never loses a month from its axis. Pure —
/// crosses year boundaries via `DateTime(now.year, now.month - k)`, the same
/// normalizing-constructor trick `rangeForPreset`'s `ultimos3Meses` case
/// already relies on.
List<MonthTotal> lastMonthsTotals(
  List<ExpenseListItem> items,
  DateTime now, {
  int months = 6,
}) {
  return [
    for (var k = months - 1; k >= 0; k--)
      _monthTotalFor(items, DateTime(now.year, now.month - k)),
  ];
}

MonthTotal _monthTotalFor(List<ExpenseListItem> items, DateTime bucket) {
  final total = items
      .where(
        (i) =>
            dateOf(i).year == bucket.year && dateOf(i).month == bucket.month,
      )
      .fold(0.0, (sum, i) => sum + amountOf(i));
  return MonthTotal(year: bucket.year, month: bucket.month, total: total);
}

/// Named shorthand for `rangeForPreset(mesAtual, now)` — the paddock summary
/// card (07-07) and the screen default (07-06) both call this so the card's
/// figure and the screen's opening figure cannot diverge (D-09, D-15).
ExpenseDateRange currentMonthRange(DateTime now) =>
    rangeForPreset(ExpensePeriodPreset.mesAtual, now);

/// `personalizado`'s range comes from `showDateRangePicker`, not from this
/// function — it throws.
ExpenseDateRange rangeForPreset(ExpensePeriodPreset preset, DateTime now) {
  switch (preset) {
    case ExpensePeriodPreset.mesAtual:
      return ExpenseDateRange(start: DateTime(now.year, now.month, 1), end: now);
    case ExpensePeriodPreset.mesPassado:
      final firstOfThisMonth = DateTime(now.year, now.month, 1);
      final lastOfPrevMonth = firstOfThisMonth.subtract(const Duration(days: 1));
      return ExpenseDateRange(
        start: DateTime(lastOfPrevMonth.year, lastOfPrevMonth.month, 1),
        end: lastOfPrevMonth,
      );
    case ExpensePeriodPreset.ultimos3Meses:
      final start = DateTime(now.year, now.month - 2, 1);
      return ExpenseDateRange(start: start, end: now);
    case ExpensePeriodPreset.ano:
      // A2 (planner assumption, RESEARCH): "Ano" is the calendar year
      // (Jan 1 -> today), not a rolling 12 months. Confirmed at UAT
      // (STATE.md Phase 7 decisions, 2026-08-11).
      return ExpenseDateRange(start: DateTime(now.year, 1, 1), end: now);
    case ExpensePeriodPreset.personalizado:
      throw ArgumentError(
        'personalizado has no computed range — it comes from showDateRangePicker',
      );
  }
}
