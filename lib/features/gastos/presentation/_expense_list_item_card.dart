import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// One row in the unified `/gastos/:paddockId` list (D-32) — either a manual
/// [Expense] (editable/deletable when [canManage]) or a read-only
/// [SanitaryApplication]. Branches with a `switch` on the sealed
/// [ExpenseListItem] union, mirroring `_AplicacaoCard`/`_DoseCard`'s shell
/// (`sanitario_screen.dart`) and `_PaddockCard`'s tappable-card shape
/// (`piquetes_screen.dart`).
class ExpenseListItemCard extends StatelessWidget {
  const ExpenseListItemCard({
    super.key,
    required this.item,
    required this.canManage,
    this.onTap,
    this.onDelete,
    this.onRestore,
  });

  final ExpenseListItem item;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onDelete;

  /// Restore an archived expense (G-07-2, found in UAT). `deleted_at` is
  /// reversible by design — the RLS UPDATE policy deliberately carries no
  /// `deleted_at` predicate so an archived row can be un-archived (the
  /// G-06-2 lesson), and the pgTAP suite asserts the restore round-trip.
  /// Before this, `ExpenseRepository.restoreExpense` had no caller and an
  /// archived row still showed the *delete* icon.
  final VoidCallback? onRestore;

  @override
  Widget build(BuildContext context) {
    return switch (item) {
      ManualExpenseItem(:final expense) => _buildManual(context, expense),
      SanitaryExpenseItem(:final application) =>
        _buildSanitary(context, application),
    };
  }

  Widget _buildManual(BuildContext context, Expense expense) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDeleted = expense.deletedAt != null;

    final description = expense.description;
    final subtitle = [
      _dateFmt.format(expense.expenseDate),
      if (description != null && description.isNotEmpty) description,
    ].join(' · ');

    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        // Tappable only when canManage (D-23) — reading a manual expense's
        // detail happens through the edit dialog, which is a write surface.
        onTap: canManage ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(kExpenseCategoryIcons[expense.category] ?? Icons.more_horiz),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            kExpenseCategoryLabels[expense.category] ??
                                expense.category,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isDeleted) ...[
                          const SizedBox(width: 8),
                          _Badge(
                            label: 'Excluído',
                            background: colorScheme.errorContainer,
                            foreground: colorScheme.onErrorContainer,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A soft-deleted row (only reachable with "Mostrar
                  // excluídos" on) contributes 0 to the header total
                  // (expense_calculations.dart's amountOf is never called on
                  // it there — the screen filters it out before summing).
                  // This struck-through figure plus the "Excluído" badge
                  // above is what keeps the on-screen total reconcilable
                  // with the visible rows, instead of the row disappearing.
                  Text(
                    formatCurrencyBrl(expense.amount),
                    style: isDeleted
                        ? theme.textTheme.bodyMedium?.copyWith(
                            decoration: TextDecoration.lineThrough,
                          )
                        : theme.textTheme.bodyMedium,
                  ),
                  // An archived row offers restore, never delete — deleting
                  // an already-deleted expense is a no-op that reads as a
                  // broken control (G-07-2).
                  if (canManage)
                    if (isDeleted)
                      IconButton(
                        icon: const Icon(Icons.restore_from_trash_outlined),
                        tooltip: 'Restaurar gasto',
                        onPressed: onRestore,
                      )
                    else
                      IconButton(
                        icon: const Icon(Icons.delete_outline),
                        tooltip: 'Excluir gasto',
                        onPressed: onDelete,
                      ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Read-only (D-32): no edit, no delete control, under any [canManage]
  /// value. [onTap] always fires — the caller routes it to
  /// `AppRoutes.aplicacaoDetail`, unrelated to write permission.
  Widget _buildSanitary(BuildContext context, SanitaryApplication application) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final totalCost = application.totalCost;

    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(kSanitaryCategoryIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            application.doseName,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _Badge(
                          label: 'Sanitário',
                          background: colorScheme.surfaceContainerHigh,
                          foreground: colorScheme.onSurface,
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${_dateFmt.format(application.appliedAt)} · '
                      '${application.lotName}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              // Never a formatted zero (Claude's Discretion resolution to
              // D-11 Phase 6, T-07-25) — a NULL totalCost renders the literal
              // em dash, still counts toward itemCount but contributes 0 to
              // the total (expense_calculations.dart#amountOf).
              Text(
                totalCost != null ? formatCurrencyBrl(totalCost.abs()) : '—',
                style: theme.textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Small rounded status badge — same shape as `_Badge` in
/// `sanitario_screen.dart` (private-per-file duplication is this codebase's
/// established convention for this exact widget).
class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}
