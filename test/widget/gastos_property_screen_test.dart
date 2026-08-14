// Quick task 260813-x4f — GastosPropertyScreen (/gastos, 6a branch, reversão
// da decisão da Fase 7). Harness `setSurfaceSize` de
// `test/widget/lotes_desktop_test.dart`; fixtures no molde de
// `expense_calculations_test.dart`.
import 'package:campo_gestor/core/providers/current_property_provider.dart';
import 'package:campo_gestor/core/router/routes.dart';
import 'package:campo_gestor/core/widgets/ui.dart';
import 'package:campo_gestor/features/auth/data/property_repository.dart';
import 'package:campo_gestor/features/dashboard/data/dashboard_providers.dart';
import 'package:campo_gestor/features/gastos/data/expense_calculations.dart';
import 'package:campo_gestor/features/gastos/data/expense_model.dart';
import 'package:campo_gestor/features/gastos/data/expense_repository.dart';
import 'package:campo_gestor/features/gastos/presentation/_expense_list_item_card.dart';
import 'package:campo_gestor/features/gastos/presentation/gastos_property_screen.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_model.dart';
import 'package:campo_gestor/features/piquetes/data/piquete_repository.dart';
import 'package:campo_gestor/features/sanitario/data/sanitary_application_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';

// ---------------------------------------------------------------------------
// Fake data — dois gastos manuais em piquetes diferentes + uma aplicação
// sanitária com custo, todos no mês corrente (data mid-month para não
// esbarrar em virada de mês do relógio real do teste).
// ---------------------------------------------------------------------------

final _now = DateTime.now();
// Today's date (not a fixed day-15) — a fixed day risks landing after "now"
// early in the month, which `rangeForPreset(mesAtual, now)` (end: now) would
// then filter out as a future date.
final _midMonth = DateTime(_now.year, _now.month, _now.day);

const _prop = SelectedProperty(id: 'prop-1', name: 'Fazenda Alpha');
const _vetMembership =
    PropertyMembership(property: _prop, role: 'veterinarian');

final _paddockA = Paddock(
  id: 'pad-a',
  propertyId: 'prop-1',
  name: 'Piquete A',
  areaHa: 10,
  uaCapacity: 20,
  createdAt: DateTime(2026, 1, 1),
);

final _paddockB = Paddock(
  id: 'pad-b',
  propertyId: 'prop-1',
  name: 'Piquete B',
  areaHa: 12,
  uaCapacity: 18,
  createdAt: DateTime(2026, 1, 1),
);

final _paddocks = <Paddock>[_paddockA, _paddockB];

final _expenseA = Expense(
  id: 'exp-a',
  propertyId: 'prop-1',
  paddockId: 'pad-a',
  category: 'racao_suplementacao',
  amount: 100.0,
  expenseDate: _midMonth,
  createdBy: 'user-1',
  createdAt: _midMonth,
  updatedAt: _midMonth,
);

final _expenseB = Expense(
  id: 'exp-b',
  propertyId: 'prop-1',
  paddockId: 'pad-b',
  category: 'combustivel',
  amount: 200.0,
  expenseDate: _midMonth,
  createdBy: 'user-1',
  createdAt: _midMonth,
  updatedAt: _midMonth,
);

final _application = SanitaryApplication(
  id: 'app-1',
  propertyId: 'prop-1',
  lotId: 'lot-1',
  lotName: 'Lote 1',
  paddockId: 'pad-b',
  paddockName: 'Piquete B',
  doseId: 'dose-1',
  doseName: 'Vacina X',
  dosagePerKg: 1.0,
  dosagePerUa: 400.0,
  totalCost: 50.0,
  appliedAt: _midMonth,
  appliedBy: 'user-1',
  animalCount: 1,
  totalUa: 1.0,
  totalVolume: 400.0,
  skippedCount: 0,
  createdAt: _midMonth,
);

// Total: 100 + 200 + 50 = 350.
final _items = <ExpenseListItem>[
  ExpenseListItem.manual(_expenseA),
  ExpenseListItem.manual(_expenseB),
  ExpenseListItem.sanitary(_application),
];

// ---------------------------------------------------------------------------
// Router stub (go_router needs a MaterialApp.router)
// ---------------------------------------------------------------------------

GoRouter _buildRouter() => GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const GastosPropertyScreen(),
        ),
        GoRoute(
          path: AppRoutes.aplicacaoById,
          builder: (context, state) => Scaffold(
            body: Text('aplicacao-${state.pathParameters['id']}'),
          ),
        ),
      ],
    );

