// GAST-01/GAST-02 — expense totals, count, filters, sort and period presets.
// Pure Dart fixtures only — no mocks, no ProviderContainer, no widget
// pumping (D-18, D-36).
import 'package:campo_gestor/features/gastos/data/expense_calculations.dart';
import 'package:campo_gestor/features/gastos/data/expense_constants.dart';
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:flutter_test/flutter_test.dart';

/// A minimal manual [ExpenseListItem] — every field has a constant default
/// except the few named params a given test case cares about.
ExpenseListItem _manual({
  String id = 'exp-1',
  String category = 'combustivel',
  double amount = 100.0,
  DateTime? expenseDate,
  DateTime? createdAt,
}) {
  return ExpenseListItem.manual(Expense(
    id: id,
    propertyId: 'prop-1',
    paddockId: 'paddock-1',
    category: category,
    amount: amount,
    expenseDate: expenseDate ?? DateTime(2026, 1, 1),
    createdBy: 'user-1',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: createdAt ?? DateTime(2026, 1, 1),
  ));
}

/// A minimal sanitary [ExpenseListItem] wrapping a [SanitaryApplication].
ExpenseListItem _sanitary({
  String id = 'app-1',
  double? totalCost = 40.0,
  DateTime? appliedAt,
  DateTime? createdAt,
}) {
  return ExpenseListItem.sanitary(SanitaryApplication(
    id: id,
    propertyId: 'prop-1',
    lotId: 'lot-1',
    lotName: 'Lote 1',
    paddockId: 'paddock-1',
    paddockName: 'Piquete 1',
    doseId: 'dose-1',
    doseName: 'Dose 1',
    dosagePerKg: 1.0,
    dosagePerUa: 400.0,
    totalCost: totalCost,
    appliedAt: appliedAt ?? DateTime(2026, 1, 1),
    appliedBy: 'user-1',
    animalCount: 1,
    totalUa: 1.0,
    totalVolume: 400.0,
    skippedCount: 0,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  ));
}

