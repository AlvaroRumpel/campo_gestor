import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/current_property_provider.dart';

/// AppBar title showing the active property name and (Phase 1+) a dropdown to
/// switch between properties the user has access to.
///
/// Per D-04 (CONTEXT.md): the selector is wired from Phase 0 even though
/// `currentPropertyProvider` returns null. Phase 1 replaces the placeholder
/// text with a real dropdown sourced from `property_members`.
class PropertySelector extends ConsumerWidget {
  const PropertySelector({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentProperty = ref.watch(currentPropertyProvider);

    return currentProperty.when(
      data: (property) {
        if (property == null) {
          return const Text(
            'Selecionar propriedade',
            style: TextStyle(fontSize: 18),
          );
        }
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(property.nome, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, size: 24),
          ],
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
