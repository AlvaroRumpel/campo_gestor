import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../sanitario/data/sanitary_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

/// Create/edit dialog for a gasto (GAST-01, D-11, D-12). Mirrors
/// `DoseFormDialog`'s shell exactly: `AlertDialog` with a
/// `LinearProgressIndicator` title while saving, `SizedBox(width: 480)` +
/// `Form` + `SingleChildScrollView` content, inline error text, a
/// `TextButton`/`FilledButton` action pair.
///
/// There is no piquete field and no piquete selector — the route already
/// resolved [paddockId] (D-10). [expense] null means create mode; non-null
/// means edit mode (D-12).
class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.propertyId,
    required this.paddockId,
    this.expense,
  });

  final String propertyId;
  final String paddockId;
  final Expense? expense;

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  String? _category;
  late final TextEditingController _valorCtrl;
  late final TextEditingController _dataCtrl;
  late final TextEditingController _descricaoCtrl;
  late DateTime _data;
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.expense != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.expense;
    _category = existing?.category;
    _valorCtrl = TextEditingController(
      text: existing != null ? _fmtDouble(existing.amount) : '',
    );
    _data = existing?.expenseDate ?? DateTime.now();
    _dataCtrl = TextEditingController(text: _dateFmt.format(_data));
    _descricaoCtrl = TextEditingController(text: existing?.description ?? '');
  }

  @override
  void dispose() {
    _valorCtrl.dispose();
    _dataCtrl.dispose();
    _descricaoCtrl.dispose();
    super.dispose();
  }

  String _fmtDouble(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Parses pt-BR decimal input (comma -> period). Unparseable or blank
  /// input returns null — never coerced to zero (mirrors
  /// `DoseFormDialog._parseDouble`).
  double? _parseDouble(String v) {
    final normalized = v.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _data,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _data = picked;
        _dataCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final repo = ref.read(expenseRepositoryProvider);
      final amount = _parseDouble(_valorCtrl.text)!;
      final descricaoText = _descricaoCtrl.text.trim();
      final description = descricaoText.isEmpty ? null : descricaoText;

      if (_isEditing) {
        await repo.updateExpense(
          id: widget.expense!.id,
          category: _category!,
          amount: amount,
          expenseDate: _data,
          description: description,
        );
      } else {
        await repo.createExpense(
          propertyId: widget.propertyId,
          paddockId: widget.paddockId,
          category: _category!,
          amount: amount,
          expenseDate: _data,
          description: description,
        );
      }

      // Both providers invalidated — an edit can touch an archived expense
      // (edit affordance stays visible under "Mostrar excluídos"), so either
      // list may hold this row (mirrors `DoseFormDialog`'s dual invalidate).
      ref.invalidate(unifiedExpenseListByPaddockProvider(widget.paddockId));
      ref.invalidate(
        unifiedExpenseListWithDeletedByPaddockProvider(widget.paddockId),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Não foi possível salvar o gasto. Verifique os '
            'dados e tente novamente.';
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Text(_isEditing ? 'Editar gasto' : 'Novo gasto'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _category,
                  decoration: const InputDecoration(
                    labelText: 'Categoria *',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final c in kExpenseCategories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(kExpenseCategoryLabels[c]!),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) =>
                      v == null ? 'Selecione a categoria do gasto' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _valorCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Valor *',
                    border: OutlineInputBorder(),
                    prefixText: 'R\$ ',
                    hintText: 'Ex: 1.240,00',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Valor é obrigatório';
                    }
                    final parsed = _parseDouble(v);
                    if (parsed == null) {
                      return 'Valor é obrigatório';
                    }
                    if (parsed <= 0) {
                      return 'Valor deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dataCtrl,
                  readOnly: true,
                  decoration: InputDecoration(
                    labelText: 'Data *',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today),
                      onPressed: _pickDate,
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Data é obrigatória'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _descricaoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Descrição',
                    border: OutlineInputBorder(),
                    hintText: 'Opcional',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        if (_errorMessage != null)
          Text(
            _errorMessage!,
            style: TextStyle(color: theme.colorScheme.error, fontSize: 12),
          ),
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Salvar gasto'),
        ),
      ],
    );
  }
}

/// Delete-confirmation dialog (D-28) — the exact value and dd/MM date stay
/// inline in the title; Material 3 wraps a long title to multiple lines by
/// default, which is the required behaviour for a destructive confirmation
/// (never shortened to a generic question with the figures moved into the
/// body). Performs no write and no provider invalidation — the caller
/// (07-06) runs `ExpenseRepository.archiveExpense` and the two list
/// invalidations only after this resolves `true`.
Future<bool> confirmDeleteExpense(
  BuildContext context,
  Expense expense,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        'Excluir gasto de ${formatCurrencyBrl(expense.amount)} de '
        '${DateFormat('dd/MM').format(expense.expenseDate)}?',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
            foregroundColor: Theme.of(ctx).colorScheme.onError,
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
