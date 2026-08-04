import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/atf_repository.dart';

/// Manual encerramento confirmation dialog (D-15, 05-UI-SPEC section 5/E7).
///
/// Structural template copied from `BaixaDialog`, with two deliberate
/// deviations: a narrower 400px content width (vs. 480px), and a default
/// primary-color confirm button instead of `colorScheme.error` — closing an
/// ATF is a routine workflow step, not data loss.
///
/// Does not dismiss optimistically: `close_atf` deactivates N membership
/// rows in one transaction, so the dialog stays mounted until the RPC
/// returns, and pops with `true` only after a successful await.
class EncerrarAtfDialog extends ConsumerStatefulWidget {
  const EncerrarAtfDialog({
    super.key,
    required this.atfId,
    required this.atfName,
    required this.pendingCount,
  });

  final String atfId;
  final String atfName;
  final int pendingCount;

  @override
  ConsumerState<EncerrarAtfDialog> createState() => _EncerrarAtfDialogState();
}

class _EncerrarAtfDialogState extends ConsumerState<EncerrarAtfDialog> {
  bool _saving = false;
  bool _failed = false;

  Future<void> _submit() async {
    setState(() {
      _saving = true;
      _failed = false;
    });
    try {
      await ref.read(atfRepositoryProvider).closeAtf(widget.atfId);
      if (!mounted) return;
      ref.invalidate(atfByIdProvider(widget.atfId));
      ref.invalidate(atfActiveMembershipsProvider(widget.atfId));
      ref.invalidate(atfMembershipsProvider(widget.atfId));
      ref.invalidate(atfListByPropertyProvider);
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

    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Text(
              'Encerrar ATF "${widget.atfName}"?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      content: SizedBox(
        width: 400,
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
                  'Não foi possível encerrar o ATF. Tente novamente.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: colorScheme.error),
                ),
              ],
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
              : const Text('Encerrar'),
        ),
      ],
    );
  }
}
