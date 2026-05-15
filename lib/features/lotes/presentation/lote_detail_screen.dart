import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../features/animais/data/animal_constants.dart';
import '../../../features/animais/data/animal_model.dart';
import '../../../features/animais/data/animal_repository.dart';
import '../../../features/animais/presentation/animal_form_dialog.dart';
import '../../../features/auth/data/property_repository.dart';
import '../../../features/piquetes/data/piquete_repository.dart';
import '../data/lote_model.dart';
import '../data/lote_repository.dart';

class LoteDetailScreen extends ConsumerWidget {
  const LoteDetailScreen({super.key, required this.loteId});
  final String loteId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lotAsync = ref.watch(loteByIdProvider(loteId));
    final animalsAsync = ref.watch(animalListByLotProvider(loteId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return Scaffold(
      appBar: AppBar(
        title: lotAsync.when(
          data: (l) => Text(l?.name ?? 'Lote'),
          loading: () => const Text('Lote'),
          error: (e, _) => const Text('Lote'),
        ),
      ),
      body: lotAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(child: Text('Erro ao carregar lote.')),
        data: (lot) {
          if (lot == null) {
            return const Center(child: Text('Lote não encontrado.'));
          }
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _LoteHeaderCard(lot: lot, animalsAsync: animalsAsync),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Animais',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 8),
              _AnimalList(animalsAsync: animalsAsync),
            ],
          );
        },
      ),
      floatingActionButton: canEdit
          ? FloatingActionButton(
              tooltip: 'Novo animal',
              onPressed: () async {
                final lot = lotAsync.asData?.value;
                if (lot == null) return;
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (_) => AnimalFormDialog(
                    lotId: loteId,
                    propertyId: lot.propertyId,
                  ),
                );
                if (ok == true) {
                  ref.invalidate(animalListByLotProvider(loteId));
                  ref.invalidate(animalListByPropertyProvider);
                }
              },
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
    return role == 'veterinarian';
  }
}

class _LoteHeaderCard extends ConsumerWidget {
  const _LoteHeaderCard({required this.lot, required this.animalsAsync});
  final Lot lot;
  final AsyncValue<List<Animal>> animalsAsync;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final paddockAsync = ref.watch(paddockByIdProvider(lot.paddockId));
    final paddockName = paddockAsync.asData?.value?.name ?? '—';

    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.group_work_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    lot.name,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'Piquete: $paddockName',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 12),
            animalsAsync.when(
              loading: () => const SizedBox(
                height: 24,
                child: LinearProgressIndicator(),
              ),
              error: (e, _) => const Text('Erro ao carregar composição.'),
              data: (animals) {
                final active =
                    animals.where((a) => a.deletedAt == null).toList();
                if (active.isEmpty) {
                  return Text(
                    'Sem animais ativos.',
                    style: theme.textTheme.bodyMedium,
                  );
                }
                final counts = <String, int>{};
                for (final a in active) {
                  counts[a.category] = (counts[a.category] ?? 0) + 1;
                }
                final ua = calcTotalUa(active);
                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final cat
                        in kCategories.where((c) => (counts[c] ?? 0) > 0))
                      Chip(
                        label: Text(
                          '${kCategoryLabelsPlural[cat]}: ${counts[cat]} · '
                          '${(counts[cat]! * (kUaWeights[cat] ?? 0)).toStringAsFixed(1).replaceAll('.', ',')} UA',
                        ),
                      ),
                    Chip(
                      label: Text(
                        'Total: ${ua.toStringAsFixed(1).replaceAll('.', ',')} UA',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _AnimalList extends StatelessWidget {
  const _AnimalList({required this.animalsAsync});
  final AsyncValue<List<Animal>> animalsAsync;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return animalsAsync.when(
      loading: () => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: CircularProgressIndicator(),
        ),
      ),
      error: (e, _) => const Center(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Text('Erro ao carregar animais.'),
        ),
      ),
      data: (animals) {
        final active = animals.where((a) => a.deletedAt == null).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        if (active.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.pets_outlined,
                  size: 48,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                ),
                const SizedBox(height: 16),
                Text(
                  'Nenhum animal neste lote',
                  style: theme.textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  'Use o botão + para adicionar animais individualmente.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }
        return Column(
          children: [
            for (final a in active)
              ListTile(
                onTap: () => context.go(AppRoutes.animalDetail(a.id)),
                title: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '#${a.number}',
                        style: theme.textTheme.bodyLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text:
                            ' · ${kCategoryLabels[a.category] ?? a.category}',
                        style: theme.textTheme.bodyLarge,
                      ),
                    ],
                  ),
                ),
                subtitle: _buildSubtitle(a, theme),
              ),
          ],
        );
      },
    );
  }

  Widget? _buildSubtitle(Animal a, ThemeData theme) {
    final parts = <String>[];
    if (a.breed != null && a.breed!.isNotEmpty) parts.add(a.breed!);
    if (a.bodyCondition != null) parts.add('EC ${a.bodyCondition}');
    if (parts.isEmpty) return null;
    return Text(
      parts.join(' · '),
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
