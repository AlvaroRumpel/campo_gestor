import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/expense_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';
import 'expense_form_dialog.dart';
import '_expense_list_item_card.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// The `/gastos/:paddockId` screen (D-08) — filter row (D-16), always-visible
/// total header (D-17), the unified date-descending list of manual and
/// read-only sanitary rows (D-19, D-32), the two contextual empty states
/// (D-13), and the single "Novo gasto" FAB (D-10), gated by
/// [canManageExpenses] (D-23) rather than `PaddockDetailScreen._canEdit`.
class GastosScreen extends ConsumerStatefulWidget {
  const GastosScreen({super.key, required this.paddockId});

  final String paddockId;

  @override
  ConsumerState<GastosScreen> createState() => _GastosScreenState();
}

class _GastosScreenState extends ConsumerState<GastosScreen> {
  // Never persisted (D-21) — every entry to the screen starts on the current
  // month with no category filter (D-15).
  ExpensePeriodPreset _preset = ExpensePeriodPreset.mesAtual;
  DateTimeRange? _customRange;
  String? _categoryFilter;
  bool _showDeleted = false;

  ExpenseDateRange get _effectiveRange => _customRange != null
      ? ExpenseDateRange(start: _customRange!.start, end: _customRange!.end)
      : rangeForPreset(_preset, DateTime.now());

  void _invalidateProviders() {
    ref.invalidate(unifiedExpenseListByPaddockProvider(widget.paddockId));
    ref.invalidate(
      unifiedExpenseListWithDeletedByPaddockProvider(widget.paddockId),
    );
    ref.invalidate(paddockMonthExpenseTotalProvider(widget.paddockId));
  }

