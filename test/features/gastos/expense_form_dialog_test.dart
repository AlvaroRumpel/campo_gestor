// GAST-01 — ExpenseFormDialog widget tests (07-UI-SPEC.md E2/E6).
//
// Lives under test/features/gastos/ rather than test/widget/ (where every
// other dialog widget test in this project lives) because
// `flutter test test/features/gastos/` is the declared 15-second feedback
// command in 07-VALIDATION.md — GAST-01's only automated coverage would
// otherwise sit outside that loop.
//
// Covers required-field validation (categoria/valor/data), the pt-BR
// comma-decimal parse, zero/negative rejection, the optional description
// field, create-vs-edit dispatch, the "Mais N" category-chip expansion
// (redesign spec 4.18), and confirmDeleteExpense's title copy.
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/gastos/presentation/expense_form_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

// ---------------------------------------------------------------------------
// Fake in-memory ExpenseRepository — no mocktail chain needed.
// ---------------------------------------------------------------------------
class _FakeExpenseRepository implements ExpenseRepository {
  int createCallCount = 0;
  int updateCallCount = 0;
  Map<String, dynamic>? lastCreateArgs;
  Map<String, dynamic>? lastUpdateArgs;

  @override
  Future<List<Expense>> fetchExpensesByPaddock(
    String paddockId, {
    bool includeArchived = false,
  }) async =>
      [];

  @override
  Future<List<Expense>> fetchExpensesByProperty(String propertyId) async => [];

