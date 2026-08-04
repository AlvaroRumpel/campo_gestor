import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../animais/data/animal_constants.dart';
import '../../auth/data/property_repository.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';
import 'atf_animal_selection_screen.dart';

/// ATF detail screen (`/atf/:atfId`, root-level per D-02).
///
/// This plan (05-04) built the shell + [AtfHeaderCard]. Plan 05-06 adds
/// [_CompositionSection] and the remove-animal flow. DG entry and the
/// encerramento banner/action are added in later waves (05-08, 05-09) that
/// edit this same file.
class AtfDetailScreen extends ConsumerWidget {
  const AtfDetailScreen({super.key, required this.atfId});
  final String atfId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atfAsync = ref.watch(atfByIdProvider(atfId));
    final membershipsAsync = ref.watch(atfActiveMembershipsProvider(atfId));
    final dgRecordsAsync = ref.watch(dgRecordsByAtfProvider(atfId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return atfAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(title: const Text('ATF')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: AppBar(title: const Text('ATF')),
        body: const Center(
          child: Text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
        ),
      ),
      data: (atf) {
        if (atf == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('ATF')),
            body: const Center(
              child: Text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(atf.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AtfHeaderCard(
                atf: atf,
                activeMemberships: membershipsAsync.asData?.value ?? const [],
                dgRecords: dgRecordsAsync.asData?.value ?? const [],
              ),
              const SizedBox(height: 16),
              _CompositionSection(
                atf: atf,
                activeMemberships: membershipsAsync.asData?.value ?? const [],
                dgRecords: dgRecordsAsync.asData?.value ?? const [],
                canEdit: canEdit,
              ),
            ],
          ),
        );
      },
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
    return role == 'veterinarian';
  }
}

/// Header card: ATF name + status badge, key-value rows (implantação,
/// inseminação, touro, observação), and the % prenhez indicator (REPR-04).
class AtfHeaderCard extends StatelessWidget {
  const AtfHeaderCard({
    super.key,
    required this.atf,
    required this.activeMemberships,
    required this.dgRecords,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> activeMemberships;
  final List<DgRecord> dgRecords;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    final summary = summarizeDg(
      dgRecords,
      compositionCount: activeMemberships.length,
    );
    final compositionCount = activeMemberships.length;
    final progress = compositionCount == 0
        ? 0.0
        : (summary.total / compositionCount).clamp(0.0, 1.0);

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_border),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(atf.name, style: theme.textTheme.titleMedium),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    atf.active ? 'Ativo' : 'Encerrado',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data de implantação',
              value: Text(dateFmt.format(atf.implantationDate)),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data de inseminação',
              value: Text(dateFmt.format(atf.inseminationDate)),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Touro',
              value: _buildBullValue(context),
            ),
            if (atf.observation != null) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Observação',
                value: Text(atf.observation!),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              formatPrenhez(summary),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }

  Widget _buildBullValue(BuildContext context) {
    if (atf.bullAnimalId != null) {
      return InkWell(
        onTap: () => context.go(AppRoutes.animalDetail(atf.bullAnimalId!)),
        child: Text(
          atf.bullName ?? atf.bullAnimalId!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    return Text(atf.bullName ?? '—');
  }
}

/// Key-value row: label (fixed width 120) + expanded value widget.
///
/// Copied from `animal_detail_screen.dart`'s `_KvRow` rather than shared
/// across features — matches the codebase's established duplication
/// convention for this widget (A-KVROW-DUP).
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}

/// Composition section (D-06/D-07/D-08, REPR-02): the active membership list
/// plus the "+ Animais" affordance and the remove-animal flow.
///
/// Renders from already-resolved lists (mirrors [AtfHeaderCard]'s
/// convention) rather than watching the providers itself — 05-UI-SPEC E5
/// "loading/error inherited from the parent screen, no independent spinner".
class _CompositionSection extends ConsumerWidget {
  const _CompositionSection({
    required this.atf,
    required this.activeMemberships,
    required this.dgRecords,
    required this.canEdit,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> activeMemberships;
  final List<DgRecord> dgRecords;
  final bool canEdit;

  void _openSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AtfAnimalSelectionScreen(atfId: atf.id, atfName: atf.name),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AtfMembershipView membership,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveAnimalConfirmDialog(
        animalNumber: membership.animalNumber,
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(atfRepositoryProvider).removeAnimalFromAtf(
            atfBatchId: atf.id,
            animalId: membership.animalId,
          );
      if (!context.mounted) return;
      ref.invalidate(atfActiveMembershipsProvider(atf.id));
      ref.invalidate(atfMembershipsProvider(atf.id));
      ref.invalidate(atfListByPropertyProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover animal. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showAddButton = atf.active && canEdit;
    final dgAnimalIds = dgRecords.map((d) => d.animalId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Composição', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '(${activeMemberships.length} animais)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (showAddButton)
              OutlinedButton.icon(
                onPressed: () => _openSelection(context),
                icon: const Icon(Icons.add),
                label: const Text('Animais'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeMemberships.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nenhum animal neste ATF.',
                style: theme.textTheme.bodyMedium,
              ),
              if (showAddButton) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _openSelection(context),
                  child: const Text('Adicionar animais'),
                ),
              ],
            ],
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeMemberships.length,
            itemBuilder: (context, i) {
              final m = activeMemberships[i];
              final hasDg = dgAnimalIds.contains(m.animalId);
              final canRemove = atf.active && canEdit && !hasDg;
              return ListTile(
                title: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '#${m.animalNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text:
                            ' · ${kCategoryLabels[m.animalCategory] ?? m.animalCategory}',
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () => context.go(AppRoutes.animalDetail(m.animalId)),
                trailing: canRemove
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Remover do ATF',
                        onPressed: () => _confirmRemove(context, ref, m),
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }
}

/// Minimal confirm dialog for removing an animal from the ATF (D-08).
///
/// Unlike [BaixaDialog], this is a correction, not data loss — the confirm
/// button keeps the default primary color rather than `colorScheme.error`.
class _RemoveAnimalConfirmDialog extends StatelessWidget {
  const _RemoveAnimalConfirmDialog({required this.animalNumber});

  final int animalNumber;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Remover #$animalNumber do ATF?'),
      content: const Text('O animal deixa de fazer parte deste ciclo.'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: const Text('Remover'),
        ),
      ],
    );
  }
}
