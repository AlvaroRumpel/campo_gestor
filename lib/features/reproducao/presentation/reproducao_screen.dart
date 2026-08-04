import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../auth/data/property_repository.dart';
import '../data/atf_repository.dart';
import '../data/dg_summary.dart';
import 'atf_form_dialog.dart';

/// ATF list screen (`/reproducao` shell branch, D-01). Replaces the Phase 0
/// placeholder.
///
/// Separates active from closed ATFs via a "Mostrar encerrados" toggle
/// (D-01, D-03) — same field-and-Switch pattern `AnimaisScreen` uses for
/// "Mostrar arquivados".
class ReproducaoScreen extends ConsumerStatefulWidget {
  const ReproducaoScreen({super.key});

  @override
  ConsumerState<ReproducaoScreen> createState() => _ReproducaoScreenState();
}

class _ReproducaoScreenState extends ConsumerState<ReproducaoScreen> {
  bool _showEncerrados = false;

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

  @override
  Widget build(BuildContext context) {
    final atfsAsync = ref.watch(atfListByPropertyProvider);
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final currentProperty = currentPropAsync.asData?.value;
    final canEdit = _canEdit(currentProperty, membersAsync.asData?.value);

    return Scaffold(
      appBar: AppBar(title: const Text('Reprodução')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Text('Mostrar encerrados'),
                Switch(
                  value: _showEncerrados,
                  onChanged: (v) => setState(() => _showEncerrados = v),
                ),
              ],
            ),
          ),
          Expanded(
            child: atfsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, st) => const Center(
                child: Text(
                  'Erro ao carregar. Verifique sua conexão e tente novamente.',
                ),
              ),
              data: (atfs) {
                final filtered = _showEncerrados
                    ? atfs
                    : atfs.where((s) => s.atf.active).toList();

                if (filtered.isEmpty) {
                  return atfs.isEmpty
                      ? const _EmptyNoAtfsState()
                      : const _EmptyFilteredState();
                }

                return ListView.builder(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  itemCount: filtered.length,
                  itemBuilder: (context, i) => _AtfCard(summary: filtered[i]),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: (canEdit && currentProperty != null)
          ? FloatingActionButton(
              tooltip: 'Novo ATF',
              onPressed: () async {
                final newId = await showDialog<String>(
                  context: context,
                  builder: (_) =>
                      AtfFormDialog(propertyId: currentProperty.id),
                );
                if (newId != null && context.mounted) {
                  context.go(AppRoutes.atfDetail(newId));
                }
              },
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

/// One ATF row (D-04). Title + summary line + progress line, driven
/// exclusively by [formatPrenhez] — no local percentage arithmetic.
class _AtfCard extends StatelessWidget {
  const _AtfCard({required this.summary});

  final AtfSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd/MM');
    final atf = summary.atf;

    final progress = summary.animalCount == 0
        ? 0.0
        : (summary.dgSummary.total / summary.animalCount).clamp(0.0, 1.0);

    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => context.go(AppRoutes.atfDetail(atf.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      atf.name,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (!atf.active) ...[
                    const SizedBox(width: 8),
                    Chip(
                      label: const Text('Encerrado'),
                      backgroundColor: colorScheme.surfaceContainerHigh,
                      labelStyle: TextStyle(color: colorScheme.onSurface),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'impl. ${dateFmt.format(atf.implantationDate)} · '
                'insem. ${dateFmt.format(atf.inseminationDate)} · '
                '${summary.animalCount} animais',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              Text(
                formatPrenhez(summary.dgSummary),
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: colorScheme.primary,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              LinearProgressIndicator(value: progress),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyNoAtfsState extends StatelessWidget {
  const _EmptyNoAtfsState();

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
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum ATF cadastrado',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Crie um ATF para iniciar um ciclo reprodutivo.',
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

class _EmptyFilteredState extends StatelessWidget {
  const _EmptyFilteredState();

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
              Icons.favorite_border,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhum ATF ativo',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              "Ative 'Mostrar encerrados' para ver o histórico.",
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
