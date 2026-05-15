import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Dialog for registering baixa (soft-delete with reason and date) on an animal
/// (ANIM-04, D-17).
///
/// Renders:
/// - Explanation text (italic)
/// - SegmentedButton(BaixaReason) with Venda / Morte / Descarte
/// - Data da baixa field (read-only, date picker via suffix icon)
/// - Observação multi-line (optional)
///
/// Submit calls [AnimalRepository.registerBaixa]. On success invalidates
/// [animalByIdProvider] and [animalListByPropertyProvider], pops with true.
class BaixaDialog extends ConsumerStatefulWidget {
  const BaixaDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<BaixaDialog> createState() => _BaixaDialogState();
}

class _BaixaDialogState extends ConsumerState<BaixaDialog> {
  BaixaReason? _reason;
  DateTime _date = DateTime.now();
  final _obsCtrl = TextEditingController();
  bool _saving = false;
  // dd/MM/yyyy pattern doesn't need locale symbol data — safe to create eagerly.
  final _dateFmt = DateFormat('dd/MM/yyyy');

  @override
  void dispose() {
    _obsCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _date = picked);
    }
  }

  Future<void> _submit() async {
    if (_reason == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o motivo da baixa')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final obsText = _obsCtrl.text.trim();
      await ref.read(animalRepositoryProvider).registerBaixa(
            id: widget.animal.id,
            reason: _reason!,
            date: _date,
            observation: obsText.isEmpty ? null : obsText,
          );
      ref.invalidate(animalByIdProvider(widget.animal.id));
      ref.invalidate(animalListByPropertyProvider);
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao registrar baixa. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Text('Confirmar baixa do animal #${widget.animal.number}?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Esta ação registra o animal como arquivado. O histórico é preservado.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              // Reason segmented button
              SegmentedButton<BaixaReason>(
                segments: [
                  for (final r in BaixaReason.values)
                    ButtonSegment<BaixaReason>(
                      value: r,
                      label: Text(r.label),
                    ),
                ],
                selected:
                    _reason == null ? <BaixaReason>{} : {_reason!},
                onSelectionChanged: (s) =>
                    setState(() => _reason = s.firstOrNull),
                emptySelectionAllowed: true,
                showSelectedIcon: false,
              ),
              const SizedBox(height: 16),
              // Date field
              TextFormField(
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Data da baixa',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ),
                controller: TextEditingController(
                  text: _dateFmt.format(_date),
                ),
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
          style: FilledButton.styleFrom(
            backgroundColor: colorScheme.error,
            foregroundColor: colorScheme.onError,
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar baixa'),
        ),
      ],
    );
  }
}
