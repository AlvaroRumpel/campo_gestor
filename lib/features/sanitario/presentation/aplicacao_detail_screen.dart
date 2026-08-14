import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
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
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: _appBar(context),
        body: const Center(
          child: Text(
            'Erro ao carregar. Verifique sua conexão e tente novamente.',
          ),
        ),
      ),
      data: (app) {
        if (app == null) {
          return Scaffold(
            appBar: _appBar(context),
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

        final membersAsync = ref.watch(memberPropertiesProvider);
        final canEdit = _canEdit(
          app.propertyId,
          membersAsync.asData?.value,
        );

        return Scaffold(
          appBar: _appBar(context),
          body: ListView(
            padding: const EdgeInsets.all(14),
            children: [
              _AplicacaoHeaderCard(
                app: app,
                reversalRow: reversalRow,
                canEdit: canEdit,
              ),
              const SizedBox(height: 12),
              if (app.skippedCount > 0) ...[
                Text(
                  Intl.plural(
                    app.skippedCount,
                    one: '1 animal desmarcado nesta aplicação.',
                    other:
                        '${app.skippedCount} animais desmarcados nesta aplicação.',
                  ),
                  style: const TextStyle(
                    fontSize: 13.5,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
              ],
              _CompositionListSection(entries: app.compositionSnapshot),
            ],
          ),
        );
      },
    );
  }

  /// Back resolves to `/sanitario` when there is no push stack (D-19
  /// resolved-fallback, mirrors `LoteDetailScreen`).
  PreferredSizeWidget _appBar(BuildContext context) {
    return DetailAppBar(
      parentLabel: 'Sanitário',
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go(AppRoutes.sanitario);
      },
    );
  }

  bool _canEdit(String appPropertyId, List<PropertyMembership>? members) {
    if (members == null) return false;
    final role = members
        .where((m) => m.property.id == appPropertyId)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }
}

/// Header card: dose name + status chip, key-value rows (lote, data,
/// dosagem, custo, observação, reversal links) and the totals line. Every
/// value below reads the frozen row — never the animal's, lot's or dose's
/// current state (D-03, D-04) — except the existence/archived check that
/// decides whether the lote row is tappable. Numbers render in mono.
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
    final lot = ref.watch(loteByIdProvider(app.lotId)).asData?.value;

    final showEstornoAction = canEdit && !app.isReversal && reversalRow == null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(
                  Icons.medical_services_outlined,
                  color: AppColors.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    app.doseName,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      decoration: reversalRow != null
                          ? TextDecoration.lineThrough
                          : null,
                      color: reversalRow != null
                          ? AppColors.textTertiary
                          : AppColors.ink,
                    ),
                  ),
                ),
                if (reversalRow != null)
                  const StatusChip('Estornada', kind: StatusKind.danger)
                else if (app.isReversal)
                  const StatusChip('Estorno', kind: StatusKind.neutral),
              ],
            ),
            const SizedBox(height: 10),
            _KvRow(
              label: 'Lote',
              value: (lot != null && lot.deletedAt == null)
                  ? InkWell(
                      onTap: () => context.go(AppRoutes.loteDetail(lot.id)),
                      child: Text(
                        app.lotName,
                        style: const TextStyle(
                          color: AppColors.primaryDarkText,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    )
                  : Text(
                      app.lotName,
                      style: const TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data da aplicação',
              value: Text(
                _dateFmt.format(app.appliedAt),
                style: monoStyle(size: 14, weight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Dosagem aplicada',
              value: Text(
                '${_dosageFmt.format(app.dosagePerKg)} mL/kg '
                '(${_dosageFmt.format(app.dosagePerUa)} mL/UA)',
                style: monoStyle(size: 14),
              ),
            ),
            if (app.costPerKg != null) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Custo',
                value: Text(
                  '${formatCurrencyBrl(app.costPerKg!)}/kg '
                  '(${formatCurrencyBrl(app.costPerUa!)}/UA)',
                  style: monoStyle(size: 14),
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
                  child: const Text(
                    'Ver aplicação original',
                    style: TextStyle(
                      color: AppColors.primaryDarkText,
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
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: _dateFmt.format(
                            reversalRow!.createdAt.toLocal(),
                          ),
                          style: monoStyle(
                            size: 14,
                            weight: FontWeight.w600,
                            color: AppColors.primaryDarkText,
                          ),
                        ),
                        const TextSpan(
                          text: ' · Ver estorno',
                          style: TextStyle(
                            color: AppColors.primaryDarkText,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            _TotalsLine(app: app),
            if (showEstornoAction) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: () => confirmEstorno(context, ref, app),
                  icon: const Icon(Icons.undo, size: 20),
                  label: const Text('Estornar'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.danger,
                    side: const BorderSide(color: AppColors.danger),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

}

/// Totals line with the frozen aggregates, numbers mono, labels plain.
class _TotalsLine extends StatelessWidget {
  const _TotalsLine({required this.app});

  final SanitaryApplication app;

  @override
  Widget build(BuildContext context) {
    final valueStyle = monoStyle(
      size: 14.5,
      weight: FontWeight.w700,
      color: AppColors.primaryDarkText,
    );
    const labelStyle = TextStyle(
      fontSize: 14,
      fontWeight: FontWeight.w600,
      color: AppColors.primaryDarkText,
    );
    return Text.rich(
      TextSpan(
        style: labelStyle,
        children: [
          TextSpan(text: '${app.animalCount.abs()}', style: valueStyle),
          TextSpan(
            text:
                ' ${Intl.plural(app.animalCount.abs(), one: 'animal', other: 'animais')} · ',
          ),
          TextSpan(text: formatUa(app.totalUa.abs()), style: valueStyle),
          const TextSpan(text: ' UA · '),
          TextSpan(
            text: formatVolumeMl(app.totalVolume.abs()),
            style: valueStyle,
          ),
          if (app.totalCost != null) ...[
            const TextSpan(text: ' · '),
            TextSpan(
              text: formatCurrencyBrl(app.totalCost!.abs()),
              style: valueStyle,
            ),
          ],
        ],
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
          child: OverlineLabel(label),
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
    return SectionCard(
      title: 'Composição',
      trailing: Text(
        Intl.plural(
          entries.length,
          one: '1 animal',
          other: '${entries.length} animais',
        ),
        style: monoStyle(size: 13, color: AppColors.textSecondary),
      ),
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 4),
      child: ListView.builder(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        itemCount: entries.length,
        itemBuilder: (context, i) {
          final e = entries[i];
          return InkWell(
            onTap: () => context.go(AppRoutes.animalDetail(e.animalId)),
            child: Container(
              height: 48,
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: i == 0 ? Colors.transparent : AppColors.divider,
                  ),
                ),
              ),
              child: Row(
                children: [
                  SizedBox(
                    width: 52,
                    child: Text(
                      '#${e.number}',
                      style: monoStyle(size: 16, weight: FontWeight.w700),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      kCategoryLabels[e.category] ?? e.category,
                      style: const TextStyle(fontSize: 14.5),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '${formatUa(e.ua)} UA',
                    style: monoStyle(
                      size: 12.5,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
