import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../dashboard/data/dashboard_providers.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/expense_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';
import 'expense_form_dialog.dart';
import '_expense_list_item_card.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');
final _monthFmt = DateFormat('MMM', 'pt_BR');

// Larguras de coluna declaradas uma vez, reusadas pelo cabeçalho e pelas
// linhas — molde `sanitario_table_views.dart`.
const _kColData = 96.0;
const _kColCategoria = 168.0;
const _kFlexDescricao = 3;
const _kFlexPiquete = 2;
const _kColValor = 116.0;
const _kColAcao = 44.0;
const _kDash = '—';

/// Rota global `/gastos` (6a branch do shell, reversão da decisão da Fase 7
/// registrada em `routes.dart`, aprovada pelo usuário em 2026-08-13): visão
/// consolidada da propriedade inteira, ao contrário de `GastosScreen`
/// (`/gastos/:paddockId`), que continua existindo por piquete.
///
/// Molde de composição (>= [Breakpoints.rail]): `sanitario_screen.dart`
/// (LayoutBuilder + `CampoAppBar` nas duas faixas + header desktop próprio)
/// e `sanitario_table_views.dart` (larguras de coluna e `_HeaderText`).
class GastosPropertyScreen extends ConsumerStatefulWidget {
  const GastosPropertyScreen({super.key});

  @override
  ConsumerState<GastosPropertyScreen> createState() =>
      _GastosPropertyScreenState();
}

class _GastosPropertyScreenState extends ConsumerState<GastosPropertyScreen> {
  // Nunca persistido — toda entrada na tela começa no mês atual (mirrors
  // GastosScreen). `personalizado` não é oferecido aqui (planner note): o
  // date-range picker não se paga nesta tela, o fluxo por piquete continua
  // tendo o intervalo livre.
  ExpensePeriodPreset _preset = ExpensePeriodPreset.mesAtual;

  void _invalidate() {
    ref.invalidate(unifiedExpenseListByPropertyProvider);
  }

