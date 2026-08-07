import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/router/routes.dart';
import '../data/sanitary_application_exception.dart';
import '../data/sanitary_application_repository.dart';

/// Estorno confirmation dialog (D-27..D-31) — the one destructive-toned
/// action in this phase. Mirrors [BaixaDialog]'s required-reason
/// confirmation template: form key, validator, progress indicator in the
/// title slot, action pair, saving flag.
///
/// Errors render inline (D-36) — this dialog never shows a SnackBar; success
/// is the caller's job ([AplicacaoDetailScreen] shows it after this dialog
/// pops `true`).
class EstornarAplicacaoDialog extends ConsumerStatefulWidget {
  const EstornarAplicacaoDialog({
    super.key,
    required this.applicationId,
    required this.doseName,
    required this.lotId,
  });

  final String applicationId;
  final String doseName;

  /// Needed to resolve the existing reversal row when the RPC reports this
  /// application was already estornada (D-31 race) — the by-lot provider is
  /// the cheapest already-existing read that can find the sibling reversal
  /// row without a new query.
  final String lotId;

  @override
  ConsumerState<EstornarAplicacaoDialog> createState() =>
      _EstornarAplicacaoDialogState();
}

class _EstornarAplicacaoDialogState
    extends ConsumerState<EstornarAplicacaoDialog> {
  final _formKey = GlobalKey<FormState>();
  final _motivoCtrl = TextEditingController();
  bool _saving = false;
  SanitaryApplicationException? _error;

  @override
  void dispose() {
    _motivoCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref
          .read(sanitaryApplicationRepositoryProvider)
          .reverseApplication(
            applicationId: widget.applicationId,
            reason: _motivoCtrl.text.trim(),
          );
      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      final exception = asSanitaryException(
        e,
        fallbackMessage:
            'Não foi possível estornar a aplicação. Tente novamente.',
      );
      if (!mounted) return;
      setState(() => _error = exception);
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
              'Estornar aplicação "${widget.doseName}"?',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Esta ação cria um novo registro que anula os efeitos '
                  'desta aplicação no histórico. Ambos os registros ficam '
                  'permanentes — esta ação não pode ser desfeita.',
                  style: theme.textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Motivo do estorno *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) => (value == null || value.trim().isEmpty)
                      ? 'Informe o motivo do estorno'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  _ErrorSlot(
                    error: _error!,
                    lotId: widget.lotId,
                    applicationId: widget.applicationId,
                  ),
                ],
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
              : const Text('Estornar'),
        ),
      ],
    );
  }
}

/// Inline error message and, only for the already-reversed race (D-31), a
/// "Ver estorno" link resolved from the sibling reversal row in the by-lot
/// list — omitted (message-only) when that sibling can't be resolved, rather
/// than rendering a dead control.
class _ErrorSlot extends ConsumerWidget {
  const _ErrorSlot({
    required this.error,
    required this.lotId,
    required this.applicationId,
  });

  final SanitaryApplicationException error;
  final String lotId;
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    String? reversalId;
    if (error.reason == SanitaryApplicationErrorReason.alreadyReversed) {
      final siblings =
          ref.watch(sanitaryApplicationsByLotProvider(lotId)).asData?.value ??
          const [];
      reversalId = siblings
          .where((a) => a.reversesApplicationId == applicationId)
          .map((a) => a.id)
          .firstOrNull;
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          error.message,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.error,
          ),
        ),
        if (reversalId != null)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                context.go(AppRoutes.aplicacaoDetail(reversalId!));
              },
              child: const Text('Ver estorno'),
            ),
          ),
      ],
    );
  }
}
