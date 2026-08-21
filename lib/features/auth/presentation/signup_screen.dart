import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../data/auth_repository.dart';
import 'auth_scaffold.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});
  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _busy = false;
  bool _obscure = true;
  // G-10-02: when signup requires email confirmation, the screen ends in
  // this terminal state instead of a SnackBar + context.go(login) — a
  // SnackBar doesn't survive a route change, so the message was silently
  // lost and the user just landed back on /login with no explanation.
  String? _sentTo;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      final email = _emailCtrl.text.trim();
      final response = await ref.read(authRepositoryProvider).signUp(
            email: email,
            password: _passCtrl.text,
          );
      if (!mounted) return;
      if (response.session != null) {
        // Confirmation disabled on this project: user is already
        // authenticated. refreshListenable's router redirect takes it from here.
        return;
      }
      setState(() => _sentTo = email);
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.message)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Não foi possível conectar. Verifique sua conexão e tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  static final ButtonStyle _primaryButtonStyle = FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(54),
    textStyle: const TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w700,
    ),
  );

  @override
  Widget build(BuildContext context) {
    if (_sentTo != null) {
      return AuthScaffold(
        title: 'Confirme seu e-mail',
        tagline: 'Campo Gestor — gestão do rebanho no campo.',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Enviamos um link de confirmação para $_sentTo. '
              'Confirme por lá antes de entrar.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => context.go(AppRoutes.login),
              style: _primaryButtonStyle,
              child: const Text('Voltar para entrar'),
            ),
          ],
        ),
      );
    }
    return AuthScaffold(
      title: 'Criar conta',
      tagline: 'Campo Gestor — gestão do rebanho no campo.',
      child: Form(
        key: _formKey,
        autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
              validator: (v) => (v == null ||
                      !RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(v.trim()))
                  ? 'Digite um email válido'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _passCtrl,
              obscureText: _obscure,
              decoration: InputDecoration(
                labelText: 'Senha',
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                    size: 22,
                  ),
                  tooltip: _obscure ? 'Mostrar senha' : 'Ocultar senha',
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) => (v == null || v.length < 6)
                  ? 'A senha deve ter pelo menos 6 caracteres'
                  : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _confirmCtrl,
              obscureText: _obscure,
              decoration: const InputDecoration(labelText: 'Confirmar senha'),
              validator: (v) =>
                  v == _passCtrl.text ? null : 'As senhas não coincidem',
            ),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: _busy ? null : _submit,
              style: _primaryButtonStyle,
              child: _busy
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Criar conta'),
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () => context.go(AppRoutes.login),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDarkText,
              ),
              child: const Text('Já tem conta? Entrar'),
            ),
          ],
        ),
      ),
    );
  }
}