  Future<void> _openNewExpenseFlow(String propertyId) async {
    final paddocks =
        ref.read(paddockListProvider).asData?.value ?? const <Paddock>[];
    final paddockId = await showAdaptiveForm<String>(
      context: context,
      builder: (_) => _PaddockPickerSheet(paddocks: paddocks),
    );
    if (paddockId == null || !mounted) return;
    final saved = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) =>
          ExpenseFormDialog(propertyId: propertyId, paddockId: paddockId),
    );
    if (saved != true || !mounted) return;
    _invalidate();
  }

  Future<void> _openEditDialog(String propertyId, Expense expense) async {
    final saved = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => ExpenseFormDialog(
        propertyId: propertyId,
        paddockId: expense.paddockId,
        expense: expense,
      ),
    );
    if (saved != true || !mounted) return;
    _invalidate();
  }

  Future<void> _deleteExpense(Expense expense) async {
    final confirmed = await confirmDeleteExpense(context, expense);
    if (!confirmed || !mounted) return;
    await ref.read(expenseRepositoryProvider).archiveExpense(expense.id);
    if (!mounted) return;
    _invalidate();
  }

  @override
  Widget build(BuildContext context) {
    final itemsAsync = ref.watch(unifiedExpenseListByPropertyProvider);
    final paddocks = ref.watch(paddockListProvider).asData?.value ?? const [];
    final paddockMap = {for (final p in paddocks) p.id: p.name};
    final totalUa = ref.watch(dashboardKpisProvider).asData?.value.totalUa;
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canManage = canManageExpenses(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );
    final propertyId = currentPropAsync.asData?.value?.id ?? '';

    return Scaffold(
      appBar: const CampoAppBar(title: 'Gastos'),
      body: itemsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, st) => Center(
          child: ErrorRetry(
            message:
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
            onRetry: () =>
                ref.invalidate(unifiedExpenseListByPropertyProvider),
          ),
        ),
        data: (items) => LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= Breakpoints.rail;
            return isDesktop
                ? _buildDesktop(items, paddockMap, totalUa, canManage, propertyId)
                : _buildMobile(items, canManage, propertyId);
          },
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Desktop (>=Breakpoints.rail)
  // ---------------------------------------------------------------------

  Widget _buildDesktop(
    List<ExpenseListItem> items,
    Map<String, String> paddockMap,
    double? totalUa,
    bool canManage,
    String propertyId,
  ) {
    final periodItems =
        filterByDateRange(items, rangeForPreset(_preset, DateTime.now()));
    final total = totalAmount(periodItems);
    final count = itemCount(periodItems);

    return Column(
      children: [
        _buildDesktopHeader(canManage, propertyId, count, total),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          child: Row(
            children: [
              for (final preset in ExpensePeriodPreset.values)
                if (preset != ExpensePeriodPreset.personalizado) ...[
                  _PeriodChip(
                    label: preset.label,
                    selected: _preset == preset,
                    onTap: () => setState(() => _preset = preset),
                  ),
                  const SizedBox(width: 8),
                ],
            ],
          ),
        ),
        Expanded(
          child: DecoratedBox(
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: AppColors.divider)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ColoredBox(
                    color: AppColors.surface,
                    child: periodItems.isEmpty
                        ? const EmptyState(
                            icon: Icons.receipt_long_outlined,
                            title: 'Nenhum gasto no período selecionado',
                            message: 'Tente ajustar o período.',
                          )
                        : _buildTable(
                            periodItems,
                            count,
                            total,
                            paddockMap,
                            canManage,
                            propertyId,
                          ),
                  ),
                ),
                _buildPanel(items, totalUa),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopHeader(
    bool canManage,
    String propertyId,
    int count,
    double total,
  ) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Gastos',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  '${_countLabel(count)} · ${formatCurrencyBrl(total)}',
                  style: monoStyle(size: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (canManage && propertyId.isNotEmpty) ...[
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed: () => _openNewExpenseFlow(propertyId),
              icon: const Icon(Icons.add, size: 20),
              label: const Text('Novo gasto'),
            ),
          ],
        ],
      ),
    );
  }

  String _countLabel(int count) => Intl.plural(
        count,
        zero: '$count lançamentos',
        one: '1 lançamento',
        other: '$count lançamentos',
        locale: 'pt_BR',
      );

  Widget _buildPeriodDropdown() {
    return DropdownButton<ExpensePeriodPreset>(
      value: _preset,
      underline: const SizedBox(),
      style: const TextStyle(fontSize: 13.5, color: AppColors.ink),
      icon: const Icon(Icons.expand_more, size: 18),
      items: [
        for (final preset in ExpensePeriodPreset.values)
          if (preset != ExpensePeriodPreset.personalizado)
            DropdownMenuItem(value: preset, child: Text(preset.label)),
      ],
      onChanged: (v) {
        if (v != null) setState(() => _preset = v);
      },
    );
  }

  Widget _buildTable(
    List<ExpenseListItem> periodItems,
    int count,
    double total,
    Map<String, String> paddockMap,
    bool canManage,
    String propertyId,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildTableHeader(),
        Expanded(
          child: ListView.builder(
            itemCount: periodItems.length,
            itemBuilder: (context, i) => _buildTableRow(
              periodItems[i],
              paddockMap,
              canManage,
              propertyId,
            ),
          ),
        ),
        _buildTableFooter(count, total),
      ],
    );
  }

  Widget _buildTableHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.surfaceVariant,
      child: const Row(
        children: [
          SizedBox(width: _kColData, child: _HeaderText('DATA')),
          SizedBox(width: _kColCategoria, child: _HeaderText('CATEGORIA')),
          Expanded(flex: _kFlexDescricao, child: _HeaderText('DESCRIÇÃO')),
          Expanded(flex: _kFlexPiquete, child: _HeaderText('PIQUETE')),
          SizedBox(
            width: _kColValor,
            child: _HeaderText('VALOR', align: TextAlign.right),
          ),
          SizedBox(width: _kColAcao),
        ],
      ),
    );
  }

  Widget _buildTableFooter(int count, double total) {
    return Container(
      constraints: const BoxConstraints(minHeight: 34),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      color: AppColors.surfaceVariant,
      alignment: Alignment.centerRight,
      child: Text(
        '${_countLabel(count)} · ${formatCurrencyBrl(total)}',
        style: monoStyle(size: 11.5, color: AppColors.textSecondary),
      ),
    );
  }

  Widget _buildTableRow(
    ExpenseListItem item,
    Map<String, String> paddockMap,
    bool canManage,
    String propertyId,
  ) {
    final label = _categoryLabel(item);
    final description = switch (item) {
      ManualExpenseItem(:final expense) =>
        (expense.description != null && expense.description!.isNotEmpty)
            ? expense.description!
            : _kDash,
      SanitaryExpenseItem(:final application) => application.doseName,
    };
    final paddockName = switch (item) {
      ManualExpenseItem(:final expense) =>
        paddockMap[expense.paddockId] ?? _kDash,
      SanitaryExpenseItem(:final application) => application.paddockName,
    };
    final valueText = switch (item) {
      ManualExpenseItem(:final expense) => formatCurrencyBrl(expense.amount),
      SanitaryExpenseItem(:final application) => application.totalCost != null
          ? formatCurrencyBrl(application.totalCost!.abs())
          : _kDash,
    };
    final onTap = switch (item) {
      ManualExpenseItem(:final expense) => () =>
          _openEditDialog(propertyId, expense),
      SanitaryExpenseItem(:final application) => () =>
          context.push(AppRoutes.aplicacaoDetail(application.id)),
    };
    final Widget deleteAction = switch (item) {
      ManualExpenseItem(:final expense) when canManage => IconButton(
          icon: const Icon(Icons.delete_outline, size: 18),
          tooltip: 'Excluir gasto',
          onPressed: () => _deleteExpense(expense),
        ),
      _ => const SizedBox.shrink(),
    };

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kColData,
            child: Text(
              _dateFmt.format(dateOf(item)),
              style: monoStyle(size: 12),
            ),
          ),
          SizedBox(
            width: _kColCategoria,
            child: Text(label, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexDescricao,
            child: Text(description, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexPiquete,
            child: Text(paddockName, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: _kColValor,
            child: Text(
              valueText,
              textAlign: TextAlign.right,
              style: monoStyle(size: 13, weight: FontWeight.w600),
            ),
          ),
          SizedBox(width: _kColAcao, child: deleteAction),
        ],
      ),
    );

    return InkWell(hoverColor: AppColors.rowHover, onTap: onTap, child: row);
  }

  String _categoryLabel(ExpenseListItem item) {
    final key = categoryKeyOf(item);
    return key == kSanitaryPseudoCategory
        ? kSanitaryPseudoCategoryLabel
        : (kExpenseCategoryLabels[key] ?? key);
  }

  // ---------------------------------------------------------------------
  // Painel direito ancorado (380px) — molde LoteDetailPanel/AnimalDetailPanel.
  // Fundo `background` (osso), não `surface`: o conteúdo é uma pilha de
  // SectionCard brancos, que sobre branco perde a definição.
  // ---------------------------------------------------------------------

  Widget _buildPanel(List<ExpenseListItem> allItems, double? totalUa) {
    final now = DateTime.now();
    final monthItems = filterByDateRange(allItems, currentMonthRange(now));
    final monthTotal = totalAmount(monthItems);
    final categoryCard = _buildCategoryCard(monthItems);

    return Container(
      key: const ValueKey('gastos-painel'),
      width: 380,
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(left: BorderSide(color: AppColors.divider)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineLabel('Total do mês'),
                  const SizedBox(height: 6),
                  Text(
                    formatCurrencyBrl(monthTotal),
                    style: monoStyle(size: 28, weight: FontWeight.w700),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            SectionCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const OverlineLabel('R\$/UA'),
                  const SizedBox(height: 6),
                  Text(
                    (totalUa == null || totalUa <= 0)
                        ? _kDash
                        : formatCurrencyBrl(monthTotal / totalUa),
                    style: monoStyle(
                      size: 22,
                      weight: FontWeight.w700,
                      color: AppColors.primaryDarkText,
                    ),
                  ),
                ],
              ),
            ),
            if (categoryCard != null) ...[
              const SizedBox(height: 10),
              categoryCard,
            ],
            const SizedBox(height: 10),
            _buildMonthsCard(allItems, now),
          ],
        ),
      ),
    );
  }

  /// "POR CATEGORIA" — top 3 categorias do mês corrente (independente do
  /// preset, mesma base de dados que o bloco "Total do mês").
  Widget? _buildCategoryCard(List<ExpenseListItem> monthItems) {
    final total = totalAmount(monthItems);
    if (total <= 0) return null;
    final byCategory = <String, double>{};
    for (final item in monthItems) {
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
          const OverlineLabel('Por categoria'),
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

  /// "ÚLTIMOS 6 MESES" — sempre sobre a lista COMPLETA (não a filtrada pelo
  /// preset selecionado): zero query nova, agregação client-side via
  /// [lastMonthsTotals].
  Widget _buildMonthsCard(List<ExpenseListItem> allItems, DateTime now) {
    final months = lastMonthsTotals(allItems, now);
    final maxTotal =
        months.fold<double>(0, (m, t) => t.total > m ? t.total : m);

    return SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const OverlineLabel('Últimos 6 meses'),
          const SizedBox(height: 10),
          for (final m in months)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 32,
                    child: Text(
                      _monthFmt.format(DateTime(m.year, m.month)),
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: StackedBar(
                      height: 8,
                      segments: [
                        if (maxTotal > 0)
                          StackedBarSegment(
                            m.total / maxTotal,
                            AppColors.primary,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  SizedBox(
                    width: 68,
                    child: Text(
                      formatCurrencyBrl(m.total),
                      textAlign: TextAlign.right,
                      style: monoStyle(size: 11.5),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // Mobile (<Breakpoints.rail)
  // ---------------------------------------------------------------------

  Widget _buildMobile(
    List<ExpenseListItem> items,
    bool canManage,
    String propertyId,
  ) {
    final periodItems =
        filterByDateRange(items, rangeForPreset(_preset, DateTime.now()));

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Align(
            alignment: Alignment.centerLeft,
            child: _buildPeriodDropdown(),
          ),
        ),
        Expanded(
          child: periodItems.isEmpty
              ? const EmptyState(
                  icon: Icons.receipt_long_outlined,
                  title: 'Nenhum gasto no período selecionado',
                  message: 'Tente ajustar o período.',
                )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 20),
                  itemCount: periodItems.length,
                  itemBuilder: (context, i) {
                    final item = periodItems[i];
                    return ExpenseListItemCard(
                      item: item,
                      canManage: canManage,
                      onTap: switch (item) {
                        ManualExpenseItem(:final expense) => () =>
                            _openEditDialog(propertyId, expense),
                        SanitaryExpenseItem(:final application) => () =>
                            context.push(
                              AppRoutes.aplicacaoDetail(application.id),
                            ),
                      },
                      onDelete: switch (item) {
                        ManualExpenseItem(:final expense) => () =>
                            _deleteExpense(expense),
                        SanitaryExpenseItem() => null,
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

/// Passo 1 do fluxo "Novo gasto": `ExpenseFormDialog` exige `paddockId` e não
/// tem seletor próprio (D-10 da Fase 7); esta folha escolhe o piquete antes
/// de abrir o diálogo existente, sem alterar sua assinatura.
class _PaddockPickerSheet extends StatelessWidget {
  const _PaddockPickerSheet({required this.paddocks});

  final List<Paddock> paddocks;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 18, 20, 8),
            child: Text(
              'Em qual piquete?',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final p in paddocks)
                  ListTile(
                    title: Text(p.name),
                    onTap: () => Navigator.pop(context, p.id),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

/// Texto de coluna do cabeçalho: mono 10.5px w700, letterSpacing 0.8 —
/// idêntico a `sanitario_table_views.dart`/`animais_table_view.dart`.
class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.align = TextAlign.left});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.primaryDarkText,
      ),
    );
  }
}

/// Chip de filtro de período — clone visual de `_ScopeChip`
/// (`animais_table_view.dart`), o "padrão das outras abas" real.
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
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.positiveChipBg : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.chipBorder),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.primaryDarkText : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}
