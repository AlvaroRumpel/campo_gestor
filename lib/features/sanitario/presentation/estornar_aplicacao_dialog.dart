import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/sanitary_application_exception.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// Shared estorno write path (extracted from `AplicacaoDetailScreen`, quick
/// task 260813-vvh) — the single owner of the dialog + invalidations +
/// success snackbar, called both from the detail screen's button and from
/// `AplicacoesTableView`'s row action so there is exactly one list of
/// invalidations in the project.
Future<void> confirmEstorno(
  BuildContext context,
  WidgetRef ref,
  SanitaryApplication app,
) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (_) => EstornarAplicacaoDialog(
      applicationId: app.id,
      doseName: app.doseName,
      appliedAt: app.appliedAt,
      lotId: app.lotId,
    ),
  );
  if (confirmed != true || !context.mounted) return;
  ref.invalidatePropertyData();
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('Aplicação estornada.')));
}

/// Estorno confirmation dialog (D-27..D-31, spec 4.20) — the one
/// destructive-toned action in this module. 480px dialog anatomy: undo icon
/// in a danger container, título "Estornar X de dd/MM/yyyy?", body
/// explaining the mirror record, required "MOTIVO DO ESTORNO *" input
/// (danger border when empty), Cancelar outline + "Estornar aplicação"
/// danger filled.
///
/// Errors render inline (D-36) — this dialog never shows a SnackBar; success
/// is the caller's job ([AplicacaoDetailScreen] shows it after this dialog
/// pops `true`).
class EstornarAplicacaoDialog extends ConsumerStatefulWidget {
  const EstornarAplicacaoDialog({
    super.key,
    required this.applicationId,
    required this.doseName,
    required this.appliedAt,
    required this.lotId,
  });

  final String applicationId;
  final String doseName;

  /// The frozen application date — part of the título per spec 4.20.
  final DateTime appliedAt;

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
      if (exception.reason == SanitaryApplicationErrorReason.alreadyReversed) {
        // The cached by-lot list predates this race — invalidate it so
        // `_ErrorSlot` resolves the sibling reversal row the other user
        // just created, instead of the stale (pre-race) snapshot (WR-02).
        ref.invalidatePropertyData();
      }
      setState(() => _error = exception);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: _saving
          ? const LinearProgressIndicator()
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: AppColors.dangerContainer,
                    borderRadius: BorderRadius.circular(11),
                  ),
                  child: const Icon(
                    Icons.undo,
                    size: 21,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Estornar ${widget.doseName} de '
                    '${_dateFmt.format(widget.appliedAt)}?',
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w700,
                      color: AppColors.ink,
                    ),
                  ),
                ),
              ],
            ),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'O registro original não é apagado: o estorno cria um '
                  'lançamento espelho, os dois ficam ligados e os efeitos '
                  'desta aplicação saem do histórico. Ambos os registros '
                  'ficam permanentes — esta ação não pode ser desfeita.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _motivoCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'MOTIVO DO ESTORNO *',
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
        OutlinedButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.danger,
            foregroundColor: AppColors.onDanger,
          ),
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Estornar aplicação'),
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
          style: const TextStyle(fontSize: 13.5, color: AppColors.danger),
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
