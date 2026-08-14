import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/data/auth_repository.dart';
import '../../features/auth/data/property_repository.dart';
import '../providers/current_property_provider.dart';
import '../router/routes.dart';
import '../theme/app_colors.dart';
import 'ui.dart';

/// Seletor de fazenda do app bar verde (spec 3.1/4.2): avatar com iniciais +
/// nome + expand_more. Menu lista as fazendas com papel, "Gerenciar fazendas"
/// e "Sair" (o logout mora aqui no mobile; no rail desktop há botão próprio).
class PropertySelector extends ConsumerWidget {
  const PropertySelector({super.key, this.compact = false});

  /// When true, renders only the farm avatar (no name/expand_more) — used
  /// by the 76px icon rail, which has no room for the full row.
  final bool compact;

  static String roleLabel(String raw) {
    switch (raw) {
      case 'owner':
        return 'Proprietário';
      case 'veterinarian':
        return 'Veterinário';
      case 'reader':
        return 'Leitor';
      default:
        return raw;
    }
  }

  Future<void> _signOut(WidgetRef ref) async {
    // Clear persisted property ID BEFORE signOut so SharedPreferences is
    // clean before the auth event fires and triggers a router redirect.
    await ref.read(currentPropertyProvider.notifier).clear();
    await ref.read(authRepositoryProvider).signOut();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPropertyProvider);
    final members = ref.watch(memberPropertiesProvider);

    return current.when(
      data: (property) {
        final name = property?.name ?? 'Selecionar fazenda';
        final list = members.asData?.value ?? const <PropertyMembership>[];
        return PopupMenuButton<Object?>(
          tooltip: 'Trocar de fazenda',
          onSelected: (v) {
            if (v is PropertyMembership) {
              ref
                  .read(currentPropertyProvider.notifier)
                  .selectProperty(v.property);
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem<Object?>(
              enabled: false,
              height: 32,
              child: OverlineLabel('Trocar de fazenda', mono: true),
            ),
            ...list.map(
              (m) => PopupMenuItem<Object?>(
                value: m,
                child: Row(
                  children: [
                    FarmAvatar(
                      name: m.property.name,
                      size: 34,
                      background: m.property.id == property?.id
                          ? AppColors.primary
                          : AppColors.neutralChipBg,
                      foreground: m.property.id == property?.id
                          ? AppColors.onGreen
                          : AppColors.ink,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            m.property.name,
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w600),
                          ),
                          Text(
                            roleLabel(m.role),
                            style: const TextStyle(
                                fontSize: 12.5,
                                color: AppColors.textSecondary),
                          ),
                        ],
                      ),
                    ),
                    if (m.property.id == property?.id)
                      const Icon(Icons.check_circle,
                          size: 22, color: AppColors.primary),
                  ],
                ),
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem<Object?>(
              onTap: () => context.push(AppRoutes.propriedades),
              child: const Row(
                children: [
                  Icon(Icons.settings_outlined,
                      size: 20, color: AppColors.primary),
                  SizedBox(width: 10),
                  Text('Gerenciar fazendas',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary)),
                ],
              ),
            ),
            PopupMenuItem<Object?>(
              onTap: () => _signOut(ref),
              child: const Row(
                children: [
                  Icon(Icons.logout, size: 20),
                  SizedBox(width: 10),
                  Text('Sair'),
                ],
              ),
            ),
          ],
          child: compact
              ? FarmAvatar(name: property?.name ?? '?', size: 36)
              : Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FarmAvatar(name: property?.name ?? '?'),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        name,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: AppColors.onGreen,
                        ),
                      ),
                    ),
                    const Icon(Icons.expand_more,
                        size: 20, color: AppColors.onGreenSecondary),
                  ],
                ),
        );
      },
      loading: () => const Align(
        alignment: Alignment.centerLeft,
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: AppColors.onGreen),
        ),
      ),
      error: (err, _) => ErrorRetry(
        message: 'Erro ao carregar fazenda',
        onRetry: () => ref.invalidate(currentPropertyProvider),
      ),
    );
  }
}
