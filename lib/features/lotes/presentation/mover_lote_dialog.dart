import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animais/data/animal_repository.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';

/// Dialog for moving an entire lot to another paddock in the same property
/// (MOV-02, D-06..D-10).
///
/// Layout (matches BaixaDialog/MoverAnimalDialog template):
/// - title: 'Mover lote "[nome]" para outro piquete?' (or LinearProgressIndicator during save)
/// - content: 480-wide column with info text + scrollable paddock picker
///   (maxHeight 320), excluding the lot's current paddock
/// - actions: TextButton('Cancelar') + FilledButton('Confirmar movimentação')
///   (confirm disabled until a paddock is selected)
///
/// On success: invalidates [loteByIdProvider], both old and new
/// [loteListByPaddockProvider] (D-12), then pops with a result Map
/// `{'paddockName': name}` so the parent shows a SnackBar (D-10).
class MoverLoteDialog extends ConsumerStatefulWidget {
  const MoverLoteDialog({
    super.key,
    required this.lot,
    required this.activeAnimalCount,
  });

  final Lot lot;
  final int activeAnimalCount;

  @override
  ConsumerState<MoverLoteDialog> createState() => _MoverLoteDialogState();
}

class _MoverLoteDialogState extends ConsumerState<MoverLoteDialog> {
  String? _selectedPaddockId;
  String? _selectedPaddockName;
  bool _saving = false;

  Future<void> _submit() async {
    final paddockId = _selectedPaddockId;
    if (paddockId == null) return; // button disabled — defensive

    final oldPaddockId = widget.lot.paddockId; // capture BEFORE async (Pitfall 2)
    final selectedName = _selectedPaddockName ?? '';

    setState(() => _saving = true);
    try {
      await ref.read(loteRepositoryProvider).moveLot(
            lotId: widget.lot.id,
            newPaddockId: paddockId,
          );
      if (!mounted) return; // WR-03: check before touching ref
      // D-12: invalidate old + new paddock-scoped lot lists and the lot itself
      ref.invalidate(loteByIdProvider(widget.lot.id));
      ref.invalidate(loteListByPaddockProvider(oldPaddockId));
      ref.invalidate(loteListByPaddockProvider(paddockId));
      // WR-01/WR-02: a lot's paddock change affects both cross-feature lists
      ref.invalidate(animalListByPropertyProvider);
      ref.invalidate(loteListByPropertyProvider);
      Navigator.pop(context, {'paddockName': selectedName});
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
          : Text('Mover lote "${widget.lot.name}" para outro piquete?'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.activeAnimalCount == 1
                    ? '1 animal será transferido para o novo piquete. A operação é atômica — ou todos movem ou nenhum.'
                    : '${widget.activeAnimalCount} animais serão transferidos para o novo piquete. A operação é atômica — ou todos movem ou nenhum.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 320),
                child: _PaddockPickerList(
                  currentPaddockId: widget.lot.paddockId,
                  selectedPaddockId: _selectedPaddockId,
                  onSelected: (id, name) {
                    setState(() {
                      _selectedPaddockId = id;
                      _selectedPaddockName = name;
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
          onPressed:
              (_saving || _selectedPaddockId == null) ? null : _submit,
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

/// Scrollable paddock picker. Excludes [currentPaddockId]. Uses
/// [paddockListProvider] (already scoped to active property).
class _PaddockPickerList extends ConsumerWidget {
  const _PaddockPickerList({
    required this.currentPaddockId,
    required this.selectedPaddockId,
    required this.onSelected,
  });

  final String currentPaddockId;
  final String? selectedPaddockId;
  final void Function(String id, String name) onSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paddocksAsync = ref.watch(paddockListProvider);

    return paddocksAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Text(
        'Erro ao carregar. Tente novamente.',
        style: theme.textTheme.bodyMedium,
      ),
      data: (paddocks) {
        final available = paddocks
            .where((p) => p.id != currentPaddockId)
            .toList();
        if (available.isEmpty) {
          return Text(
            'Nenhum outro piquete disponível nesta propriedade.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          );
        }
        return ListView.builder(
          shrinkWrap: true,
          itemCount: available.length,
          itemBuilder: (context, i) {
            final p = available[i];
            final isSelected = p.id == selectedPaddockId;
            final areaStr = p.areaHa > 0
                ? '${p.areaHa.toStringAsFixed(1).replaceAll('.', ',')} ha'
                : '—';
            return ListTile(
              selected: isSelected,
              selectedTileColor: theme.colorScheme.primaryContainer,
              title: Text(
                p.name,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                areaStr,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
              onTap: () => onSelected(p.id, p.name),
            );
          },
        );
      },
    );
  }
}