Widget _buildScreen(List<ExpenseListItem> items) {
  return ProviderScope(
    overrides: [
      unifiedExpenseListByPropertyProvider.overrideWith((ref) async => items),
      paddockListProvider.overrideWith((ref) async => _paddocks),
      dashboardKpisProvider.overrideWith(
        (ref) async => const DashboardKpis(
          activeAnimals: 10,
          totalUa: 10.0,
          totalHa: 50.0,
        ),
      ),
      // Single membership -> CurrentPropertyNotifier auto-selects it
      // (D-04-01, mirrors lotes_desktop_test.dart).
      memberPropertiesProvider.overrideWith((ref) async => [_vetMembership]),
    ],
    child: MaterialApp.router(routerConfig: _buildRouter()),
  );
}

Future<void> _pumpDesktop(
  WidgetTester tester,
  List<ExpenseListItem> items,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(1440, 900));
  await tester.pumpWidget(_buildScreen(items));
  await tester.pumpAndSettle();
}

Future<void> _pumpMobile(
  WidgetTester tester,
  List<ExpenseListItem> items,
) async {
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.binding.setSurfaceSize(const Size(800, 600));
  await tester.pumpWidget(_buildScreen(items));
  await tester.pumpAndSettle();
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() => initializeDateFormatting('pt_BR'));

  group('GastosPropertyScreen — /gastos consolidado (260813-x4f)', () {
    testWidgets(
        '1440x900: tabela + painel ancorado de 380px renderizam, total do '
        'rodapé bate com o subtítulo do header', (tester) async {
      await _pumpDesktop(tester, _items);

      // 'TOTAL' foi absorvido pelo rodapé com contagem — o rótulo sumiu,
      // o rodapé agora mostra o mesmo texto plural do subtítulo do header.
      expect(find.textContaining('lançamentos'), findsNWidgets(2));
      // Header subtitle ("N lançamentos · R$ 350,00") + table footer share
      // the same figure — computed once, not recalculated separately. (The
      // painel's "Total do mês"/"Últimos 6 meses" blocks coincidentally show
      // the same number here because every fixture falls in the current
      // month — that's additional confirmation, not noise.)
      expect(find.textContaining('R\$ 350,00'), findsAtLeastNWidgets(2));
      expect(
        tester.getSize(find.byKey(const ValueKey('gastos-painel'))).width,
        380,
      );
    });

    testWidgets(
        '1440x900: chips de período substituem o dropdown e refiltram a '
        'tabela', (tester) async {
      await _pumpDesktop(tester, _items);

      expect(find.text('Mês atual'), findsOneWidget);
      expect(find.text('Ano'), findsOneWidget);
      expect(find.byType(DropdownButton<ExpensePeriodPreset>), findsNothing);

      // Todas as fixtures caem no mês corrente — trocar para "Mês passado"
      // deve esvaziar a tabela, provando que o chip refiltra de verdade.
      await tester.tap(find.text('Mês passado'));
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets(
        '1440x900: cabeçalhos DATA/CATEGORIA/PIQUETE/VALOR e os nomes dos '
        'dois piquetes aparecem nas linhas', (tester) async {
      await _pumpDesktop(tester, _items);

      expect(find.text('DATA'), findsOneWidget);
      expect(find.text('CATEGORIA'), findsOneWidget);
      expect(find.text('PIQUETE'), findsOneWidget);
      expect(find.text('VALOR'), findsOneWidget);
      expect(find.text('Piquete A'), findsWidgets);
      expect(find.text('Piquete B'), findsWidgets);
    });

    testWidgets(
        '800x600: sem tabela (nenhum cabeçalho DATA), ExpenseListItemCard '
        'presente — caminho mobile intacto', (tester) async {
      await _pumpMobile(tester, _items);

      expect(find.text('DATA'), findsNothing);
      expect(find.byType(ExpenseListItemCard), findsWidgets);
      // <1024 continua com o dropdown de período, sem chips — o dropdown
      // fechado só renderiza o item selecionado ("Mês atual").
      expect(find.byType(DropdownButton<ExpensePeriodPreset>), findsOneWidget);
      expect(find.text('Mês passado'), findsNothing);
    });

    testWidgets('1440x900: lista vazia mostra EmptyState', (tester) async {
      await _pumpDesktop(tester, const []);

      expect(find.byType(EmptyState), findsOneWidget);
    });
  });
}
