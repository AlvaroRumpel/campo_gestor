import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/animal_constants.dart';
import '../data/animal_repository.dart';

/// Dialog for creating an individual animal in an existing lot.
///
/// Auto-fills the [Número] field by calling [AnimalRepository.generateAnimalNumber]
/// on init, but the user may overwrite it (D-07).
///
/// Submits via [AnimalRepository.createAnimal]. On [AnimalNumberConflictException]
/// shows the D-07 SnackBar. On success pops with `true`.
class AnimalFormDialog extends ConsumerStatefulWidget {
  const AnimalFormDialog({
    super.key,
    required this.lotId,
    required this.propertyId,
  });
  final String lotId;
  final String propertyId;

  @override
  ConsumerState<AnimalFormDialog> createState() => _AnimalFormDialogState();
}

class _AnimalFormDialogState extends ConsumerState<AnimalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  String? _breed;
  int? _bodyCondition;
  final _numberCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();
  bool _saving = false;
  bool _loadingNumber = true;

  @override
  void initState() {
    super.initState();
    _fetchAutoNumber();
  }

  Future<void> _fetchAutoNumber() async {
    try {
      final n = await ref
          .read(animalRepositoryProvider)
          .generateAnimalNumber(widget.propertyId);
      if (!mounted) return;
      setState(() {
        _numberCtrl.text = n.toString();
        _loadingNumber = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadingNumber = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível gerar o número automaticamente. Informe um número manualmente.',
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _numberCtrl.dispose();
    _observationCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_category == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione a categoria do animal')),
      );
      return;
    }
    final number = int.tryParse(_numberCtrl.text.trim());
    if (number == null || number <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Informe um número inteiro positivo')),
      );
      return;
    }
    setState(() => _saving = true);
    try {
      await ref.read(animalRepositoryProvider).createAnimal(
            propertyId: widget.propertyId,
            lotId: widget.lotId,
            category: _category!,
            number: number,
            breed: _breed,
            bodyCondition: _bodyCondition,
            observation: _observationCtrl.text.trim().isEmpty
                ? null
                : _observationCtrl.text.trim(),
          );
      ref.invalidate(animalListByLotProvider(widget.lotId));
      ref.invalidate(animalListByPropertyProvider);
      if (mounted) Navigator.pop(context, true);
    } on AnimalNumberConflictException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Erro ao salvar animal. Tente novamente.')),
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
          : const Text('Novo animal'),
      content: SizedBox(
        width: 400,
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
                    for (final c in kCategories)
                      DropdownMenuItem(
                        value: c,
                        child: Text(kCategoryLabels[c]!),
                      ),
                  ],
                  onChanged: (v) => setState(() => _category = v),
                  validator: (v) =>
                      v == null ? 'Selecione a categoria do animal' : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _numberCtrl,
                  decoration: InputDecoration(
                    labelText: 'Número *',
                    border: const OutlineInputBorder(),
                    hintText: _loadingNumber ? 'Carregando…' : 'Auto-gerado',
                  ),
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Informe o número';
                    }
                    final n = int.tryParse(v.trim());
                    if (n == null || n <= 0) {
                      return 'Informe um número inteiro positivo';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String?>(
                  initialValue: _breed,
                  decoration: const InputDecoration(
                    labelText: 'Raça',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('— Sem raça'),
                    ),
                    for (final b in kBreeds)
                      DropdownMenuItem<String?>(
                        value: b,
                        child: Text(b),
                      ),
                  ],
                  onChanged: (v) => setState(() => _breed = v),
                ),
                const SizedBox(height: 16),
                Text(
                  'Estado corporal',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    for (final n in const [1, 2, 3, 4, 5])
                      ChoiceChip(
                        label: SizedBox(
                          width: 28,
                          child: Center(child: Text('$n')),
                        ),
                        selected: _bodyCondition == n,
                        onSelected: (sel) =>
                            setState(() => _bodyCondition = sel ? n : null),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _observationCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Observação',
                    border: OutlineInputBorder(),
                  ),
                ),
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
              : const Text('Adicionar'),
        ),
      ],
    );
  }
}
