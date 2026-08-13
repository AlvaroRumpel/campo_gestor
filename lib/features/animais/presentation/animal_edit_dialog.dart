import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Formulário de edição do animal — conteúdo para [showAdaptiveForm].
/// Editáveis: Raça, EC (estado corporal), Observação. Número e Categoria são
/// linhas travadas somente-leitura (ANIM-02).
///
/// Submit chama [AnimalRepository.updateAnimal]. Em sucesso invalida
/// [animalByIdProvider] e [animalListByPropertyProvider] e faz pop com true.
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
    final categoryLabel =
        kCategoryLabels[widget.animal.category] ?? widget.animal.category;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Editar animal',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Linhas travadas (número/categoria não editáveis)
                    Row(
                      children: [
                        Expanded(
                          child: _LockedField(
                            label: 'Número',
                            child: Text(
                              '#${widget.animal.number}',
                              style: monoStyle(
                                  size: 15.5, weight: FontWeight.w600),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _LockedField(
                            label: 'Categoria',
                            child: Text(
                              categoryLabel,
                              style: const TextStyle(fontSize: 15.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String?>(
                      initialValue: _breed,
                      decoration: const InputDecoration(labelText: 'Raça'),
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
                                    color: _ec == n
                                        ? AppColors.onGreen
                                        : AppColors.ink,
                                  ),
                                ),
                              ),
                            ),
                            selected: _ec == n,
                            onSelected: (sel) =>
                                setState(() => _ec = sel ? n : null),
                            showCheckmark: false,
                          ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                        hintText: 'Observações adicionais (opcional)',
                      ),
                      maxLines: 3,
                      textInputAction: TextInputAction.newline,
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
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Salvar'),
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

/// Caixa somente-leitura com cadeado — número/categoria travados (spec 4.4).
class _LockedField extends StatelessWidget {
  const _LockedField({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.surfaceSubtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.inputBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 11,
                    letterSpacing: 0.9,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 3),
                child,
              ],
            ),
          ),
          const Icon(Icons.lock_outline,
              size: 16, color: AppColors.textTertiary),
        ],
      ),
    );
  }
}
