import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/membro_exception.dart';
import '../data/membro_models.dart';
import '../data/membro_repository.dart';

final _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

/// Diálogo "Convidar membro" — pede e-mail e papel, chama `create_invite`.
///
/// Aberto pela tela (10-05) via `showAdaptiveForm(width: FormWidth.form)`;
/// este arquivo não chama `showAdaptiveForm` diretamente.
class InviteFormDialog extends ConsumerStatefulWidget {
  const InviteFormDialog({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<InviteFormDialog> createState() => _InviteFormDialogState();
}

class _InviteFormDialogState extends ConsumerState<InviteFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  String _role = 'reader';
  bool _saving = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      await ref.read(membroRepositoryProvider).createInvite(
            propertyId: widget.propertyId,
            email: _emailController.text.trim(),
            role: _role,
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final ex = asMembroException(
        e,
        fallbackMessage: 'Erro ao enviar o convite. Tente novamente.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 18, 20, 16),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving) ...[
                const LinearProgressIndicator(),
                const SizedBox(height: 10),
              ],
              const Text(
                'Convidar membro',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'E-mail do convidado *',
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                autofocus: true,
                validator: (v) {
                  final value = v?.trim() ?? '';
                  if (value.isEmpty) return 'Informe o e-mail do convidado.';
                  if (!_emailPattern.hasMatch(value)) {
                    return 'Informe um e-mail válido.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 14),
              DropdownButtonFormField<String>(
                initialValue: _role,
                decoration: const InputDecoration(labelText: 'Papel'),
                items: [
                  for (final role in const ['veterinarian', 'owner', 'reader'])
                    DropdownMenuItem(value: role, child: Text(roleLabel(role))),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _role = v ?? _role),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: OutlinedButton(
                      onPressed:
                          _saving ? null : () => Navigator.pop(context, false),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
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
                        minimumSize: const Size.fromHeight(52),
                      ),
                      child: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Enviar convite'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
