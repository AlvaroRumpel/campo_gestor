import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../features/auth/data/property_repository.dart';
import '../data/propriedade_model.dart';
import '../data/propriedade_repository.dart';
import 'property_form_dialog.dart';

class PropriedadesScreen extends ConsumerWidget {
  const PropriedadesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final propertiesAsync = ref.watch(propertyListProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final canEdit = _canEditProperties(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Fazendas'),
      ),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Erro ao carregar fazendas.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (properties) {
          if (properties.isEmpty) {
            return _EmptyState(canCreate: canEdit);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: properties.length,
            separatorBuilder: (context, index) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PropertyCard(
              property: properties[i],
              canEdit: canEdit,
              onEdit: () => _openForm(context, ref, property: properties[i]),
              onDelete: () => _confirmDelete(context, ref, properties[i]),
            ),
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _openForm(context, ref),
              tooltip: 'Nova fazenda',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  bool _canEditProperties(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Property? property,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PropertyFormDialog(existing: property),
    );
    if (result == true) {
      ref.invalidate(propertyListProvider);
      ref.invalidate(memberPropertiesProvider);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Property property,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover fazenda'),
        content: Text(
          'Tem certeza que deseja remover "${property.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
            ),
            child: const Text('Remover'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref
          .read(propertyRepositoryProvider)
          .softDeleteProperty(property.id);
      ref.invalidate(propertyListProvider);
      ref.invalidate(memberPropertiesProvider);
    }
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.canCreate});
  final bool canCreate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.landscape_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma fazenda cadastrada',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie sua primeira fazenda para começar a organizar o rebanho.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });
  final Property property;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.landscape),
        title: Text(property.name),
        subtitle: property.owner != null
            ? Text('Proprietário: ${property.owner}')
            : null,
        trailing: canEdit
            ? PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Remover',
                      style: TextStyle(color: theme.colorScheme.error),
                    ),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}
