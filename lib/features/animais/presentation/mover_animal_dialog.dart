import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';

/// Dialog for moving an animal to another lot in the same property
/// (MOV-01, D-01..D-05).
///
/// Layout (matches BaixaDialog template):
/// - title: 'Mover animal #N para outro lote?' (or LinearProgressIndicator during save)
/// - content: 480-wide column with explanation text + scrollable lot picker
///   (maxHeight 320), excluding the animal's current lot
/// - actions: TextButton('Cancelar') + FilledButton('Confirmar movimentação')
///   (confirm disabled until a lot is selected)
///
/// On success: invalidates [animalByIdProvider], both old and new
/// [animalListByLotProvider], and [animalListByPropertyProvider] (D-11),
/// then pops with a `{'lotName': ...}` map so the parent shows a SnackBar
/// (D-05).
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
    final theme = Theme.of(context);

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Text('Mover animal #${widget.animal.number} para outro lote?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Selecione o lote de destino. O animal continuará ativo e seu histórico será preservado.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
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
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: (_saving || _selectedLotId == null) ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Confirmar movimentação'),
        ),
      ],
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
          return Text(
            'Nenhum outro lote disponível nesta propriedade.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
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
    final theme = Theme.of(context);
    final paddockAsync = ref.watch(paddockByIdProvider(lot.paddockId));
    final animalsAsync = ref.watch(animalListByLotProvider(lot.id));

    final paddockName = paddockAsync.asData?.value?.name ?? '—';
    final animalCount = animalsAsync.asData?.value.length ?? 0;

    return ListTile(
      selected: isSelected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      title: Text(
        lot.name,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        'Piquete $paddockName · $animalCount animais',
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
        ),
      ),
      onTap: onTap,
    );
  }
}
