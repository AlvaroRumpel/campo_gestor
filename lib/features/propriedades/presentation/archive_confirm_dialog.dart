import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';

/// Confirmação forte por digitação do nome, antes de arquivar uma fazenda
/// (PROPV-01). Devolve `true` via `Navigator.pop` só quando o texto digitado
/// casa exatamente (case-sensitive) com [propertyName]; devolve `false` no
/// cancelamento. Não conhece Riverpod nem o repositório — quem chama o
/// `PropertyRepository.softDeleteProperty` é a tela (plano 10-07).
class ArchiveConfirmDialog extends StatefulWidget {
  const ArchiveConfirmDialog({super.key, required this.propertyName});
  final String propertyName;

  @override
  State<ArchiveConfirmDialog> createState() => _ArchiveConfirmDialogState();
}

class _ArchiveConfirmDialogState extends State<ArchiveConfirmDialog> {
  late final TextEditingController _controller;

  // Comparação exata, sem trim()/toLowerCase(): o usuário precisa digitar o
  // nome exatamente como está escrito. Este onPressed: null é a exceção
  // desenhada à convenção "controle ausente, nunca desabilitado" — aquela
  // convenção governa visibilidade por papel, não validade de formulário.
  bool get _matches => _controller.text == widget.propertyName;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController()..addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
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
                    Icons.archive_outlined,
                    size: 21,
                    color: AppColors.danger,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Arquivar fazenda',
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Esta ação oculta "${widget.propertyName}" para todos os '
              'membros até que um veterinário a restaure. Digite o nome da '
              'fazenda para confirmar.',
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              decoration: const InputDecoration(hintText: 'Nome da fazenda'),
              autofocus: true,
              autocorrect: false,
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
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
                        _matches ? () => Navigator.pop(context, true) : null,
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.danger,
                      foregroundColor: AppColors.onDanger,
                      minimumSize: const Size.fromHeight(52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Arquivar'),
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
