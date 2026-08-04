import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';

/// ATF detail screen (`/atf/:atfId`, root-level per D-02).
///
/// This plan (05-04) builds the shell + [AtfHeaderCard] only. Composition,
/// DG entry, and the encerramento banner/action are added in later waves
/// (05-06, 05-08, 05-09) that edit this same file — no placeholder is left
/// for them, the header-only screen is complete and useful on its own.
class AtfDetailScreen extends ConsumerWidget {
  const AtfDetailScreen({super.key, required this.atfId});
  final String atfId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atfAsync = ref.watch(atfByIdProvider(atfId));
    final membershipsAsync = ref.watch(atfActiveMembershipsProvider(atfId));
    final dgRecordsAsync = ref.watch(dgRecordsByAtfProvider(atfId));

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
            ],
          ),
        );
      },
    );
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
