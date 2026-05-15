import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_repository.dart' show AnimalNumberConflictException;
import '../data/lote_model.dart';
import '../data/lote_repository.dart';

/// Dialog for creating a lot with batch animal composition (create mode)
/// or editing a lot name (edit mode, D-12).
///
/// Create mode: shows name field + 7 category composition rows + optional
/// "Iniciar do número" field. Submit calls [LoteRepository.createLotWithAnimals].
///
/// Edit mode ([existing] != null): shows name field only. Submit calls
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

  bool get _isEditing => widget.existing != null;

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
      final total = _qtys.values.fold(0, (a, b) => a + b);
      if (total == 0) {
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
        ref.invalidate(loteListByPaddockProvider(widget.paddockId));
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

      ref.invalidate(loteListByPaddockProvider(widget.paddockId));
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

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Text(_isEditing ? 'Editar lote' : 'Novo lote'),
      content: SizedBox(
        width: 480,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nome do lote *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nome do lote é obrigatório'
                      : null,
                ),
                if (!_isEditing) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Animais por categoria',
                    style: theme.textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  ...kCategories.map(
                    (cat) => _CategoryCompositionRow(
                      category: cat,
                      qty: _qtys[cat]!,
                      onQtyChanged: (v) => setState(() => _qtys[cat] = v),
                      breed: _breeds[cat],
                      onBreedChanged: (b) =>
                          setState(() => _breeds[cat] = b),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _startNumCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Iniciar do número',
                      border: OutlineInputBorder(),
                      hintText: 'Ex: 101 (deixe vazio para auto)',
                    ),
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
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
      ),
      actions: [
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
              : Text(_isEditing ? 'Salvar' : 'Criar lote'),
        ),
      ],
    );
  }
}

/// One row in the batch composition grid.
///
/// Layout: [CategoryLabel] [Decrement] [QtyDisplay] [Increment] [BreedDropdown]
class _CategoryCompositionRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(kCategoryLabelsPlural[category]!),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: qty > 0 ? () => onQtyChanged(qty - 1) : null,
            icon: const Icon(Icons.remove),
          ),
          SizedBox(
            width: 32,
            child: Text(
              '$qty',
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
            onPressed: qty < 999 ? () => onQtyChanged(qty + 1) : null,
            icon: const Icon(Icons.add),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: DropdownButtonFormField<String?>(
              initialValue: breed,
              isExpanded: true,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                isDense: true,
              ),
              hint: const Text('Raça (opcional)'),
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
              onChanged: onBreedChanged,
            ),
          ),
        ],
      ),
    );
  }
}
