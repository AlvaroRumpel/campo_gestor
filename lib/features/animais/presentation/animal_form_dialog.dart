import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/animal_constants.dart';
import '../data/animal_repository.dart';

/// Formulário de criação de animal — conteúdo para [showAdaptiveForm]
/// (bottom sheet <600px / dialog 480px).
///
/// Auto-preenche o Número via [AnimalRepository.generateAnimalNumber] (D-07),
/// mas o usuário pode sobrescrever. Quando [lotId] é null (FAB da lista de
/// animais), mostra um seletor de lote obrigatório; quando vem preenchido
/// (ficha do lote), o lote é fixo e o campo não aparece.
///
/// Submete via [AnimalRepository.createAnimal]. Em
/// [AnimalNumberConflictException] mostra o SnackBar D-07. Em sucesso faz pop
/// com `true`.
class AnimalFormDialog extends ConsumerStatefulWidget {
  const AnimalFormDialog({
    super.key,
    this.lotId,
    required this.propertyId,
  });
  final String? lotId;
  final String propertyId;

  @override
  ConsumerState<AnimalFormDialog> createState() => _AnimalFormDialogState();
}

class _AnimalFormDialogState extends ConsumerState<AnimalFormDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _category;
  String? _breed;
  int? _bodyCondition;
  String? _selectedLotId;
  final _numberCtrl = TextEditingController();
  final _observationCtrl = TextEditingController();
  bool _saving = false;
  bool _loadingNumber = true;

  @override
  void initState() {
    super.initState();
    _selectedLotId = widget.lotId;
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
    final lotId = _selectedLotId;
    if (lotId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione o lote do animal')),
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
            lotId: lotId,
            category: _category!,
            number: number,
            breed: _breed,
            bodyCondition: _bodyCondition,
            observation: _observationCtrl.text.trim().isEmpty
                ? null
                : _observationCtrl.text.trim(),
          );
      ref.invalidate(animalListByLotProvider(lotId));
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
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                'Novo animal',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              Flexible(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (widget.lotId == null) ...[
                        _LotDropdown(
                          value: _selectedLotId,
                          onChanged: (v) =>
                              setState(() => _selectedLotId = v),
                        ),
                        const SizedBox(height: 14),
                      ],
                      DropdownButtonFormField<String>(
                        initialValue: _category,
                        decoration: const InputDecoration(
                          labelText: 'Categoria *',
                        ),
                        items: [
                          for (final c in kCategories)
                            DropdownMenuItem(
                              value: c,
                              child: Text(kCategoryLabels[c]!),
                            ),
                        ],
                        onChanged: (v) => setState(() => _category = v),
                        validator: (v) => v == null
                            ? 'Selecione a categoria do animal'
                            : null,
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _numberCtrl,
                        style: monoStyle(size: 15.5, weight: FontWeight.w600),
                        decoration: InputDecoration(
                          labelText: 'Número *',
                          hintText:
                              _loadingNumber ? 'Carregando…' : 'Auto-gerado',
                        ),
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly
                        ],
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
                      const SizedBox(height: 14),
                      DropdownButtonFormField<String?>(
                        initialValue: _breed,
                        decoration: const InputDecoration(labelText: 'Raça'),
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
                      const SizedBox(height: 14),
                      const Text(
                        'ESTADO CORPORAL',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          for (final n in const [1, 2, 3, 4, 5])
                            ChoiceChip(
                              label: SizedBox(
                                width: 28,
                                child: Center(
                                  child: Text(
                                    '$n',
                                    style: monoStyle(
                                      size: 14,
                                      weight: FontWeight.w600,
                                      color: _bodyCondition == n
                                          ? AppColors.onGreen
                                          : AppColors.ink,
                                    ),
                                  ),
                                ),
                              ),
                              selected: _bodyCondition == n,
                              onSelected: (sel) => setState(
                                  () => _bodyCondition = sel ? n : null),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      TextFormField(
                        controller: _observationCtrl,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Observação',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 18),
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
                            borderRadius: BorderRadius.circular(14)),
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
                        minimumSize: const Size(0, 52),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14)),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child:
                                  CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Adicionar'),
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

/// Seletor de lote (obrigatório quando o formulário abre sem lote fixo).
class _LotDropdown extends ConsumerWidget {
  const _LotDropdown({required this.value, required this.onChanged});

  final String? value;
  final ValueChanged<String?> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotsAsync = ref.watch(loteListByPropertyProvider);
    final lots = lotsAsync.asData?.value ?? const [];
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(labelText: 'Lote *'),
      items: [
        for (final lot in lots)
          DropdownMenuItem(value: lot.id, child: Text(lot.name)),
      ],
      onChanged: onChanged,
      validator: (v) => v == null ? 'Selecione o lote do animal' : null,
    );
  }
}