  @override
  Future<Expense> createExpense({
    required String propertyId,
    String? paddockId,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    createCallCount++;
    lastCreateArgs = {
      'propertyId': propertyId,
      'paddockId': paddockId,
      'category': category,
      'amount': amount,
      'expenseDate': expenseDate,
      'description': description,
    };
    return _expenseFixture(
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      description: description,
    );
  }

  @override
  Future<Expense> updateExpense({
    required String id,
    required String category,
    required double amount,
    required DateTime expenseDate,
    String? description,
  }) async {
    updateCallCount++;
    lastUpdateArgs = {
      'id': id,
      'category': category,
      'amount': amount,
      'expenseDate': expenseDate,
      'description': description,
    };
    return _expenseFixture(
      id: id,
      category: category,
      amount: amount,
      expenseDate: expenseDate,
      description: description,
    );
  }

  @override
  Future<void> archiveExpense(String id) async {}

  @override
  Future<void> restoreExpense(String id) async {}
}

// ---------------------------------------------------------------------------
// Sample data
// ---------------------------------------------------------------------------

Expense _expenseFixture({
  String id = 'exp-1',
  String category = 'racao_suplementacao',
  double amount = 500,
  DateTime? expenseDate,
  String? description,
}) =>
    Expense(
      id: id,
      propertyId: 'prop-1',
      paddockId: 'pad-1',
      category: category,
      amount: amount,
      expenseDate: expenseDate ?? DateTime(2026, 1, 1),
      description: description,
      createdBy: 'user-1',
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

// ---------------------------------------------------------------------------
// Widget builder — mounts the form through showAdaptiveForm, the same entry
// point GastosScreen uses (dialog variant at the default 800px test surface).
// ---------------------------------------------------------------------------

Widget _buildApp({
  required _FakeExpenseRepository repo,
  Expense? expense,
}) {
  return ProviderScope(
    overrides: [
      expenseRepositoryProvider.overrideWithValue(repo),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [Locale('pt', 'BR')],
      home: Scaffold(
        body: Builder(
          builder: (ctx) => ElevatedButton(
            onPressed: () => showAdaptiveForm<bool>(
              context: ctx,
              builder: (_) => ExpenseFormDialog(
                propertyId: 'prop-1',
                paddockId: 'pad-1',
                expense: expense,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    ),
  );
}

Future<void> _selectCategory(
  WidgetTester tester, [
  String label = 'Ração/Suplementação',
]) async {
  await tester.tap(find.text(label).last);
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  group('ExpenseFormDialog (GAST-01, 07-UI-SPEC E2)', () {
    testWidgets(
        'create mode: title "Novo gasto", 5 primary category chips and a '
        '"Mais 4" chip that expands the remaining categories', (tester) async {
      await tester.pumpWidget(_buildApp(repo: _FakeExpenseRepository()));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Novo gasto'), findsOneWidget);
      for (final label in [
        'Ração/Suplementação',
        'Mão de obra',
        'Manutenção',
        'Pastagem/Adubação',
        'Combustível',
      ]) {
        expect(find.text(label), findsOneWidget);
      }
      // The 4 non-primary categories start hidden behind "Mais 4".
      expect(find.text('Mais 4'), findsOneWidget);
      expect(find.text('Sanidade/Medicamentos'), findsNothing);
      expect(find.text('Arrendamento'), findsNothing);
      expect(find.text('Outros'), findsNothing);

      await tester.tap(find.text('Mais 4'));
      await tester.pumpAndSettle();

      expect(find.text('Mais 4'), findsNothing);
      expect(find.text('Sanidade/Medicamentos'), findsOneWidget);
      expect(find.text('Arrendamento'), findsOneWidget);
      expect(find.text('Outros'), findsOneWidget);
    });

    testWidgets(
        'blank form: shows validation errors and calls no repository method',
        (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Selecione a categoria do gasto'), findsOneWidget);
      expect(find.text('Valor é obrigatório'), findsOneWidget);
      expect(repo.createCallCount, 0);
      expect(repo.updateCallCount, 0);
    });

    testWidgets(
        'valid create: valor "1240,50" calls createExpense once with '
        'amount == 1240.50 and the tapped chip category', (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _selectCategory(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor *'),
        '1240,50',
      );
      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(repo.createCallCount, 1);
      expect(repo.lastCreateArgs?['amount'], 1240.50);
      expect(repo.lastCreateArgs?['category'], 'racao_suplementacao');
    });

    testWidgets('valor "0" is rejected and calls no repository method',
        (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _selectCategory(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor *'),
        '0',
      );
      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Valor deve ser maior que zero'), findsOneWidget);
      expect(repo.createCallCount, 0);
    });

    testWidgets('valor "-5" is rejected and calls no repository method',
        (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _selectCategory(tester);

      // The `[0-9.,]` input formatter blocks '-' from a real keystroke, so
      // the controller is set directly here — this proves the *validator*
      // itself rejects a negative parsed value, independent of whether the
      // formatter can ever be bypassed by typing (paste/IME/a11y input).
      final field = tester.widget<TextFormField>(
        find.widgetWithText(TextFormField, 'Valor *'),
      );
      field.controller!.text = '-5';
      await tester.pump();

      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(find.text('Valor deve ser maior que zero'), findsOneWidget);
      expect(repo.createCallCount, 0);
    });

    testWidgets(
        'blank descrição succeeds — createExpense is called with a null description',
        (tester) async {
      final repo = _FakeExpenseRepository();
      await tester.pumpWidget(_buildApp(repo: repo));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      await _selectCategory(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Valor *'),
        '100,00',
      );
      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(repo.createCallCount, 1);
      expect(repo.lastCreateArgs?['description'], isNull);
    });

    testWidgets(
        'edit mode: title "Editar gasto", fields pre-filled, submit calls '
        'updateExpense with the untouched original category, not createExpense',
        (tester) async {
      final repo = _FakeExpenseRepository();
      final existing = _expenseFixture(amount: 500, description: 'Ração');
      await tester.pumpWidget(_buildApp(repo: repo, expense: existing));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.text('Editar gasto'), findsOneWidget);
      expect(find.text('500,00'), findsOneWidget);
      expect(find.text('Ração'), findsOneWidget);

      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(repo.updateCallCount, 1);
      expect(repo.createCallCount, 0);
      expect(repo.lastUpdateArgs?['category'], 'racao_suplementacao');
    });

    testWidgets(
        'edit mode with a category hidden behind "Mais N": its chip is shown '
        'expanded from the start', (tester) async {
      final repo = _FakeExpenseRepository();
      final existing = _expenseFixture(category: 'arrendamento', amount: 250);
      await tester.pumpWidget(_buildApp(repo: repo, expense: existing));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      // No "Mais N" chip — the full set is expanded so the stored category
      // is visible and selected, and submitting keeps it.
      expect(find.textContaining('Mais '), findsNothing);
      expect(find.text('Arrendamento'), findsOneWidget);

      await tester.tap(find.text('Salvar gasto'));
      await tester.pumpAndSettle();

      expect(repo.updateCallCount, 1);
      expect(repo.lastUpdateArgs?['category'], 'arrendamento');
    });

    testWidgets(
        'confirmDeleteExpense: title contains the formatted value and dd/MM date, returns false on Cancelar',
        (tester) async {
      bool? result;
      final expense =
          _expenseFixture(amount: 1240.50, expenseDate: DateTime(2026, 8, 15));

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () async {
                  result = await confirmDeleteExpense(ctx, expense);
                },
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      expect(find.textContaining('R\$ 1.240,50'), findsOneWidget);
      expect(find.textContaining('15/08'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(result, false);
    });
  });
}
