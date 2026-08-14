import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
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
      appBar: DetailAppBar(
        parentLabel: 'Fazendas',
        onBack: () {
          if (context.canPop()) {
            context.pop();
            return;
          }
          context.go(AppRoutes.dashboard);
        },
      ),
      body: propertiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(
          child: ErrorRetry(
            message: 'Erro ao carregar fazendas.',
            onRetry: () => ref.invalidate(propertyListProvider),
          ),
        ),
        data: (properties) {
          if (properties.isEmpty) {
            return const EmptyState(
              icon: Icons.landscape_outlined,
              title: 'Nenhuma fazenda cadastrada',
              message:
                  'Crie sua primeira fazenda para começar a organizar o rebanho.',
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            itemCount: properties.length,
            separatorBuilder: (context, index) => const SizedBox(height: 10),
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
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(
                context,
                ref,
                isFirstProperty: membersAsync.asData?.value.isEmpty ?? false,
              ),
              tooltip: 'Nova fazenda',
              icon: const Icon(Icons.add, size: 22),
              label: const Text('Fazenda'),
            )
          : null,
    );
  }

  bool _canEditProperties(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (members == null) return false;
    // No memberships → allow creating the first property.
    if (members.isEmpty) return true;
    if (current == null) return false;
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
    bool isFirstProperty = false,
  }) async {
    final result = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => PropertyFormDialog(existing: property),
    );
    if (result == true) {
      ref.invalidate(propertyListProvider);
      ref.invalidate(memberPropertiesProvider);
      if (isFirstProperty && context.mounted) {
        context.go(AppRoutes.dashboard);
      }
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
        title: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: AppColors.dangerContainer,
                borderRadius: BorderRadius.circular(11),
              ),
              child: const Icon(
                Icons.delete_outline,
                size: 21,
                color: AppColors.danger,
              ),
            ),
            const SizedBox(width: 12),
            const Expanded(child: Text('Remover fazenda')),
          ],
        ),
        content: Text(
          'Tem certeza que deseja remover "${property.name}"? Esta ação não pode ser desfeita.',
        ),
        actions: [
          OutlinedButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.danger,
              foregroundColor: AppColors.onDanger,
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            FarmAvatar(
              name: property.name,
              size: 40,
              background: AppColors.surfaceVariant,
              foreground: AppColors.primaryDarkText,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    property.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (property.owner != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Proprietário: ${property.owner}',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ],
              ),
            ),
            if (canEdit)
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') onEdit();
                  if (v == 'delete') onDelete();
                },
                itemBuilder: (_) => [
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text(
                      'Remover',
                      style: TextStyle(color: AppColors.danger),
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
