import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../../gastos/data/expense_calculations.dart';
import '../../gastos/data/expense_model.dart';
import '../../gastos/data/expense_repository.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import '../../sanitario/data/sanitary_calculations.dart';

/// KPIs do header do Início (spec 4.1 / 4.14).
class DashboardKpis {
  const DashboardKpis({
    required this.activeAnimals,
    required this.totalUa,
    required this.totalHa,
  });

  final int activeAnimals;
  final double totalUa;
  final double totalHa;

  /// Null quando não há hectares cadastrados — a UI renderiza "—".
  double? get uaPerHa => totalHa > 0 ? totalUa / totalHa : null;
}

/// Piquete + UA atual (soma dos pesos UA dos animais ativos alocados nele).
class PaddockOccupancy {
  const PaddockOccupancy({required this.paddock, required this.currentUa});

  final Paddock paddock;
  final double currentUa;

  double get ratio =>
      paddock.uaCapacity > 0 ? currentUa / paddock.uaCapacity : 0.0;

  /// Null quando o piquete não tem área — a UI renderiza "—".
  double? get uaPerHa =>
      paddock.areaHa > 0 ? currentUa / paddock.areaHa : null;

  bool get overCapacity =>
      paddock.uaCapacity > 0 && currentUa > paddock.uaCapacity;
}

/// Item acionável do banner "Precisa de você hoje" (spec 3.14).
class DashboardAlert {
  const DashboardAlert({
    required this.figure,
    required this.text,
    required this.route,
  });

  /// Número em destaque (mono 20/700 mobile, 24/700 desktop).
  final String figure;
  final String text;
  final String route;
}

/// Gastos do mês corrente da propriedade (manuais + sanitário, D-33).
class MonthExpenses {
  const MonthExpenses({required this.total, required this.perAnimal});

  final double total;

  /// Null quando não há animais ativos — a UI omite a linha "por animal".
  final double? perAnimal;
}

/// Agrupa a UA ativa por piquete e ordena por taxa de lotação decrescente,
/// para o card "Lotação por piquete" abrir pelo mais crítico. Pure — testável
/// sem Supabase.
List<PaddockOccupancy> buildPaddockOccupancies(
  List<Paddock> paddocks,
  List<AnimalWithContext> animals,
) {
  final uaByPaddock = <String, double>{};
  for (final a in animals) {
    if (a.animal.deletedAt != null) continue;
    uaByPaddock[a.paddockId] =
        (uaByPaddock[a.paddockId] ?? 0.0) + (kUaWeights[a.animal.category] ?? 0.0);
  }
  final list = [
    for (final p in paddocks)
      PaddockOccupancy(paddock: p, currentUa: uaByPaddock[p.id] ?? 0.0),
  ];
  list.sort((a, b) => b.ratio.compareTo(a.ratio));
  return list;
}

/// Animais ativos (deleted_at null) da propriedade ativa, com contexto de
/// lote/piquete — base de todos os agregados do Início.
final activeAnimalsProvider =
    FutureProvider<List<AnimalWithContext>>((ref) async {
  final all = await ref.watch(animalListByPropertyProvider.future);
  return all.where((a) => a.animal.deletedAt == null).toList();
});

/// KPIs do header: animais ativos, UA total, UA/ha média.
final dashboardKpisProvider = FutureProvider<DashboardKpis>((ref) async {
  final actives = await ref.watch(activeAnimalsProvider.future);
  final paddocks = await ref.watch(paddockListProvider.future);
  return DashboardKpis(
    activeAnimals: actives.length,
    totalUa: calcTotalUa(actives.map((a) => a.animal)),
    totalHa: paddocks.fold(0.0, (sum, p) => sum + p.areaHa),
  );
});

/// Lotação por piquete, ordenada pelo mais lotado.
final paddockOccupancyProvider =
    FutureProvider<List<PaddockOccupancy>>((ref) async {
  final paddocks = await ref.watch(paddockListProvider.future);
  final animals = await ref.watch(animalListByPropertyProvider.future);
  return buildPaddockOccupancies(paddocks, animals);
});

/// Itens do banner "Precisa de você hoje": DGs pendentes por ATF ativo e
/// piquetes acima da capacidade. Lista vazia = banner oculto.
final dashboardAlertsProvider =
    FutureProvider<List<DashboardAlert>>((ref) async {
  final atfs = await ref.watch(atfListByPropertyProvider.future);
  final occupancies = await ref.watch(paddockOccupancyProvider.future);
  return [
    for (final s in atfs)
      if (s.atf.active && s.dgSummary.pending > 0)
        DashboardAlert(
          figure: '${s.dgSummary.pending}',
          text: s.dgSummary.pending == 1
              ? 'DG pendente no ${s.atf.name}'
              : 'DGs pendentes no ${s.atf.name}',
          route: AppRoutes.atfDetail(s.atf.id),
        ),
    for (final o in occupancies)
      if (o.overCapacity)
        DashboardAlert(
          figure: formatUa(o.currentUa - o.paddock.uaCapacity),
          text: 'UA acima da capacidade no ${o.paddock.name}',
          route: '/piquetes/${o.paddock.id}',
        ),
  ];
});

/// Total de gastos do mês corrente da propriedade (manuais + aplicações
/// sanitárias visíveis, D-33) e valor por animal ativo.
final monthExpensesProvider = FutureProvider<MonthExpenses>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const MonthExpenses(total: 0, perAnimal: null);

  final expenses = await ref
      .watch(expenseRepositoryProvider)
      .fetchExpensesByProperty(property.id);
  final applications =
      await ref.watch(sanitaryApplicationListByPropertyProvider.future);
  final items = <ExpenseListItem>[
    for (final e in expenses) ExpenseListItem.manual(e),
    for (final a in visibleApplications(applications, showReversed: false))
      ExpenseListItem.sanitary(a),
  ];
  final total = totalAmount(
    filterByDateRange(items, currentMonthRange(DateTime.now())),
  );
  final actives = await ref.watch(activeAnimalsProvider.future);
  return MonthExpenses(
    total: total,
    perAnimal: actives.isEmpty ? null : total / actives.length,
  );
});
