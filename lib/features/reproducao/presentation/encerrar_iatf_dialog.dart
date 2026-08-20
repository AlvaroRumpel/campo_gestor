import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../data/iatf_repository.dart';

/// Manual encerramento confirmation dialog (D-15, 05-UI-SPEC section 5/E7).
///
/// Sheet-style content shown via `showAdaptiveForm` (redesign): title 20/700,
/// footer Cancelar outline + "Encerrar" filled h52 r14. The confirm button
/// keeps the default primary color instead of `colorScheme.error` — closing
/// an IATF is a routine workflow step, not data loss.
///
/// Does not dismiss optimistically: `close_iatf` deactivates N membership
/// rows in one transaction, so the dialog stays mounted until the RPC
/// returns, and pops with `true` only after a successful await.
class EncerrarIatfDialog extends ConsumerStatefulWidget {
  const EncerrarIatfDialog({
    super.key,
    required this.iatfId,
    required this.iatfName,
    required this.pendingCount,
  });

  final String iatfId;
  final String iatfName;
  final int pendingCount;

  @override
  ConsumerState<EncerrarIatfDialog> createState() => _EncerrarIatfDialogState();
}

class _EncerrarIatfDialogState extends ConsumerState<EncerrarIatfDialog> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(iatfRepositoryProvider).closeIatf(widget.iatfId);
      if (!mounted) return;
      ref.invalidatePropertyData();
      Navigator.pop(context, true);
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

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
            'Encerrar IATF "${widget.iatfName}"?',
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          Flexible(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Esta ação libera os animais para participar de um novo ciclo. '
                    'O histórico é preservado e correções de DG continuam '
                    'possíveis depois de encerrado.',
                    style: theme.textTheme.bodyMedium,
                  ),
                  if (widget.pendingCount > 0) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Ainda há ${widget.pendingCount} '
                      '${widget.pendingCount == 1 ? 'animal' : 'animais'} sem DG '
                      'registrado.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.tertiary),
                    ),
                  ],
                  if (_failed) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Não foi possível encerrar o IATF. Tente novamente.',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
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
                  onPressed: _saving ? null : _submit,
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
                      : const Text('Encerrar'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
