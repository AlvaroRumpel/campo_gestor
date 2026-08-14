import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
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
/// (D-13), and the single "Gasto" FAB (D-10), gated by
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
    final saved = await showAdaptiveForm<bool>(
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
    final saved = await showAdaptiveForm<bool>(
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

  /// G-07-2: un-archive a soft-deleted expense. No confirmation dialog —
  /// restoring is non-destructive, unlike `_deleteExpense`.
  Future<void> _restoreExpense(Expense expense) async {
    await ref.read(expenseRepositoryProvider).restoreExpense(expense.id);
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

  /// Legenda do período para o hero verde ("agosto 2026", "últimos 3 meses"…).
  String _periodDescription() {
    final now = DateTime.now();
    switch (_preset) {
      case ExpensePeriodPreset.mesAtual:
        return DateFormat('MMMM yyyy', 'pt_BR').format(now);
      case ExpensePeriodPreset.mesPassado:
        return DateFormat('MMMM yyyy', 'pt_BR')
            .format(DateTime(now.year, now.month - 1));
      case ExpensePeriodPreset.ultimos3Meses:
        return 'últimos 3 meses';
      case ExpensePeriodPreset.ano:
        return 'ano de ${now.year}';
      case ExpensePeriodPreset.personalizado:
        final r = _customRange;
        if (r == null) return 'personalizado';
        return '${_dateFmt.format(r.start)} – ${_dateFmt.format(r.end)}';
    }
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
        automaticallyImplyLeading: false,
        titleSpacing: 6,
        toolbarHeight: 48,
        title: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, size: 24),
              tooltip: 'Voltar',
              // Explicit back control: /gastos/:paddockId is a root-level
              // route that is also a deep-link target (D-08), so it can be
              // entered with no Navigator history at all. Falls back to this
              // paddock's detail screen.
              onPressed: () {
                if (context.canPop()) {
                  context.pop();
                  return;
                }
                context.go('/piquetes/${widget.paddockId}');
              },
            ),
            Expanded(
              child: Text(
                paddockName != null ? 'Gastos · $paddockName' : 'Gastos',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.onGreen,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: ErrorRetry(
            message:
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
            onRetry: () => _showDeleted
                ? ref.invalidate(
                    unifiedExpenseListWithDeletedByPaddockProvider(
                        widget.paddockId),
                  )
                : ref.invalidate(
                    unifiedExpenseListByPaddockProvider(widget.paddockId),
                  ),
          ),
        ),
        data: (items) => _buildBody(items, canManage, propertyId),
      ),
      floatingActionButton: canManage
          ? FloatingActionButton.extended(
              tooltip: 'Novo gasto',
              onPressed: propertyId.isEmpty
                  ? null
                  : () => _openCreateDialog(propertyId),
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Gasto'),
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
    final totalSubset = filtered
        .where(
          (i) => switch (i) {
            ManualExpenseItem(:final expense) => expense.deletedAt == null,
            SanitaryExpenseItem() => true,
          },
        )
        .toList();
    final total = totalAmount(totalSubset);
    final count = itemCount(totalSubset);

    return Column(
      children: [
        _buildHero(total, count),
        _buildFilterRow(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmpty(neverHad: items.isEmpty)
              : _buildList(filtered, totalSubset, total, canManage, propertyId),
        ),
      ],
    );
  }

  /// Hero verde colado no app bar: total mono 32/700 + "N lançamentos ·
  /// período" (spec 4.12). "R$ X por animal" foi omitido — não há contagem
  /// de animais por piquete disponível sem uma consulta extra.
  Widget _buildHero(double total, int count) {
    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatCurrencyBrl(total),
            style: monoStyle(
              size: 32,
              weight: FontWeight.w700,
              color: AppColors.onGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          Text(
            '${Intl.plural(
              count,
              zero: '$count lançamentos',
              one: '1 lançamento',
              other: '$count lançamentos',
              locale: 'pt_BR',
            )} · ${_periodDescription()}',
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.onGreenSecondary,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildFilterRow() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          for (final preset in ExpensePeriodPreset.values)
            if (preset != ExpensePeriodPreset.personalizado)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: _PeriodChip(
                  label: preset.label,
                  selected: _preset == preset,
                  onTap: () => setState(() {
                    _preset = preset;
                    _customRange = null;
                  }),
                ),
              ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _PeriodChip(
              label: _preset == ExpensePeriodPreset.personalizado &&
                      _customRange != null
                  ? '${_dateFmt.format(_customRange!.start)} - '
                        '${_dateFmt.format(_customRange!.end)}'
                  : ExpensePeriodPreset.personalizado.label,
              selected: _preset == ExpensePeriodPreset.personalizado,
              onTap: _pickCustomRange,
            ),
          ),
          const SizedBox(width: 4),
          DropdownButton<String?>(
            value: _categoryFilter,
            hint: const Text(
              'Todas as categorias',
              style: TextStyle(fontSize: 13.5),
            ),
            style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
            underline: const SizedBox(),
            icon: const Icon(Icons.expand_more, size: 18),
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
          const SizedBox(width: 14),
          const Text('Mostrar excluídos', style: TextStyle(fontSize: 13)),
          Switch(
            value: _showDeleted,
            onChanged: (v) => setState(() => _showDeleted = v),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty({required bool neverHad}) {
    return EmptyState(
      icon: Icons.receipt_long_outlined,
      title: neverHad
          ? 'Nenhum gasto lançado neste piquete'
          : 'Nenhum gasto no período selecionado',
      message: neverHad
          ? 'Lance o primeiro gasto deste piquete.'
          : 'Tente ajustar os filtros.',
      action: neverHad
          ? null
          : TextButton(
              onPressed: _clearFilter,
              child: const Text('Limpar filtro'),
            ),
    );
  }

  /// Card "POR CATEGORIA" (spec 4.12): barra empilhada h12 com as 3 maiores
  /// categorias do período + legenda com valores mono.
  Widget? _buildCategoryCard(List<ExpenseListItem> totalSubset, double total) {
    if (total <= 0) return null;
    final byCategory = <String, double>{};
    for (final item in totalSubset) {
      final key = categoryKeyOf(item);
      byCategory[key] = (byCategory[key] ?? 0) + amountOf(item);
    }
    final entries = byCategory.entries.where((e) => e.value > 0).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    if (entries.isEmpty) return null;

    const colors = [AppColors.primary, AppColors.greenMid, AppColors.accent];
    final top = entries.take(colors.length).toList();

    String labelOf(String key) => key == kSanitaryPseudoCategory
        ? kSanitaryPseudoCategoryLabel
        : (kExpenseCategoryLabels[key] ?? key);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(child: OverlineLabel('Por categoria')),
              if (_categoryFilter != null)
                TextButton(
                  onPressed: () => setState(() => _categoryFilter = null),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    minimumSize: const Size(0, 32),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  child: const Text('Ver tudo'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          StackedBar(
            segments: [
              for (var i = 0; i < top.length; i++)
                StackedBarSegment(top[i].value / total, colors[i]),
            ],
          ),
          const SizedBox(height: 10),
          for (var i = 0; i < top.length; i++)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: colors[i],
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      labelOf(top[i].key),
                      style: const TextStyle(fontSize: 12.5),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    formatCurrencyBrl(top[i].value),
                    style: monoStyle(size: 12.5, weight: FontWeight.w600),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // D-18 ceiling: the header total above sums client-side over this
  // already-loaded list. If this list ever becomes paginated, the total
  // silently becomes "total of this page" — upgrade to a server-side
  // SUM()/RPC at that point, not before.
  //
  // ponytail: the rows render as one Column inside a single scroll view (no
  // builder laziness) — fine for per-paddock, per-period volumes; switch to
  // slivers if a paddock ever accumulates thousands of rows in one period.
  Widget _buildList(
    List<ExpenseListItem> filtered,
    List<ExpenseListItem> totalSubset,
    double total,
    bool canManage,
    String propertyId,
  ) {
    final categoryCard = _buildCategoryCard(totalSubset, total);
    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 88),
      children: [
        if (categoryCard != null) ...[categoryCard, const SizedBox(height: 10)],
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final item in filtered)
                ExpenseListItemCard(
                  item: item,
                  canManage: canManage,
                  onTap: switch (item) {
                    ManualExpenseItem(:final expense) => () =>
                        _openEditDialog(propertyId, expense),
                    SanitaryExpenseItem(:final application) => () => context
                        .push(AppRoutes.aplicacaoDetail(application.id)),
                  },
                  onDelete: switch (item) {
                    ManualExpenseItem(:final expense) => () =>
                        _deleteExpense(expense),
                    SanitaryExpenseItem() => null,
                  },
                  // G-07-2: only a manual expense can be restored — a
                  // sanitary row is read-only here and is reversed from its
                  // own detail screen.
                  onRestore: switch (item) {
                    ManualExpenseItem(:final expense) => () =>
                        _restoreExpense(expense),
                    SanitaryExpenseItem() => null,
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Filter chip do período (spec 3.5): h36 r999, selecionado verde/texto bone,
/// não selecionado branco com borda.
class _PeriodChip extends StatelessWidget {
  const _PeriodChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.chipBorder),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
            color: selected ? AppColors.onGreen : AppColors.ink,
          ),
        ),
      ),
    );
  }
}
