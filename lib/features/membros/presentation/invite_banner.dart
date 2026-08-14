import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/widgets/ui.dart';
import '../data/membro_exception.dart';
import '../data/membro_models.dart';
import '../data/membro_repository.dart';

/// Widget único de convite aceitar/recusar — compartilhado por `/sem-acesso`
/// (10-08) e pelo banner do dashboard (10-09). A lógica de aceite não é
/// escrita duas vezes.
class InviteBanner extends ConsumerStatefulWidget {
  const InviteBanner({super.key, required this.invite});

  final MyInvite invite;

  @override
  ConsumerState<InviteBanner> createState() => _InviteBannerState();
}

class _InviteBannerState extends ConsumerState<InviteBanner> {
  bool _busy = false;

  Future<void> _accept() async {
    setState(() => _busy = true);
    try {
      await ref.read(membroRepositoryProvider).acceptInvite(widget.invite.id);
      // A navegação é consequência do redirect do GoRouter, que reage à
      // invalidação de memberPropertiesProvider via _RouterRefreshNotifier
      // (lib/core/router/router.dart). Navegar manualmente aqui é proibido —
      // duplicaria o mecanismo já provado do projeto.
      ref.invalidate(memberPropertiesProvider);
      ref.invalidate(myInvitesProvider);
    } catch (e) {
      if (!mounted) return;
      final ex = asMembroException(
        e,
        fallbackMessage: 'Erro ao aceitar o convite. Tente novamente.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _decline() async {
    setState(() => _busy = true);
    try {
      await ref.read(membroRepositoryProvider).declineInvite(widget.invite.id);
      ref.invalidate(myInvitesProvider);
    } catch (e) {
      if (!mounted) return;
      final ex = asMembroException(
        e,
        fallbackMessage: 'Erro ao recusar o convite. Tente novamente.',
      );
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(ex.message)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WarningBanner(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Você recebeu um convite para ${widget.invite.propertyName} '
              'como ${roleLabel(widget.invite.role)}.',
              softWrap: true,
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _busy ? null : _decline,
                    child: const Text('Recusar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton(
                    onPressed: _busy ? null : _accept,
                    child: const Text('Aceitar'),
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
