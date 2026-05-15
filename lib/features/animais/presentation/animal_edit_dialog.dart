import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Dialog for editing editable animal fields: Raça, EC (estado corporal),
/// Observação. Número and Categoria are read-only display fields (ANIM-02).
///
/// Submit calls [AnimalRepository.updateAnimal]. On success invalidates
/// [animalByIdProvider] and [animalListByPropertyProvider], pops with true.
class AnimalEditDialog extends ConsumerStatefulWidget {
  const AnimalEditDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<AnimalEditDialog> createState() => _AnimalEditDialogState();
}

class _AnimalEditDialogState extends ConsumerState<AnimalEditDialog> {
  late String? _breed;
  late int? _ec;
  late final TextEditingController _obsCtrl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _breed = widget.animal.breed;
    _ec = widget.animal.bodyCondition;
    _obsCtrl = TextEditingController(
      text: widget.animal.observation ?? '',
    );
  }

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    try {
      final obsText = _obsCtrl.text.trim();
      await ref.read(animalRepositoryProvider).updateAnimal(
            id: widget.animal.id,
            breed: _breed,
            bodyCondition: _ec,
            observation: obsText.isEmpty ? null : obsText,
          );
      ref.invalidate(animalByIdProvider(widget.animal.id));
      ref.invalidate(animalListByPropertyProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar animal. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final categoryLabel =
        kCategoryLabels[widget.animal.category] ?? widget.animal.category;

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : const Text('Editar animal'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Read-only display rows
              _ReadOnlyRow(label: 'Número', value: '#${widget.animal.number}'),
              const SizedBox(height: 8),
              _ReadOnlyRow(label: 'Categoria', value: categoryLabel),
              const SizedBox(height: 16),
              // Raça dropdown
              DropdownButtonFormField<String?>(
                initialValue: _breed,
                decoration: const InputDecoration(
                  labelText: 'Raça',
                  border: OutlineInputBorder(),
                ),
                hint: const Text('Sem raça'),
                items: [
                  const DropdownMenuItem<String?>(
                    value: null,
                    child: Text('Sem raça'),
                  ),
                  ...kBreeds.map(
                    (b) => DropdownMenuItem<String?>(
                      value: b,
                      child: Text(b),
                    ),
                  ),
                ],
                onChanged: (v) => setState(() => _breed = v),
              ),
              const SizedBox(height: 16),
              // EC ChoiceChips
              Text('Estado corporal', style: theme.textTheme.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: List.generate(5, (i) {
                  final val = i + 1;
                  return ChoiceChip(
                    label: Text('$val'),
                    selected: _ec == val,
                    onSelected: (sel) =>
                        setState(() => _ec = sel ? val : null),
                    showCheckmark: false,
                  );
                }),
              ),
              const SizedBox(height: 16),
              // Observação
              TextFormField(
                controller: _obsCtrl,
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  border: OutlineInputBorder(),
                  hintText: 'Observações adicionais (opcional)',
                ),
                maxLines: 3,
                textInputAction: TextInputAction.newline,
              ),
            ],
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
              : const Text('Salvar'),
        ),
      ],
    );
  }
}

class _ReadOnlyRow extends StatelessWidget {
  const _ReadOnlyRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text(value, style: theme.textTheme.bodyMedium),
      ],
    );
  }
}
