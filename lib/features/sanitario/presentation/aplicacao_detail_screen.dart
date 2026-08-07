import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../animais/data/animal_constants.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';
import 'estornar_aplicacao_dialog.dart';

/// dd/MM/yyyy, no locale symbol data needed for this numeric pattern.
final _dateFmt = DateFormat('dd/MM/yyyy');

/// Plain numeric formatting for the frozen dosage figures (mL/kg, mL/UA) —
/// distinct from [formatUa]/[formatVolumeMl]/[formatCurrencyBrl], which are
/// each shaped for a specific unit these rows don't use.
final _dosageFmt = NumberFormat('#,##0.##', 'pt_BR');

/// Read-only detail of a single frozen application (`/aplicacoes/:id`,
/// root-level per D-19) plus the veterinarian-only estorno action
/// (D-27..D-31). Reachable from three list origins (global list, lote
/// history section, animal ficha), so the back button cannot assume a push
/// stack always exists.
class AplicacaoDetailScreen extends ConsumerWidget {
  const AplicacaoDetailScreen({super.key, required this.applicationId});
  final String applicationId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appAsync = ref.watch(sanitaryApplicationByIdProvider(applicationId));

    return appAsync.when(
      loading: () => Scaffold(
        appBar: AppBar(
          title: const Text('Aplicação'),
          leading: _backButton(context),
        ),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: AppBar(
          title: const Text('Aplicação'),
          leading: _backButton(context),
        ),
        body: const Center(
          child: Text(
            'Erro ao carregar. Verifique sua conexão e tente novamente.',
          ),
        ),
      ),
      data: (app) {
        if (app == null) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Aplicação'),
              leading: _backButton(context),
            ),
            body: const Center(child: Text('Aplicação não encontrada.')),
          );
        }

        final siblings =
            ref
                .watch(sanitaryApplicationsByLotProvider(app.lotId))
                .asData
                ?.value ??
            const <SanitaryApplication>[];
        final hasBeenReversed = reversedApplicationIds(
          siblings,
        ).contains(app.id);
        final reversalRow = hasBeenReversed
            ? siblings.firstWhere((s) => s.reversesApplicationId == app.id)
            : null;

        final currentPropAsync = ref.watch(currentPropertyProvider);
        final membersAsync = ref.watch(memberPropertiesProvider);
        final canEdit = _canEdit(
          currentPropAsync.asData?.value,
          membersAsync.asData?.value,
        );

        final theme = Theme.of(context);

        return Scaffold(
          appBar: AppBar(
            leading: _backButton(context),
            title: Text(app.doseName),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AplicacaoHeaderCard(
                app: app,
                reversalRow: reversalRow,
                canEdit: canEdit,
              ),
              const SizedBox(height: 16),
              if (app.skippedCount > 0) ...[
                Text(
                  Intl.plural(
                    app.skippedCount,
                    one: '1 animal desmarcado nesta aplicação.',
                    other:
                        '${app.skippedCount} animais desmarcados nesta aplicação.',
                  ),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 16),
              ],
              _CompositionListSection(entries: app.compositionSnapshot),
            ],
          ),
        );
      },
    );
  }

  bool _canEdit(SelectedProperty? current, List<PropertyMembership>? members) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }
}

/// Back control (D-19 resolved-fallback, mirrors `LoteDetailScreen`): this
/// route has three possible origins (global list, lote section, animal
/// ficha), so it cannot assume `Navigator.canPop()` is always true.
Widget _backButton(BuildContext context) {
  return BackButton(
    onPressed: () {
      if (context.canPop()) {
        context.pop();
        return;
      }
      context.go(AppRoutes.sanitario);
    },
  );
}

/// Header card: dose name + status badge, key-value rows (lote, data,
/// dosagem, custo, observação, reversal links) and the totals line. Every
/// value below reads the frozen row — never the animal's, lot's or dose's
/// current state (D-03, D-04) — except the existence/archived check that
/// decides whether the lote row is tappable.
class _AplicacaoHeaderCard extends ConsumerWidget {
  const _AplicacaoHeaderCard({
    required this.app,
    required this.reversalRow,
    required this.canEdit,
  });

  final SanitaryApplication app;
  final SanitaryApplication? reversalRow;
  final bool canEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final lot = ref.watch(loteByIdProvider(app.lotId)).asData?.value;

    final showEstornoAction = canEdit && !app.isReversal && reversalRow == null;