  Future<void> _openCreateDialog(String propertyId) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        propertyId: propertyId,
        paddockId: widget.paddockId,
      ),
    );
    if (saved != true || !mounted) return;
    _invalidateProviders();
  }

  Future<void> _openEditDialog(String propertyId, Expense expense) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        propertyId: propertyId,
        paddockId: widget.paddockId,
        expense: expense,
      ),
    );
    if (saved != true || !mounted) return;
    _invalidateProviders();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await confirmDeleteExpense(context, expense);
    if (!confirmed || !mounted) return;
    await ref.read(expenseRepositoryProvider).archiveExpense(expense.id);
    if (!mounted) return;
    _invalidateProviders();
  }

  Future<void> _pickCustomRange() async {
    final current = _effectiveRange;
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: DateTimeRange(
        start: current.start,
        end: current.end,
      ),
      locale: const Locale('pt', 'BR'),
    );
    // Cancelled: change nothing — the previously selected preset stays
    // selected and the list does not re-filter.
    if (picked == null || !mounted) return;
    setState(() {
      _preset = ExpensePeriodPreset.personalizado;
      _customRange = picked;
    });
  }

  void _clearFilter() {
    setState(() {
      _preset = ExpensePeriodPreset.mesAtual;
      _customRange = null;
      _categoryFilter = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final paddockAsync = ref.watch(paddockByIdProvider(widget.paddockId));
    // Falls back to plain "Gastos" while loading and when the paddock
    // resolves to nothing (a deep-linked foreign paddock, T-07-23) — never
    // an unresolved/empty title.
    final paddockName = paddockAsync.asData?.value?.name;

    final itemsAsync = _showDeleted
        ? ref.watch(
            unifiedExpenseListWithDeletedByPaddockProvider(widget.paddockId),
          )
        : ref.watch(unifiedExpenseListByPaddockProvider(widget.paddockId));

    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canManage = canManageExpenses(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );
    final propertyId = currentPropAsync.asData?.value?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: Text(paddockName != null ? 'Gastos — $paddockName' : 'Gastos'),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => const Center(
          child: Text(
            'Erro ao carregar. Verifique sua conexão e tente novamente.',
          ),
        ),
        data: (items) => _buildBody(items, canManage, propertyId),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton(
              tooltip: 'Novo gasto',
              onPressed: propertyId.isEmpty
                  ? null
                  : () => _openCreateDialog(propertyId),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  Widget _buildBody(
    List<ExpenseListItem> items,
    bool canManage,
    String propertyId,
  ) {
    final filtered = filterByCategory(
      filterByDateRange(items, _effectiveRange),
      _categoryFilter,
    );

    // The total counts non-deleted rows only — a soft-deleted manual row is
    // not a cost, so it contributes 0. Its visible "Excluído" marker
    // (_expense_list_item_card.dart) is what keeps the on-screen total
    // reconcilable with the visible rows instead of the row being hidden.
    final totalSubset = filtered.where(
      (i) => switch (i) {
        ManualExpenseItem(:final expense) => expense.deletedAt == null,
        SanitaryExpenseItem() => true,
      },
    );
    final total = totalAmount(totalSubset);
    final count = itemCount(totalSubset);

    return Column(
      children: [
        _buildFilterRow(),
        _buildTotalHeader(total, count),
        Expanded(
          child: filtered.isEmpty
              ? _EmptyState(
                  neverHad: items.isEmpty,
                  onClearFilter: _clearFilter,
                )
              : _buildList(filtered, canManage, propertyId),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          for (final preset in ExpensePeriodPreset.values)
            if (preset != ExpensePeriodPreset.personalizado)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: FilterChip(
                  label: Text(preset.label),
                  selected: _preset == preset,
                  selectedColor: theme.colorScheme.primary,
                  onSelected: (_) => setState(() {
                    _preset = preset;
                    _customRange = null;
                  }),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilterChip(
              label: Text(
                _preset == ExpensePeriodPreset.personalizado &&
                        _customRange != null
                    ? '${_dateFmt.format(_customRange!.start)} - '
                          '${_dateFmt.format(_customRange!.end)}'
                    : ExpensePeriodPreset.personalizado.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              selected: _preset == ExpensePeriodPreset.personalizado,
              selectedColor: theme.colorScheme.primary,
              onSelected: (_) => _pickCustomRange(),
            ),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: _categoryFilter,
            hint: const Text('Todas as categorias'),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as categorias'),
              ),
              for (final key in kExpenseFilterCategories)
                DropdownMenuItem<String?>(
                  value: key,
                  child: Text(
                    key == kSanitaryPseudoCategory
                        ? kSanitaryPseudoCategoryLabel
                        : (kExpenseCategoryLabels[key] ?? key),
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _categoryFilter = v),
          ),
          const SizedBox(width: 16),
          const Text('Mostrar excluídos'),
          Switch(
            value: _showDeleted,
            onChanged: (v) => setState(() => _showDeleted = v),
          ),
        ],
      ),
    );
  }

  Widget _buildTotalHeader(double total, int count) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            formatCurrencyBrl(total),
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          Text(
            Intl.plural(
              count,
              zero: '$count lançamentos',
              one: '1 lançamento',
              other: '$count lançamentos',
              locale: 'pt_BR',
            ),
            style: theme.textTheme.bodyMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // D-18 ceiling: the header total above sums client-side over this
  // already-loaded list. If this list ever becomes paginated, the total
  // silently becomes "total of this page" — upgrade to a server-side
  // SUM()/RPC at that point, not before.
  Widget _buildList(
    List<ExpenseListItem> filtered,
    bool canManage,
    String propertyId,
  ) {
    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, i) {
        final item = filtered[i];
        final onTap = switch (item) {
          ManualExpenseItem(:final expense) =>
            () => _openEditDialog(propertyId, expense),
          SanitaryExpenseItem(:final application) =>
            () => context.push(AppRoutes.aplicacaoDetail(application.id)),
        };
        final onDelete = switch (item) {
          ManualExpenseItem(:final expense) => () => _deleteExpense(expense),
          SanitaryExpenseItem() => null,
        };
        return ExpenseListItemCard(
          item: item,
          canManage: canManage,
          onTap: onTap,
          onDelete: onDelete,
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.neverHad, required this.onClearFilter});

  final bool neverHad;
  final VoidCallback onClearFilter;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.receipt_long_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              neverHad
                  ? 'Nenhum gasto lançado neste piquete'
                  : 'Nenhum gasto no período selecionado',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              neverHad
                  ? 'Lance o primeiro gasto deste piquete.'
                  : 'Tente ajustar os filtros.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
            if (!neverHad) ...[
              const SizedBox(height: 8),
              TextButton(
                onPressed: onClearFilter,
                child: const Text('Limpar filtro'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
