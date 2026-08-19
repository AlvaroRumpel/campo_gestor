import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/data/piquete_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';

/// Form content for moving an entire lot to another paddock in the same
/// property (MOV-02, D-06..D-10). Shown via `showAdaptiveForm` (bottom sheet
/// <600px / dialog 480px).
///
/// Layout (spec 3.7/4.16 footer):
/// - title: 'Mover lote "[nome]" para outro piquete?' 20/700
/// - info text + scrollable paddock picker (maxHeight 320), excluding the
///   lot's current paddock
/// - footer: OutlinedButton('Cancelar') flex 1 + FilledButton('Confirmar
///   movimentação') flex 1.4 (confirm disabled until a paddock is selected)
///
/// On success: invalidates [loteByIdProvider], both old and new
/// [loteListByPaddockProvider] (D-12), then pops with a result Map
/// `{'paddockName': name}` so the parent shows a SnackBar (D-10).
class MoverLoteDialog extends ConsumerStatefulWidget {
  const MoverLoteDialog({
    super.key,
    required this.lot,
    required this.activeAnimalCount,
    this.initialPaddock,
  });

  final Lot lot;
  final int activeAnimalCount;

  /// Piquete de destino pré-selecionado (D-quadro-desktop): quando o
  /// diálogo é aberto a partir de um drop no quadro de piquetes, abre já
  /// com esse piquete selecionado, servindo de tela de confirmação.
  final Paddock? initialPaddock;

  @override
  ConsumerState<MoverLoteDialog> createState() => _MoverLoteDialogState();
}

class _MoverLoteDialogState extends ConsumerState<MoverLoteDialog> {
  String? _selectedPaddockId;
  String? _selectedPaddockName;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _selectedPaddockId = widget.initialPaddock?.id;
    _selectedPaddockName = widget.initialPaddock?.name;
  }

  Future<void> _submit() async {
    final paddockId = _selectedPaddockId;
    if (paddockId == null) return; // button disabled — defensive

    final selectedName = _selectedPaddockName ?? '';

    setState(() => _saving = true);
    try {
      await ref.read(loteRepositoryProvider).moveLot(
            lotId: widget.lot.id,
            newPaddockId: paddockId,
          );
      if (!mounted) return; // WR-03: check before touching ref
      ref.invalidatePropertyData();
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
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
            'Mover lote "${widget.lot.name}" para outro piquete?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            widget.activeAnimalCount == 1
                ? '1 animal será transferido para o novo piquete. A operação é atômica — ou todos movem ou nenhum.'
                : '${widget.activeAnimalCount} animais serão transferidos para o novo piquete. A operação é atômica — ou todos movem ou nenhum.',
            style: const TextStyle(
              fontSize: 14,
              height: 1.45,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 14),
          Flexible(
            child: ConstrainedBox(
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
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                flex: 10,
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.pop(context),
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
                flex: 14,
                child: FilledButton(
                  onPressed:
                      (_saving || _selectedPaddockId == null) ? null : _submit,
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
                      : const Text('Confirmar movimentação'),
                ),
              ),
            ],
          ),
        ],
      ),
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
