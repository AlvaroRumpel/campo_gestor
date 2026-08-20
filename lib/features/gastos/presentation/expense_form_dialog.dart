import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/expense_constants.dart';
import '../data/expense_model.dart';
import '../data/expense_repository.dart';

/// As 5 categorias mostradas de cara como chips (spec 4.18); as demais ficam
/// atrás do chip "Mais N".
const List<String> _kPrimaryCategories = <String>[
  'racao_suplementacao',
  'mao_de_obra',
  'manutencao',
  'pastagem_adubacao',
  'combustivel',
];

/// Create/edit form for a gasto (GAST-01, D-11, D-12), shown via
/// `showAdaptiveForm` (bottom sheet <600px / dialog 480px, spec 4.18):
/// CATEGORIA como chips h40 r999 com ícone 18, VALOR com prefixo "R$" mono e
/// valor mono 30/700, DATA com calendar, DESCRIÇÃO, rodapé Cancelar +
/// "Salvar gasto" (flex 1 / 1.4).
///
/// There is no piquete field and no piquete selector — the route already
/// resolved [paddockId] (D-10). [expense] null means create mode; non-null
/// means edit mode (D-12).
class ExpenseFormDialog extends ConsumerStatefulWidget {
  const ExpenseFormDialog({
    super.key,
    required this.propertyId,
    this.paddockId,
    this.expense,
  });

  final String propertyId;
  final String? paddockId;
  final Expense? expense;

  @override
  ConsumerState<ExpenseFormDialog> createState() => _ExpenseFormDialogState();
}

class _ExpenseFormDialogState extends ConsumerState<ExpenseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  String? _category;
  late bool _showAllCategories;
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
    // Editing an expense whose category lives behind "Mais N" must show its
    // chip selected, not hidden.
    _showAllCategories =
        _category != null && !_kPrimaryCategories.contains(_category);
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

      ref.invalidatePropertyData();
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

  Widget _categoryField() {
    final hidden = kExpenseCategories
        .where((c) => !_kPrimaryCategories.contains(c))
        .toList();
    final visible = [
      ..._kPrimaryCategories,
      if (_showAllCategories) ...hidden,
    ];
    return FormField<String>(
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: (_) =>
          _category == null ? 'Selecione a categoria do gasto' : null,
      builder: (state) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const OverlineLabel('Categoria *'),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final c in visible)
                _CategoryChip(
                  label: kExpenseCategoryLabels[c] ?? c,
                  icon: kExpenseCategoryIcons[c] ?? Icons.more_horiz,
                  selected: _category == c,
                  onTap: () {
                    setState(() => _category = c);
                    state.didChange(c);
                  },
                ),
              if (!_showAllCategories)
                _CategoryChip(
                  label: 'Mais ${hidden.length}',
                  icon: Icons.more_horiz,
                  selected: false,
                  onTap: () => setState(() => _showAllCategories = true),
                ),
            ],
          ),
          if (state.hasError)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                state.errorText!,
                style:
                    const TextStyle(fontSize: 12, color: AppColors.danger),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
              ],
              Text(
                _isEditing ? 'Editar gasto' : 'Novo gasto',
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _categoryField(),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _valorCtrl,
                        style: monoStyle(size: 30, weight: FontWeight.w700),
                        decoration: InputDecoration(
                          labelText: 'Valor *',
                          prefixText: 'R\$ ',
                          prefixStyle: monoStyle(
                            size: 16,
                            color: AppColors.textSecondary,
                          ),
                          hintText: 'Ex: 1.240,00',
                          hintStyle: monoStyle(
                            size: 30,
                            weight: FontWeight.w700,
                            color: AppColors.textTertiary,
                          ),
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
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _dataCtrl,
                        readOnly: true,
                        style: monoStyle(size: 15.5, weight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Data *',
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.calendar_today, size: 22),
                            onPressed: _pickDate,
                          ),
                        ),
                        onTap: _pickDate,
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Data é obrigatória'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _descricaoCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Descrição',
                          hintText: 'Opcional',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_errorMessage != null) ...[
                const SizedBox(height: 10),
                Text(
                  _errorMessage!,
                  style:
                      const TextStyle(fontSize: 12, color: AppColors.danger),
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: OutlinedButton(
                      onPressed: _saving
                          ? null
                          : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: const Text('Cancelar'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 14,
                    child: FilledButton(
                      onPressed: _saving ? null : _submit,
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(54),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Salvar gasto'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chip de categoria h40 r999 com ícone 18 (spec 4.18).
class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 13),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: selected ? null : Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 18,
              color: selected ? AppColors.onGreen : AppColors.textSecondary,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: selected ? AppColors.onGreen : AppColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Delete-confirmation dialog (D-28, spec 4.19) — ícone-container 38 r11
/// `#FDECE7` + `delete` `#A32D14`, o valor exato e a data dd/MM ficam no
/// título (Material 3 wraps a long title by default — never shortened to a
/// generic question with the figures moved into the body), corpo sobre
/// restauração, Cancelar outline + "Excluir" destrutivo. Performs no write
/// and no provider invalidation — the caller runs
/// `ExpenseRepository.archiveExpense` only after this resolves `true`.
Future<bool> confirmDeleteExpense(
  BuildContext context,
  Expense expense,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.dangerContainer,
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.delete_outline,
              size: 21,
              color: AppColors.danger,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Excluir gasto de ${formatCurrencyBrl(expense.amount)} de '
              '${DateFormat('dd/MM').format(expense.expenseDate)}?',
            ),
          ),
        ],
      ),
      content: const Text(
        "O lançamento sai do total do período, mas continua visível em "
        "'Mostrar excluídos' e pode ser restaurado.",
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onDanger,
          ),
          child: const Text('Excluir'),
        ),
      ],
    ),
  );
  return confirmed ?? false;
}
