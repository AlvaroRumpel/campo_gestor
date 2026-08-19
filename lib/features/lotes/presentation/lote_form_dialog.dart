import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_repository.dart'
    show AnimalNumberConflictException;
import '../data/lote_model.dart';
import '../data/lote_repository.dart';

String _fmtUa(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Categorias visíveis por padrão no sheet de novo lote (spec 4.16);
/// touro/boi/novilho ficam atrás do expansor "Touros, Bois e Novilhos".
const _mainCategories = ['vaca', 'novilha', 'terneiro', 'terneira'];
const _extraCategories = ['touro', 'boi', 'novilho'];

/// Conteúdo de formulário (spec 4.16) exibido via [showAdaptiveForm]:
/// criação de lote com composição em lote (create mode) ou edição de nome
/// (edit mode, D-12).
///
/// Create mode: nome + steppers por categoria + raça + "Numerar a partir de"
/// + resumo live. Submit chama [LoteRepository.createLotWithAnimals].
///
/// Edit mode ([existing] != null): apenas nome. Submit chama
/// [LoteRepository.updateLotName].
class LoteFormDialog extends ConsumerStatefulWidget {
  const LoteFormDialog({
    super.key,
    required this.paddockId,
    required this.propertyId,
    this.existing,
  });

  final String paddockId;
  final String propertyId;

  /// When non-null: edit mode — only name is shown (D-12).
  final Lot? existing;

  @override
  ConsumerState<LoteFormDialog> createState() => _LoteFormDialogState();
}

class _LoteFormDialogState extends ConsumerState<LoteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _startNumCtrl;

  final Map<String, int> _qtys = {for (final c in kCategories) c: 0};
  final Map<String, String?> _breeds = {for (final c in kCategories) c: null};
  bool _saving = false;
  bool _extrasExpanded = false;
  int? _startNumber;

  bool get _isEditing => widget.existing != null;

  int get _totalAnimals => _qtys.values.fold(0, (a, b) => a + b);

  double get _totalUa => _qtys.entries
      .fold(0.0, (sum, e) => sum + e.value * (kUaWeights[e.key] ?? 0));

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _startNumCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startNumCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    if (!_isEditing) {
      if (_totalAnimals == 0) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Informe ao menos 1 animal para criar o lote'),
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);

    try {
      final repo = ref.read(loteRepositoryProvider);

      if (_isEditing) {
        await repo.updateLotName(
          id: widget.existing!.id,
          name: _nameCtrl.text.trim(),
        );
        ref.invalidatePropertyData();
        if (mounted) Navigator.pop(context, true);
        return;
      }

      // Parse optional start number
      final startNumText = _startNumCtrl.text.trim();
      int? startNum;
      if (startNumText.isNotEmpty) {
        startNum = int.tryParse(startNumText);
        // Validation already covered by form validator — should always parse here
      }

      await repo.createLotWithAnimals(
        propertyId: widget.propertyId,
        paddockId: widget.paddockId,
        name: _nameCtrl.text.trim(),
        categoryQuantities: Map.fromEntries(
          _qtys.entries.where((e) => e.value > 0),
        ),
        categoryBreeds: {
          for (final cat in _qtys.keys.where((c) => _qtys[c]! > 0))
            cat: _breeds[cat],
        },
        startNumber: startNum,
      );

      ref.invalidatePropertyData();
      if (mounted) Navigator.pop(context, true);
    } on AnimalNumberConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível criar o lote. Verifique os dados e tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _submitLabel {
    if (_isEditing) return 'Salvar';
    if (_totalAnimals == 0) return 'Criar lote';
    return 'Criar lote e $_totalAnimals '
        '${_totalAnimals == 1 ? 'animal' : 'animais'}';
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(),
              ),
            Text(
              _isEditing ? 'Editar lote' : 'Novo lote',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome do lote *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nome do lote é obrigatório'
                          : null,
                    ),
                    if (!_isEditing) ...[
                      const SizedBox(height: 18),
                      const OverlineLabel('Composição'),
                      const SizedBox(height: 2),
                      const Text(
                        'quantidade e raça por categoria',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      for (final cat in _mainCategories)
                        _CategoryCompositionRow(
                          category: cat,
                          qty: _qtys[cat]!,
                          onQtyChanged: (v) => setState(() => _qtys[cat] = v),
                          breed: _breeds[cat],
                          onBreedChanged: (b) =>
                              setState(() => _breeds[cat] = b),
                        ),
                      InkWell(
                        key: const ValueKey('extras_expander'),
                        onTap: () => setState(
                            () => _extrasExpanded = !_extrasExpanded),
                        child: SizedBox(
                          height: 46,
                          child: Row(
                            children: [
                              Icon(
                                _extrasExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                size: 20,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Touros, Bois e Novilhos',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.primaryDarkText,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (_extrasExpanded)
                        for (final cat in _extraCategories)
                          _CategoryCompositionRow(
                            category: cat,
                            qty: _qtys[cat]!,
                            onQtyChanged: (v) =>
                                setState(() => _qtys[cat] = v),
                            breed: _breeds[cat],
                            onBreedChanged: (b) =>
                                setState(() => _breeds[cat] = b),
                          ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _startNumCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Numerar a partir de',
                          hintText: 'vazio = automático',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        onChanged: (v) => setState(
                          () => _startNumber = int.tryParse(v.trim()),
                        ),
                        validator: (v) {
                          if (v == null || v.trim().isEmpty) return null;
                          final parsed = int.tryParse(v.trim());
                          if (parsed == null || parsed <= 0) {
                            return 'Informe um número inteiro positivo';
                          }
                          return null;
                        },
                      ),
                    ],
                  ],
                ),
              ),
            ),
            if (!_isEditing) ...[
              const SizedBox(height: 12),
              _LiveSummary(
                totalAnimals: _totalAnimals,
                totalUa: _totalUa,
                startNumber: _startNumber,
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed:
                        _saving ? null : () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 16,
                  child: FilledButton(
                    key: const ValueKey('lote_submit'),
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(_submitLabel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rodapé de resumo live (spec 4.16): N animais | X UA no lote | numeração.
class _LiveSummary extends StatelessWidget {
  const _LiveSummary({
    required this.totalAnimals,
    required this.totalUa,
    required this.startNumber,
  });

  final int totalAnimals;
  final double totalUa;
  final int? startNumber;

  @override
  Widget build(BuildContext context) {
    final numbering = (startNumber != null && totalAnimals > 0)
        ? '#$startNumber–#${startNumber! + totalAnimals - 1}'
        : 'automática';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Expanded(
            child: _SummaryCol(
              value: '$totalAnimals',
              label: totalAnimals == 1 ? 'animal' : 'animais',
            ),
          ),
          Expanded(
            child: _SummaryCol(
              value: _fmtUa(totalUa),
              label: 'UA no lote',
            ),
          ),
          Expanded(
            child: _SummaryCol(
              value: numbering,
              label: 'numeração',
              valueSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryCol extends StatelessWidget {
  const _SummaryCol({
    required this.value,
    required this.label,
    this.valueSize = 17,
  });

  final String value;
  final String label;
  final double valueSize;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: monoStyle(
            size: valueSize,
            weight: valueSize >= 17 ? FontWeight.w700 : FontWeight.w600,
            color: AppColors.primaryDarkText,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

/// Linha de composição por categoria (spec 4.16, 56h):
/// label + stepper (− outline · display mono · + verde) + dropdown de raça.
class _CategoryCompositionRow extends StatefulWidget {
  const _CategoryCompositionRow({
    required this.category,
    required this.qty,
    required this.onQtyChanged,
    required this.breed,
    required this.onBreedChanged,
  });

  final String category;
  final int qty;
  final ValueChanged<int> onQtyChanged;
  final String? breed;
  final ValueChanged<String?> onBreedChanged;

  @override
  State<_CategoryCompositionRow> createState() =>
      _CategoryCompositionRowState();
}

class _CategoryCompositionRowState extends State<_CategoryCompositionRow> {
  late final TextEditingController _qtyCtrl =
      TextEditingController(text: '${widget.qty}');

  @override
  void dispose() {
    _qtyCtrl.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant _CategoryCompositionRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    final displayed = int.tryParse(_qtyCtrl.text) ?? 0;
    if (displayed != widget.qty) {
      final text = '${widget.qty}';
      _qtyCtrl.value = TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: text.length),
      );
    }
  }

  void _onTextChanged(String text) {
    if (text.isEmpty) {
      widget.onQtyChanged(0);
      return;
    }
    widget.onQtyChanged(int.parse(text));
  }

  @override
  Widget build(BuildContext context) {
    final zeroed = widget.qty == 0;
    return Container(
      constraints: const BoxConstraints(minHeight: 56),
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 78,
            child: Text(
              kCategoryLabelsPlural[widget.category]!,
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w500,
                color: zeroed ? AppColors.textTertiary : AppColors.ink,
              ),
            ),
          ),
          // Stepper − (outline)
          SizedBox(
            width: 44,
            height: 44,
            child: OutlinedButton(
              key: ValueKey('qty_dec_${widget.category}'),
              onPressed: widget.qty > 0
                  ? () => widget.onQtyChanged(widget.qty - 1)
                  : null,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(44, 44),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(11),
                ),
              ),
              child: const Icon(Icons.remove, size: 20),
            ),
          ),
          const SizedBox(width: 4),
          // Display editável (mono, bg #F1F4EC)
          SizedBox(
            width: 44,
            height: 44,
            child: TextField(
              key: ValueKey('qty_field_${widget.category}'),
              controller: _qtyCtrl,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: monoStyle(
                size: 17,
                weight: FontWeight.w700,
                color: zeroed ? AppColors.textTertiary : AppColors.ink,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3),
              ],
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor:
                    zeroed ? AppColors.surfaceSubtle : AppColors.surfaceVariant,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(11),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: _onTextChanged,
            ),
          ),
          const SizedBox(width: 4),
          // Stepper + (verde sólido; outline quando zerado)
          SizedBox(
            width: 44,
            height: 44,
            child: zeroed
                ? OutlinedButton(
                    key: ValueKey('qty_inc_${widget.category}'),
                    onPressed: () => widget.onQtyChanged(widget.qty + 1),
                    style: OutlinedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  )
                : FilledButton(
                    key: ValueKey('qty_inc_${widget.category}'),
                    onPressed: widget.qty < 999
                        ? () => widget.onQtyChanged(widget.qty + 1)
                        : null,
                    style: FilledButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(44, 44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: widget.breed,
              isExpanded: true,
              decoration: const InputDecoration(
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                isDense: true,
              ),
              hint: const Text('Raça'),
              items: [
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('—'),
                ),
                ...kBreeds.map(
                  (b) => DropdownMenuItem<String?>(
                    value: b,
                    child: Text(b),
                  ),
                ),
              ],
              onChanged: widget.onBreedChanged,
            ),
          ),
        ],
      ),
    );
  }
}
