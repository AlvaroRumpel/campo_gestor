// GAST-01/GAST-02 — the manual+sanitary merge that folds Phase 6 sanitary
// rows into one date-ordered list. Pure Dart fixtures only — no mocks, no
// ProviderContainer, no network (D-30, D-33).
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({
  String id = 'exp-1',
  String paddockId = 'paddock-1',
  double amount = 100.0,
  DateTime? expenseDate,
  DateTime? createdAt,
}) {
  return Expense(
    id: id,
    propertyId: 'prop-1',
    paddockId: paddockId,
    category: 'combustivel',
    amount: amount,
    expenseDate: expenseDate ?? DateTime(2026, 1, 1),
    createdBy: 'user-1',
    createdAt: createdAt ?? DateTime(2026, 1, 1),
    updatedAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

SanitaryApplication _application({
  String id = 'app-1',
  String paddockId = 'paddock-1',
  double? totalCost = 40.0,
  DateTime? appliedAt,
  DateTime? createdAt,
  String? reversesApplicationId,
}) {
  return SanitaryApplication(
    id: id,
    propertyId: 'prop-1',
    lotId: 'lot-1',
    lotName: 'Lote 1',
    paddockId: paddockId,
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
    reversesApplicationId: reversesApplicationId,
    createdAt: createdAt ?? DateTime(2026, 1, 1),
  );
}

void main() {
  group('buildUnifiedExpenseItems (D-29, D-30, D-32, D-33)', () {
    test('2 expenses, 0 applications returns 2 ManualExpenseItems', () {
      final expenses = [_expense(id: 'a'), _expense(id: 'b')];

      final result = buildUnifiedExpenseItems(
        expenses: expenses,
        applications: const [],
        paddockId: 'paddock-1',
      );

      expect(result.length, 2);
      expect(result.every((i) => i is ManualExpenseItem), isTrue);
    });

    test('an application whose paddockId differs is excluded', () {
      final applications = [_application(id: 'app-a', paddockId: 'other-paddock')];

      final result = buildUnifiedExpenseItems(
        expenses: const [],
        applications: applications,
        paddockId: 'paddock-1',
      );

      expect(result, isEmpty);
    });

    test('an application whose paddockId matches is wrapped as a '
        'SanitaryExpenseItem', () {
      final applications = [_application(id: 'app-a', paddockId: 'paddock-1')];

      final result = buildUnifiedExpenseItems(
        expenses: const [],
        applications: applications,
        paddockId: 'paddock-1',
      );

      expect(result.length, 1);
      expect(result.single, isA<SanitaryExpenseItem>());
    });

    test(
        'given an original application and its reversal, both are excluded '
        '(D-33)', () {
      final original = _application(id: 'orig', paddockId: 'paddock-1');
      final reversal = _application(
        id: 'rev',
        paddockId: 'paddock-1',
        reversesApplicationId: 'orig',
      );

      final result = buildUnifiedExpenseItems(
        expenses: const [],
        applications: [original, reversal],
        paddockId: 'paddock-1',
      );

      expect(result, isEmpty);
    });

    test('the returned list is ordered by date descending across both '
        'variants', () {
      final expenses = [
        _expense(id: 'manual-early', expenseDate: DateTime(2026, 1, 1)),
      ];
      final applications = [
        _application(
          id: 'sanitary-late',
          paddockId: 'paddock-1',
          appliedAt: DateTime(2026, 2, 1),
        ),
      ];

      final result = buildUnifiedExpenseItems(
        expenses: expenses,
        applications: applications,
        paddockId: 'paddock-1',
      );

      expect(result.first, isA<SanitaryExpenseItem>());
      expect(result.last, isA<ManualExpenseItem>());
    });

    test('two items on the same date are ordered by createdAt descending',
        () {
      final sameDate = DateTime(2026, 1, 1);
      final expenses = [
        _expense(
          id: 'early',
          expenseDate: sameDate,
          createdAt: DateTime(2026, 1, 1, 8),
        ),
      ];
      final applications = [
        _application(
          id: 'late',
          paddockId: 'paddock-1',
          appliedAt: sameDate,
          createdAt: DateTime(2026, 1, 1, 10),
        ),
      ];

      final result = buildUnifiedExpenseItems(
        expenses: expenses,
        applications: applications,
        paddockId: 'paddock-1',
      );

      expect(result.first, isA<SanitaryExpenseItem>());
      expect(result.last, isA<ManualExpenseItem>());
    });

    test('returns a new list and does not mutate either input list', () {
      final expenses = [_expense(id: 'a')];
      final applications = [_application(id: 'b', paddockId: 'paddock-1')];

      buildUnifiedExpenseItems(
        expenses: expenses,
        applications: applications,
        paddockId: 'paddock-1',
      );

      expect(expenses.length, 1);
      expect(expenses.single.id, 'a');
      expect(applications.length, 1);
      expect(applications.single.id, 'b');
    });
  });
}
