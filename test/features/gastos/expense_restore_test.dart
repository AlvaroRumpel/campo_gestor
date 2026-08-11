// G-07-2 regression guard (found in Phase 7 UAT): a soft-deleted expense
// could not be restored from the UI. `ExpenseRepository.restoreExpense` was
// implemented and the RLS UPDATE policy was deliberately written without a
// `deleted_at` predicate so the round-trip works at the DB level (the G-06-2
// lesson, asserted by 07_expenses_test.sql) — but nothing in the UI ever
// called it, and an already-archived row still showed the *delete* icon.
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/gastos/presentation/_expense_list_item_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Expense _expense({DateTime? deletedAt}) => Expense(
      id: 'exp-1',
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      category: 'arrendamento',
      amount: 250.00,
      expenseDate: DateTime(2026, 8, 11),
      createdBy: 'user-1',
      createdAt: DateTime(2026, 8, 11),
      updatedAt: DateTime(2026, 8, 11),
      deletedAt: deletedAt,
    );

Widget _host({
  required Expense expense,
  required bool canManage,
  VoidCallback? onDelete,
  VoidCallback? onRestore,
}) {
  return MaterialApp(
    home: Scaffold(
      body: ExpenseListItemCard(
        item: ManualExpenseItem(expense),
        canManage: canManage,
        onDelete: onDelete,
        onRestore: onRestore,
      ),
    ),
  );
}

void main() {
  group('ExpenseListItemCard delete/restore affordance (G-07-2)', () {
    testWidgets('an active expense offers delete, not restore',
        (tester) async {
      await tester.pumpWidget(_host(
        expense: _expense(),
        canManage: true,
        onDelete: () {},
        onRestore: () {},
      ));

      expect(find.byIcon(Icons.delete_outline), findsOneWidget);
      expect(find.byIcon(Icons.restore_from_trash_outlined), findsNothing);
    });

    testWidgets(
      'an archived expense offers restore and NOT delete — deleting an '
      'already-deleted row is a no-op that reads as a broken control',
      (tester) async {
        await tester.pumpWidget(_host(
          expense: _expense(deletedAt: DateTime(2026, 8, 11)),
          canManage: true,
          onDelete: () {},
          onRestore: () {},
        ));

        expect(find.byIcon(Icons.restore_from_trash_outlined), findsOneWidget);
        expect(find.byIcon(Icons.delete_outline), findsNothing);
      },
    );

    testWidgets('tapping restore invokes onRestore exactly once',
        (tester) async {
      var restoreCalls = 0;
      await tester.pumpWidget(_host(
        expense: _expense(deletedAt: DateTime(2026, 8, 11)),
        canManage: true,
        onRestore: () => restoreCalls++,
      ));

      await tester.tap(find.byIcon(Icons.restore_from_trash_outlined));
      await tester.pump();

      expect(restoreCalls, 1);
    });

    testWidgets('a reader sees neither delete nor restore on an archived row',
        (tester) async {
      await tester.pumpWidget(_host(
        expense: _expense(deletedAt: DateTime(2026, 8, 11)),
        canManage: false,
      ));

      expect(find.byIcon(Icons.restore_from_trash_outlined), findsNothing);
      expect(find.byIcon(Icons.delete_outline), findsNothing);
    });
  });
}
