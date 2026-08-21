import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import '../providers/auth_provider.dart';
import 'auth_scaffold.dart';

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

  ButtonStyle get _ctaStyle => FilledButton.styleFrom(
        minimumSize: const Size.fromHeight(54),
        textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      );

  Widget get _busySpinner => const SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );

  @override
  Widget build(BuildContext context) {
    final recovery = _isRecoveryState;
    return AuthScaffold(
      title: recovery ? 'Nova senha' : 'Redefinir senha',
      icon: Icons.lock_reset,
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: recovery
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _passCtrl,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Nova senha'),
                    validator: (v) => (v == null || v.length < 6)
                        ? 'A senha deve ter pelo menos 6 caracteres'
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmCtrl,
                    obscureText: true,
                    decoration:
                        const InputDecoration(labelText: 'Confirmar senha'),
                    validator: (v) =>
                        v == _passCtrl.text ? null : 'As senhas não coincidem',
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submitNewPassword,
                    style: _ctaStyle,
                    child: _busy ? _busySpinner : const Text('Salvar nova senha'),
                  ),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (v) => (v == null ||
                            !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$')
                                .hasMatch(v.trim()))
                        ? 'Digite um email válido'
                        : null,
                  ),
                  const SizedBox(height: 18),
                  FilledButton(
                    onPressed: _busy ? null : _submitRequest,
                    style: _ctaStyle,
                    child: _busy
                        ? _busySpinner
                        : const Text('Enviar email de redefinição'),
                  ),
                  const SizedBox(height: 6),
                  TextButton(
                    onPressed: () => context.go(AppRoutes.login),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primaryDarkText,
                    ),
                    child: const Text('Voltar ao login'),
                  ),
                ],
              ),
      ),
    );
  }
}
