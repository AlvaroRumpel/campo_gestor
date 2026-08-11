import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/expense_repository.dart';

/// The paddock-detail entry point into `/gastos/:paddockId` (D-09) — a
/// "Gastos" card showing the current-month total. Extracted as its own
/// widget, in its own file, so its three async states are testable in
/// isolation (the same arrangement `LotsSection` already uses for
/// `PaddockDetailScreen`'s lots list).
///
/// Tappable in every state, including error, and for every role — reading
/// the expense total is open to every member (D-24). Only the write
/// affordances inside `/gastos/:paddockId` itself are gated by
/// `canManageExpenses` (07-03); this card carries no role gate of its own.
class PaddockExpenseSummaryCard extends ConsumerWidget {
  const PaddockExpenseSummaryCard({super.key, required this.paddockId});

  final String paddockId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalAsync = ref.watch(paddockMonthExpenseTotalProvider(paddockId));

    final (subtitle, trailing) = totalAsync.when<(Widget, Widget)>(
      data: (value) => (
        Text(
          '${formatCurrencyBrl(value)} este mês',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const Icon(Icons.chevron_right),
      ),
      // No skeleton/shimmer pattern exists in this codebase — do not
      // introduce one here.
      loading: () => (
        const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
        const Icon(Icons.chevron_right),
      ),
      // A failed load must never degrade to a formatted zero — "R$ 0,00"
      // reads as "this paddock had no expenses this month", not "the total
      // could not be loaded" (T-07-28).
      error: (err, st) => (
        const Text('—'),
        IconButton(
          icon: const Icon(Icons.refresh),
          onPressed: () =>
              ref.invalidate(paddockMonthExpenseTotalProvider(paddockId)),
        ),
      ),
    );

    return Card(
      child: ListTile(
        title: Text('Gastos', style: Theme.of(context).textTheme.titleMedium),
        subtitle: subtitle,
        trailing: trailing,
        onTap: () => context.push(AppRoutes.gastosPorPiquete(paddockId)),
      ),
    );
  }
}
