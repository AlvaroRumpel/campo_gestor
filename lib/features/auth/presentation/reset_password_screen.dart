import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/routes.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';

class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});
  @override
  ConsumerState<ResetPasswordScreen> createState() => _S();
}

class _S extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  bool get _isRecoveryState {
    final s = ref.read(authNotifierProvider).asData?.value;
    return s?.event == AuthChangeEvent.passwordRecovery;
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(authRepositoryProvider)
          .resetPasswordForEmail(_emailCtrl.text.trim());
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email de redefinição enviado. Verifique sua caixa de entrada.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Se esse email estiver cadastrado, você receberá as instruções em breve.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submitNewPassword() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updatePassword(_passCtrl.text);
      // After updateUser, supabase emits userUpdated → router routes home.
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final recovery = _isRecoveryState;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 48),
                    Icon(Icons.lock_reset, size: 64, color: theme.colorScheme.primary),
                    const SizedBox(height: 24),
                    Text(recovery ? 'Nova senha' : 'Redefinir senha',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 32),
                    Card(
                      color: theme.colorScheme.surfaceContainer,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Form(
                          key: _formKey,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          child: recovery
                              ? Column(children: [
                                  TextFormField(
                                    controller: _passCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Nova senha',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) => (v == null || v.length < 6)
                                        ? 'A senha deve ter pelo menos 6 caracteres'
                                        : null,
                                  ),
                                  const SizedBox(height: 16),
                                  TextFormField(
                                    controller: _confirmCtrl,
                                    obscureText: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Confirmar senha',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) => v == _passCtrl.text
                                        ? null
                                        : 'As senhas não coincidem',
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    onPressed: _busy ? null : _submitNewPassword,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Salvar nova senha'),
                                  ),
                                ])
                              : Column(children: [
                                  TextFormField(
                                    controller: _emailCtrl,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: const InputDecoration(
                                      labelText: 'Email',
                                      border: OutlineInputBorder(),
                                    ),
                                    validator: (v) => (v == null ||
                                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                                .hasMatch(v.trim()))
                                        ? 'Digite um email válido'
                                        : null,
                                  ),
                                  const SizedBox(height: 24),
                                  FilledButton(
                                    onPressed: _busy ? null : _submitRequest,
                                    style: FilledButton.styleFrom(
                                      minimumSize: const Size(double.infinity, 48),
                                    ),
                                    child: _busy
                                        ? const SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                                strokeWidth: 2),
                                          )
                                        : const Text('Enviar email de redefinição'),
                                  ),
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: () => context.go(AppRoutes.login),
                                    child: const Text('Voltar ao login'),
                                  ),
                                ]),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
