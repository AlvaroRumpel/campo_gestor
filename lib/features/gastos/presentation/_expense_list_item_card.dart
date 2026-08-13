import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';

final _dateFmt = DateFormat('dd/MM');

/// One row in the unified `/gastos/:paddockId` list (D-32, spec 4.12) —
/// either a manual [Expense] (editable/deletable when [canManage]) or a
/// read-only [SanitaryApplication]. Row 64h: ícone-container 38×38 r10 +
/// título 14.5/600 + sub "dd/MM · descrição" 12.5 + valor mono 14.5/700.
/// Excluído: textos esmaecidos + chip danger + valor riscado + restore.
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
    final isDeleted = expense.deletedAt != null;
    final description = expense.description;

    return _Row(
      // Tappable only when canManage (D-23) — reading a manual expense's
      // detail happens through the edit dialog, which is a write surface.
      onTap: canManage ? onTap : null,
      faded: isDeleted,
      icon: kExpenseCategoryIcons[expense.category] ?? Icons.more_horiz,
      iconBackground: AppColors.surfaceVariant,
      iconColor: AppColors.primaryDarkText,
      title: kExpenseCategoryLabels[expense.category] ?? expense.category,
      chip: isDeleted
          ? const StatusChip('Excluído', kind: StatusKind.danger)
          : null,
      subtitleDate: _dateFmt.format(expense.expenseDate),
      subtitleText:
          description != null && description.isNotEmpty ? description : null,
      // A soft-deleted row (only reachable with "Mostrar excluídos" on)
      // contributes 0 to the header total. This struck-through figure plus
      // the "Excluído" chip is what keeps the on-screen total reconcilable
      // with the visible rows, instead of the row disappearing.
      value: formatCurrencyBrl(expense.amount),
      valueStruck: isDeleted,
      // An archived row offers restore, never delete — deleting an
      // already-deleted expense is a no-op that reads as a broken control
      // (G-07-2).
      trailingAction: !canManage
          ? null
          : isDeleted
              ? IconButton(
                  icon: const Icon(Icons.restore_from_trash_outlined, size: 22),
                  tooltip: 'Restaurar gasto',
                  onPressed: onRestore,
                )
              : IconButton(
                  icon: const Icon(Icons.delete_outline, size: 22),
                  tooltip: 'Excluir gasto',
                  onPressed: onDelete,
                ),
    );
  }

  /// Read-only (D-32): no edit, no delete control, under any [canManage]
  /// value. [onTap] always fires — the caller routes it to
  /// `AppRoutes.aplicacaoDetail`, unrelated to write permission.
  Widget _buildSanitary(BuildContext context, SanitaryApplication application) {
    final totalCost = application.totalCost;
    return _Row(
      onTap: onTap,
      icon: kSanitaryCategoryIcon,
      iconBackground: const Color(0x24E8833A), // rgba(232,131,58,0.14)
      iconColor: AppColors.accentDark,
      title: application.doseName,
      chip: const StatusChip(
        kSanitaryPseudoCategoryLabel,
        kind: StatusKind.warning,
      ),
      subtitleDate: _dateFmt.format(application.appliedAt),
      subtitleText: '${application.lotName} · automático',
      // Never a formatted zero (Claude's Discretion resolution to D-11
      // Phase 6, T-07-25) — a NULL totalCost renders the literal em dash,
      // still counts toward itemCount but contributes 0 to the total.
      value: totalCost != null ? formatCurrencyBrl(totalCost.abs()) : '—',
    );
  }
}

/// Anatomia compartilhada da linha (64h, divisor inferior).
class _Row extends StatelessWidget {
  const _Row({
    required this.icon,
    required this.iconBackground,
    required this.iconColor,
    required this.title,
    this.chip,
    required this.subtitleDate,
    this.subtitleText,
    required this.value,
    this.valueStruck = false,
    this.trailingAction,
    this.onTap,
    this.faded = false,
  });

  final IconData icon;
  final Color iconBackground;
  final Color iconColor;
  final String title;
  final Widget? chip;
  final String subtitleDate;
  final String? subtitleText;
  final String value;
  final bool valueStruck;
  final Widget? trailingAction;
  final VoidCallback? onTap;
  final bool faded;

  @override
  Widget build(BuildContext context) {
    final titleColor = faded ? AppColors.textTertiary : AppColors.ink;
    final subColor = faded ? AppColors.textTertiary : AppColors.textSecondary;

    return Material(
      color: AppColors.surface,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              Opacity(
                opacity: faded ? 0.5 : 1,
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: iconBackground,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, size: 20, color: iconColor),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            title,
                            style: TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w600,
                              color: titleColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (chip != null) ...[
                          const SizedBox(width: 7),
                          chip!,
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: subtitleDate,
                            style: monoStyle(size: 12.5, color: subColor),
                          ),
                          if (subtitleText != null)
                            TextSpan(
                              text: ' · $subtitleText',
                              style:
                                  TextStyle(fontSize: 12.5, color: subColor),
                            ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                value,
                style: monoStyle(
                  size: 14.5,
                  weight: FontWeight.w700,
                  color: faded ? AppColors.textTertiary : AppColors.ink,
                ).copyWith(
                  decoration: valueStruck ? TextDecoration.lineThrough : null,
                ),
              ),
              if (trailingAction != null) trailingAction!,
            ],
          ),
        ),
      ),
    );
  }
}
