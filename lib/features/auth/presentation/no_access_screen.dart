import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/widgets/ui.dart';
import '../../membros/data/membro_repository.dart';
import '../../membros/presentation/invite_banner.dart';
import '../data/auth_repository.dart';

class NoAccessScreen extends ConsumerWidget {
  const NoAccessScreen({super.key});

  /// The two exits available in every state of this screen (loading, error,
  /// empty, with invites) — extracted so no state renders without a way out
  /// (T-10-29).
  Widget _exitActions(BuildContext context, WidgetRef ref) {
    return Column(
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
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ref.watch(myInvitesProvider).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, _) => Center(
                child: ErrorRetry(
                  message: 'Erro ao carregar. Verifique sua conexão e '
                      'tente novamente.',
                  onRetry: () => ref.invalidate(myInvitesProvider),
                ),
              ),
              data: (invites) {
                if (invites.isEmpty) {
                  return EmptyState(
                    icon: Icons.mail_outline,
                    title: 'Nenhum convite no momento',
                    message: 'Peça para um veterinário da fazenda te '
                        'convidar pelo seu e-mail de cadastro.',
                    action: _exitActions(context, ref),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text(
                      'Convites pendentes',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 12),
                    for (var i = 0; i < invites.length; i++) ...[
                      InviteBanner(invite: invites[i]),
                      if (i != invites.length - 1) const SizedBox(height: 10),
                    ],
                    const SizedBox(height: 24),
                    _exitActions(context, ref),
                  ],
                );
              },
            ),
      ),
    );
  }
}