void main() {
  group('totalAmount / itemCount (GAST-02)', () {
    test('totalAmount([]) returns 0.0 and itemCount([]) returns 0', () {
      expect(totalAmount(const []), 0.0);
      expect(itemCount(const []), 0);
    });

    test('totalAmount sums 3 manual expenses', () {
      final items = [
        _manual(id: 'a', amount: 100.50),
        _manual(id: 'b', amount: 200.25),
        _manual(id: 'c', amount: 1000.00),
      ];
      expect(totalAmount(items), 1300.75);
    });

    test(
        'totalAmount sums a manual expense plus a sanitary row with a known '
        'cost (D-29)', () {
      final items = [
        _manual(id: 'a', amount: 100.0),
        _sanitary(id: 'b', totalCost: 40.0),
      ];
      expect(totalAmount(items), 140.0);
    });

    test(
        'a null sanitary totalCost contributes 0 to the total but the row '
        'is still counted', () {
      final items = [
        _manual(id: 'a', amount: 100.0),
        _sanitary(id: 'b', totalCost: null),
      ];
      expect(totalAmount(items), 100.0);
      expect(itemCount(items), 2);
    });
  });

  group('filterByDateRange / filterByCategory (D-07)', () {
    test('filterByDateRange includes both range endpoints', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);
      final items = [
        _manual(id: 'onStart', expenseDate: start),
        _manual(id: 'onEnd', expenseDate: end),
        _manual(id: 'before', expenseDate: DateTime(2025, 12, 31)),
        _manual(id: 'after', expenseDate: DateTime(2026, 2, 1)),
      ];

      final filtered =
          filterByDateRange(items, ExpenseDateRange(start: start, end: end));

      expect(
        filtered.map((i) => (i as ManualExpenseItem).expense.id).toSet(),
        {'onStart', 'onEnd'},
      );
    });

    test('filterByCategory(items, null) returns every item', () {
      final items = [_manual(), _sanitary()];
      expect(filterByCategory(items, null).length, 2);
    });

    test(
        'filterByCategory(items, kSanitaryPseudoCategory) returns only '
        'sanitary rows', () {
      final items = [
        _manual(id: 'a'),
        _sanitary(id: 'b'),
      ];

      final filtered = filterByCategory(items, kSanitaryPseudoCategory);

      expect(filtered.length, 1);
      expect(filtered.single, isA<SanitaryExpenseItem>());
    });

    test(
        "filterByCategory(items, 'combustivel') returns only manual rows "
        'with that category', () {
      final items = [
        _manual(id: 'a', category: 'combustivel'),
        _manual(id: 'b', category: 'outros'),
        _sanitary(id: 'c'),
      ];

      final filtered = filterByCategory(items, 'combustivel');

      expect(filtered.map((i) => (i as ManualExpenseItem).expense.id),
          ['a']);
    });

    test(
        'filterByDateRange then filterByCategory yields the same result as '
        'the opposite order (D-07 combinability)', () {
      final start = DateTime(2026, 1, 1);
      final end = DateTime(2026, 1, 31);
      final range = ExpenseDateRange(start: start, end: end);
      final items = [
        _manual(id: 'a', category: 'combustivel', expenseDate: start),
        _manual(id: 'b', category: 'outros', expenseDate: start),
        _manual(
            id: 'c',
            category: 'combustivel',
            expenseDate: DateTime(2025, 12, 1)),
        _sanitary(id: 'd', appliedAt: start),
      ];

      final dateThenCategory =
          filterByCategory(filterByDateRange(items, range), 'combustivel');
      final categoryThenDate =
          filterByDateRange(filterByCategory(items, 'combustivel'), range);

      expect(
        dateThenCategory.map((i) => (i as ManualExpenseItem).expense.id),
        categoryThenDate.map((i) => (i as ManualExpenseItem).expense.id),
      );
      expect(dateThenCategory.map((i) => (i as ManualExpenseItem).expense.id),
          ['a']);
    });
  });

  group('sortExpenseItemsDesc tie-break (D-19)', () {
    test('two items on the same date break ties on createdAt descending',
        () {
      final sameDate = DateTime(2026, 1, 1);
      final earlyCreated = _manual(
        id: 'a',
        expenseDate: sameDate,
        createdAt: DateTime(2026, 1, 1, 8),
      );
      final lateCreated = _manual(
        id: 'b',
        expenseDate: sameDate,
        createdAt: DateTime(2026, 1, 1, 10),
      );

      final sorted = sortExpenseItemsDesc([earlyCreated, lateCreated]);

      expect(
        sorted.map((i) => (i as ManualExpenseItem).expense.id).toList(),
        ['b', 'a'],
      );
    });
  });

  group('rangeForPreset / currentMonthRange (D-15, D-16, A2)', () {
    test('rangeForPreset(mesAtual, now) starts on day 1 of the month', () {
      final now = DateTime(2026, 3, 15);

      final range = rangeForPreset(ExpensePeriodPreset.mesAtual, now);

      expect(range.start, DateTime(2026, 3, 1));
      expect(range.end, now);
    });

    test(
        'rangeForPreset(ano, now) starts on 1 January of the calendar year '
        '(A2)', () {
      final now = DateTime(2026, 8, 11);

      final range = rangeForPreset(ExpensePeriodPreset.ano, now);

      expect(range.start, DateTime(2026, 1, 1));
      expect(range.end, now);
    });

    test('currentMonthRange matches rangeForPreset(mesAtual, ...)', () {
      final now = DateTime(2026, 5, 20);

      expect(currentMonthRange(now).start,
          rangeForPreset(ExpensePeriodPreset.mesAtual, now).start);
    });
  });

  group('lastMonthsTotals (redesign, gastos consolidados)', () {
    test('returns a fixed length of 6 by default', () {
      final result = lastMonthsTotals(const [], DateTime(2026, 6, 15));
      expect(result.length, 6);
    });

    test('is ordered oldest to newest, ending on now\'s month', () {
      final now = DateTime(2026, 6, 15);
      final result = lastMonthsTotals(const [], now);

      expect(result.map((m) => (m.year, m.month)).toList(), [
        (2026, 1),
        (2026, 2),
        (2026, 3),
        (2026, 4),
        (2026, 5),
        (2026, 6),
      ]);
    });

    test('a month with no matching item still appears with total zero', () {
      final now = DateTime(2026, 6, 1);
      final items = [_manual(amount: 50.0, expenseDate: DateTime(2026, 6, 1))];

      final result = lastMonthsTotals(items, now);

      final january = result.firstWhere((m) => m.month == 1);
      expect(january.total, 0.0);
    });

    test('sums two items in the same month', () {
      final now = DateTime(2026, 6, 1);
      final items = [
        _manual(id: 'a', amount: 30.0, expenseDate: DateTime(2026, 6, 5)),
        _manual(id: 'b', amount: 20.0, expenseDate: DateTime(2026, 6, 20)),
      ];

      final result = lastMonthsTotals(items, now);

      final june = result.firstWhere((m) => m.month == 6);
      expect(june.total, 50.0);
    });

    test('crosses a year boundary when now is in February', () {
      final now = DateTime(2026, 2, 10);
      final items = [
        _manual(amount: 75.0, expenseDate: DateTime(2025, 9, 15)),
      ];

      final result = lastMonthsTotals(items, now);

      expect(result.map((m) => (m.year, m.month)).toList(), [
        (2025, 9),
        (2025, 10),
        (2025, 11),
        (2025, 12),
        (2026, 1),
        (2026, 2),
      ]);
      final september = result.firstWhere((m) => m.year == 2025 && m.month == 9);
      expect(september.total, 75.0);
    });
  });
}
