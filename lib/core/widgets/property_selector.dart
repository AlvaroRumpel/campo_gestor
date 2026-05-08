import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/property_repository.dart';
import '../providers/current_property_provider.dart';

/// AppBar title: shows the active property. With 2+ properties, becomes a
/// PopupMenuButton dropdown showing all memberships with their perfil label.
/// With 1 property: plain Text (D-05). Loading/error states preserve the
/// Phase 0 visual contract.
class PropertySelector extends ConsumerWidget {
  const PropertySelector({super.key});

  static String _roleLabel(String raw) {
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(currentPropertyProvider);
    final members = ref.watch(memberPropertiesProvider);

    return current.when(
      data: (property) {
        if (property == null) {
          return const Text(
            'Selecionar propriedade',
            style: TextStyle(fontSize: 18),
          );
        }
        // With 1 prop: plain Text (no dropdown — D-05).
        final list = members.asData?.value ?? const <PropertyMembership>[];
        if (list.length <= 1) {
          return Text(property.name, style: const TextStyle(fontSize: 18));
        }
        // With 2+ props: dropdown via PopupMenuButton.
        return PopupMenuButton<PropertyMembership>(
          tooltip: 'Trocar propriedade',
          onSelected: (m) => ref
              .read(currentPropertyProvider.notifier)
              .selectProperty(m.property),
          itemBuilder: (context) => list
              .map(
                (m) => PopupMenuItem<PropertyMembership>(
                  value: m,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(m.property.name,
                          style: const TextStyle(fontSize: 16)),
                      const SizedBox(height: 4),
                      Text(
                        _roleLabel(m.role),
                        style: TextStyle(
                          fontSize: 12,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(property.name, style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 4),
              const Icon(Icons.arrow_drop_down, size: 24),
            ],
          ),
        );
      },
      loading: () => const SizedBox(
        width: 16,
        height: 16,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (err, _) => const Text(
        'Erro ao carregar propriedade',
        style: TextStyle(fontSize: 16),
      ),
    );
  }
}
