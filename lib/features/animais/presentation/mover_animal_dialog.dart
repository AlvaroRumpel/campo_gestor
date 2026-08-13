import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Formulário de movimentação de animal entre lotes — conteúdo para
/// [showAdaptiveForm] (MOV-01, D-01..D-05).
///
/// Picker de lotes (exclui o lote atual do animal) + rodapé Cancelar /
/// "Confirmar movimentação" (desabilitado até selecionar um lote).
///
/// Em sucesso: invalida [animalByIdProvider], os dois
/// [animalListByLotProvider] (origem e destino) e
/// [animalListByPropertyProvider] (D-11), e faz pop com `{'lotName': ...}`
/// para o pai mostrar o SnackBar (D-05).
class MoverAnimalDialog extends ConsumerStatefulWidget {
  const MoverAnimalDialog({super.key, required this.animal});

  final Animal animal;

  @override
  ConsumerState<MoverAnimalDialog> createState() => _MoverAnimalDialogState();
}

class _MoverAnimalDialogState extends ConsumerState<MoverAnimalDialog> {
  String? _selectedLotId;
  String? _selectedLotName;
  bool _saving = false;

  Future<void> _submit() async {
    final lotId = _selectedLotId;
    if (lotId == null) return; // button is disabled — defensive

    final oldLotId = widget.animal.lotId; // capture BEFORE async (Pitfall 2)
    final selectedName = _selectedLotName ?? '';

    setState(() => _saving = true);
    try {
      await ref.read(animalRepositoryProvider).moveAnimal(
            id: widget.animal.id,
            newLotId: lotId,
          );
      if (!mounted) return; // WR-03: check before touching ref
      // D-11: invalidate old + new lots, the animal itself, and the property list
      ref.invalidate(animalByIdProvider(widget.animal.id));
      ref.invalidate(animalListByLotProvider(oldLotId));
      ref.invalidate(animalListByLotProvider(lotId));
      ref.invalidate(animalListByPropertyProvider);
      Navigator.pop(context, {'lotName': selectedName});
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao mover. Tente novamente.')),
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Mover #${widget.animal.number} para outro lote',
              style:
                  const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text(
              'Selecione o lote de destino. O animal continuará ativo e seu histórico será preservado.',
              style: TextStyle(
                fontSize: 13.5,
                height: 1.45,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _LotPickerList(
                  currentLotId: widget.animal.lotId,
                  selectedLotId: _selectedLotId,
                  onSelected: (id, name) {
                    setState(() {
                      _selectedLotId = id;
                      _selectedLotName = name;
                    });
                  },
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
                        _saving ? null : () => Navigator.pop(context),
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
                    onPressed:
                        (_saving || _selectedLotId == null) ? null : _submit,
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
                        : const Text('Confirmar movimentação'),
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

/// Scrollable lot picker. Excludes [currentLotId]. Uses
/// [loteListByPropertyProvider]; shows loading/error/empty states. Each row
/// resolves paddock name and active animal count via
/// [paddockByIdProvider]/[animalListByLotProvider] (D-03).
class _LotPickerList extends ConsumerWidget {
  const _LotPickerList({
    required this.currentLotId,
    required this.selectedLotId,
    required this.onSelected,
  });

  final String currentLotId;
  final String? selectedLotId;
  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final lotsAsync = ref.watch(loteListByPropertyProvider);

    return lotsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        'Erro ao carregar. Tente novamente.',
        style: theme.textTheme.bodyMedium,
      ),
      data: (lots) {
        final available = lots.where((l) => l.id != currentLotId).toList();
        if (available.isEmpty) {
          return const Text(
            'Nenhum outro lote disponível nesta propriedade.',
            style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: available.length,
          itemBuilder: (context, i) {
            final lot = available[i];
            final isSelected = lot.id == selectedLotId;
            return _LotPickerTile(
              lot: lot,
              isSelected: isSelected,
              onTap: () => onSelected(lot.id, lot.name),
            );
          },
        );
      },
    );
  }
}

/// Single picker row: lot name + "Piquete {name} · {count} animais" subtitle.
class _LotPickerTile extends ConsumerWidget {
  const _LotPickerTile({
    required this.lot,
    required this.isSelected,
    required this.onTap,
  });

  final Lot lot;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddockAsync = ref.watch(paddockByIdProvider(lot.paddockId));
    final animalsAsync = ref.watch(animalListByLotProvider(lot.id));

    final paddockName = paddockAsync.asData?.value?.name ?? '—';
    final animalCount = animalsAsync.asData?.value.length ?? 0;

    return ListTile(
      selected: isSelected,
      selectedTileColor: AppColors.positiveChipBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        lot.name,
        style: const TextStyle(fontSize: 15.5, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Piquete $paddockName · $animalCount animais',
        style:
            const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
      ),
      trailing: isSelected
          ? const Icon(Icons.check_circle,
              size: 22, color: AppColors.primary)
          : null,
      onTap: onTap,
    );
  }
}
