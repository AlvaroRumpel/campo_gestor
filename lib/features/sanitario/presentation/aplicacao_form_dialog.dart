import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'registrar_aplicacao_screen.dart';

/// D-24's success SnackBar copy, pluralised per the UI-SPEC contract
/// (`Intl.plural`, never the "animal(is)" parenthetical). Shared by both
/// entry points so the two call sites cannot drift apart.
String sanitaryRegisteredMessage(int count) =>
    'Aplicação registrada — '
    '${Intl.plural(count, one: '1 animal', other: '$count animais', locale: 'pt_BR')}';

/// Compat adapter for the redesigned single-screen registration flow
/// (spec 4.10). The old 3-step chain (this dialog → selection screen →
/// resumo dialog) collapsed into [RegistrarAplicacaoScreen]; this widget
/// keeps the old `showDialog(builder: (_) => AplicacaoFormDialog(...))`
/// entry point compiling (LoteDetailScreen's "Aplicação" action): on first
/// frame it pops the dialog route and pushes the full screen on the same
/// navigator — exactly the pop-then-push the old dialog performed on
/// "Continuar" (06-08/06-11), so the `showDialog` future still resolves
/// null and the count still arrives through [onRegistered].
class AplicacaoFormDialog extends StatefulWidget {
  const AplicacaoFormDialog({super.key, this.lotId, this.onRegistered});

  /// Pre-selects the lot on the registration screen.
  final String? lotId;

  /// Fires with the registered animal count once the flow completes
  /// successfully — callers hook this instead of awaiting `showDialog`.
  final ValueChanged<int>? onRegistered;

  @override
  State<AplicacaoFormDialog> createState() => _AplicacaoFormDialogState();
}

class _AplicacaoFormDialogState extends State<AplicacaoFormDialog> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final onRegistered = widget.onRegistered;
      navigator.pop();
      navigator
          .push<int>(
            MaterialPageRoute(
              fullscreenDialog: true,
              builder: (_) =>
                  RegistrarAplicacaoScreen(initialLotId: widget.lotId),
            ),
          )
          .then((count) {
        if (count != null) onRegistered?.call(count);
      });
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
