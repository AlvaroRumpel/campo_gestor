import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../features/auth/data/property_repository.dart';
import '../data/piquete_model.dart';
import '../data/piquete_repository.dart';
import 'paddock_form_dialog.dart';

class PiquetesScreen extends ConsumerWidget {
  const PiquetesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final paddocksAsync = ref.watch(paddockListProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Piquetes')),
      body: paddocksAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: Text(
            'Erro ao carregar piquetes.',
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
        data: (paddocks) {
          if (paddocks.isEmpty) {
            return _EmptyState(canCreate: canEdit);
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            itemCount: paddocks.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (context, i) => _PaddockCard(
              paddock: paddocks[i],
              canEdit: canEdit,
              onEdit: () => _openForm(context, ref, paddock: paddocks[i]),
              onDelete: () => _confirmDelete(context, ref, paddocks[i]),
            ),
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              onPressed: () => _openForm(context, ref),
              tooltip: 'Novo piquete',
              child: const Icon(Icons.add),
            )
          : null,
    );
  }

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'owner' || role == 'veterinarian';
  }

  Future<void> _openForm(
    BuildContext context,
    WidgetRef ref, {
    Paddock? paddock,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => PaddockFormDialog(existing: paddock),
    );
    if (result == true) {
      ref.invalidate(paddockListProvider);
    }
  }

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    Paddock paddock,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remover piquete'),
        content: Text(
          'Tem certeza que deseja remover "${paddock.name}"?',
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
      await ref.read(paddockRepositoryProvider).softDeletePaddock(paddock.id);
      ref.invalidate(paddockListProvider);
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
              Icons.fence_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum piquete cadastrado',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Adicione piquetes para começar a organizar os lotes da fazenda.',
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

class _PaddockCard extends StatelessWidget {
  const _PaddockCard({
    required this.paddock,
    required this.canEdit,
    required this.onEdit,
    required this.onDelete,
  });
  final Paddock paddock;
  final bool canEdit;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        leading: const Icon(Icons.fence),
        title: Text(paddock.name),
        subtitle: Text(
          '${paddock.areaHa.toStringAsFixed(1).replaceAll('.', ',')} ha · ${paddock.uaCapacity.toStringAsFixed(1).replaceAll('.', ',')} UA',
        ),
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
