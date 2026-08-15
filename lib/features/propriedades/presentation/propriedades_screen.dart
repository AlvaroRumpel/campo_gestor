import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/role_gates.dart';
import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../../features/auth/data/property_repository.dart';
import '../data/propriedade_model.dart';
import '../data/propriedade_repository.dart';
import 'archive_confirm_dialog.dart';
import 'property_form_dialog.dart';

class PropriedadesScreen extends ConsumerStatefulWidget {
  const PropriedadesScreen({super.key});

  @override
  ConsumerState<PropriedadesScreen> createState() =>
      _PropriedadesScreenState();
}

class _PropriedadesScreenState extends ConsumerState<PropriedadesScreen> {
  // PROPV-02: aba Ativas é a padrão ao montar.
  bool _showArchived = false;

  @override
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(propertyListProvider);
    final archivedAsync = ref.watch(archivedPropertyListProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    // G-10-04: the archived query is already veterinarian-scoped
    // (fetchArchivedProperties), so "has something archived" doubles as the
    // role gate — a reader/owner always resolves an empty list here, and the
    // alternador (plus Restaurar) disappears with it, per role_gates.dart's
    // convention of an absent control rather than a disabled one.
    final canSeeArchived = archivedAsync.asData?.value.isNotEmpty ?? false;
    final showArchived = _showArchived && canSeeArchived;

    final canEdit = _canEditProperties(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );
    final canManageMembersHere = canManageMembers(
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
      body: Column(
        children: [
          if (canSeeArchived)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 10, 14, 6),
              child: Row(
                children: [
                  _ScopeChip(
                    label: 'Ativas',
                    selected: !showArchived,
                    onTap: () => setState(() => _showArchived = false),
                  ),
                  const SizedBox(width: 8),
                  _ScopeChip(
                    label: 'Arquivadas',
                    selected: showArchived,
                    onTap: () => setState(() => _showArchived = true),
                  ),
                ],
              ),
            ),
          Expanded(
            child: (showArchived ? archivedAsync : activeAsync).when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, _) => Center(
                child: ErrorRetry(
                  message: 'Erro ao carregar fazendas.',
                  onRetry: () => ref.invalidate(
                    showArchived
                        ? archivedPropertyListProvider
                        : propertyListProvider,
                  ),
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  itemCount: properties.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 10),
                  itemBuilder: (context, i) => _PropertyCard(
                    property: properties[i],
                    canEdit: canEdit,
                    canManageMembers: canManageMembersHere,
                    archived: showArchived,
                    onEdit: () => _openForm(property: properties[i]),
                    onArchive: () => _confirmArchive(properties[i]),
                    onRestore: () => _restore(properties[i]),
                    onMembers: () =>
                        context.push(AppRoutes.membros(properties[i].id)),
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: canEdit && !showArchived
          ? FloatingActionButton.extended(
              onPressed: () => _openForm(
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

  Future<void> _openForm({
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
      if (isFirstProperty && mounted) {
        context.go(AppRoutes.dashboard);
      }
    }
  }

  Future<void> _confirmArchive(Property property) async {
    final confirmed = await showAdaptiveForm<bool>(
      context: context,
      width: FormWidth.confirm,
      builder: (_) => ArchiveConfirmDialog(propertyName: property.name),
    );
    if (confirmed != true) return;
    try {
      await ref
          .read(propertyRepositoryProvider)
          .softDeleteProperty(property.id);
      ref.invalidate(propertyListProvider);
      ref.invalidate(archivedPropertyListProvider);
      ref.invalidate(memberPropertiesProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao arquivar a fazenda. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _restore(Property property) async {
    try {
      await ref.read(propertyRepositoryProvider).restoreProperty(property.id);
      ref.invalidate(propertyListProvider);
      ref.invalidate(archivedPropertyListProvider);
      ref.invalidate(memberPropertiesProvider);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao restaurar a fazenda. Tente novamente.'),
        ),
      );
    }
  }
}

/// Alternador de escopo Ativas/Arquivadas — visual de `_PeriodChip`
/// (`gastos_property_screen.dart`), redeclarado localmente porque aquela
/// classe é privada de outro arquivo.
class _ScopeChip extends StatelessWidget {
  const _ScopeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : AppColors.surfaceVariant,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 13,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onGreen : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _PropertyCard extends StatelessWidget {
  const _PropertyCard({
    required this.property,
    required this.canEdit,
    required this.canManageMembers,
    required this.onEdit,
    required this.onArchive,
    required this.onRestore,
    required this.onMembers,
    this.archived = false,
  });
  final Property property;
  final bool canEdit;
  final bool canManageMembers;
  final bool archived;
  final VoidCallback onEdit;
  final VoidCallback onArchive;
  final VoidCallback onRestore;
  final VoidCallback onMembers;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
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
          if (archived)
            FilledButton.icon(
              onPressed: onRestore,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: AppColors.onAccent,
              ),
              icon: const Icon(Icons.unarchive_outlined, size: 18),
              label: const Text('Restaurar fazenda'),
            )
          else if (!archived && (canEdit || canManageMembers))
            PopupMenuButton<String>(
              onSelected: (v) {
                if (v == 'members') onMembers();
                if (v == 'edit') onEdit();
                if (v == 'archive') onArchive();
              },
              itemBuilder: (_) => [
                if (canManageMembers)
                  const PopupMenuItem(value: 'members', child: Text('Membros')),
                if (canEdit) ...[
                  const PopupMenuItem(value: 'edit', child: Text('Editar')),
                  const PopupMenuItem(
                    value: 'archive',
                    child: Text(
                      'Arquivar',
                      style: TextStyle(color: AppColors.danger),
                    ),
                  ),
                ],
              ],
            ),
        ],
      ),
    );

    // Cartão arquivado esmaecido — mesmo tratamento das aplicações
    // sanitárias arquivadas (Fase 9).
    return Card(child: archived ? Opacity(opacity: 0.6, child: content) : content);
  }
}