    final totalsParts = <String>[
      Intl.plural(
        app.animalCount,
        one: '1 animal',
        other: '${app.animalCount} animais',
      ),
      '${formatUa(app.totalUa)} UA',
      formatVolumeMl(app.totalVolume),
      if (app.totalCost != null) formatCurrencyBrl(app.totalCost!),
    ];

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.medical_services_outlined),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(app.doseName, style: theme.textTheme.titleMedium),
                ),
                const Spacer(),
                if (reversalRow != null)
                  _StatusChip(
                    label: 'Estornada',
                    background: colorScheme.errorContainer,
                    foreground: colorScheme.onErrorContainer,
                  )
                else if (app.isReversal)
                  _StatusChip(
                    label: 'Estorno',
                    background: colorScheme.surfaceContainerHigh,
                    foreground: colorScheme.onSurface,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Lote',
              value: (lot != null && lot.deletedAt == null)
                  ? InkWell(
                      onTap: () => context.go(AppRoutes.loteDetail(lot.id)),
                      child: Text(
                        app.lotName,
                        style: TextStyle(
                          color: colorScheme.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : Text(
                      app.lotName,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data da aplicação',
              value: Text(_dateFmt.format(app.appliedAt)),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Dosagem aplicada',
              value: Text(
                '${_dosageFmt.format(app.dosagePerKg)} mL/kg '
                '(${_dosageFmt.format(app.dosagePerUa)} mL/UA)',
              ),
            ),
            if (app.costPerKg != null) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Custo',
                value: Text(
                  '${formatCurrencyBrl(app.costPerKg!)}/kg '
                  '(${formatCurrencyBrl(app.costPerUa!)}/UA)',
                ),
              ),
            ],
            if (app.notes != null && app.notes!.trim().isNotEmpty) ...[
              const SizedBox(height: 8),
              _KvRow(label: 'Observação', value: Text(app.notes!)),
            ],
            if (app.isReversal) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Estorno de',
                value: InkWell(
                  onTap: () => context.go(
                    AppRoutes.aplicacaoDetail(app.reversesApplicationId!),
                  ),
                  child: Text(
                    'Ver aplicação original',
                    style: TextStyle(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
            if (reversalRow != null) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Estornada em',
                value: InkWell(
                  onTap: () =>
                      context.go(AppRoutes.aplicacaoDetail(reversalRow!.id)),
                  child: Text(
                    '${_dateFmt.format(reversalRow!.createdAt.toLocal())} · Ver estorno',
                    style: TextStyle(
                      color: colorScheme.primary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              totalsParts.join(' · '),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            if (showEstornoAction) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => _confirmEstorno(context, ref),
                  icon: const Icon(Icons.undo),
                  label: const Text('Estornar aplicação'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: colorScheme.error,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _confirmEstorno(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => EstornarAplicacaoDialog(
        applicationId: app.id,
        doseName: app.doseName,
        lotId: app.lotId,
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.invalidate(sanitaryApplicationByIdProvider(app.id));
    ref.invalidate(sanitaryApplicationsByLotProvider(app.lotId));
    ref.invalidate(sanitaryApplicationListByPropertyProvider);
    for (final entry in app.compositionSnapshot) {
      ref.invalidate(sanitaryHistoryByAnimalProvider(entry.animalId));
    }
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Aplicação estornada.')));
  }
}

/// Small rounded status badge — mutually exclusive with its sibling, matches
/// `AtfHeaderCard`'s inline `Container` badge shape.
class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// Key-value row: label (fixed width 120) + expanded value widget.
///
/// Copied rather than shared across features — matches the codebase's
/// established duplication convention for this widget (A-KVROW-DUP).
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
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}

/// Composition section: header + one row per frozen animal. Never caps the
/// list — the header count and the row count must always agree (they are
/// literally the same array length here).
class _CompositionListSection extends StatelessWidget {
  const _CompositionListSection({required this.entries});

  final List<SanitaryCompositionEntry> entries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Composição', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '(${Intl.plural(entries.length, one: '1 animal', other: '${entries.length} animais')})',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: entries.length,
          itemBuilder: (context, i) {
            final e = entries[i];
            return ListTile(
              onTap: () => context.go(AppRoutes.animalDetail(e.animalId)),
              title: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '#${e.number}',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    TextSpan(
                      text:
                          ' · ${kCategoryLabels[e.category] ?? e.category} · '
                          '${formatUa(e.ua)} UA',
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}
