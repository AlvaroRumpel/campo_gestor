import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/ui.dart';
import '../data/auth_repository.dart';

class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: EmptyState(
          icon: Icons.lock_outline,
          title: 'Acesso não configurado',
          message:
              'Sua conta foi criada, mas ainda não está vinculada a nenhuma propriedade. Entre em contato com o proprietário da fazenda para receber acesso.',
          action: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FilledButton(
                onPressed: () => context.push(AppRoutes.propriedades),
                child: const Text('Criar minha fazenda'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () async {
                  await ref.read(currentPropertyProvider.notifier).clear();
                  await ref.read(authRepositoryProvider).signOut();
                },
                child: const Text('Sair'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
