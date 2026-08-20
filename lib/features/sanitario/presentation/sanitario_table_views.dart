import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../data/dose_model.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_calculations.dart';
import 'estornar_aplicacao_dialog.dart';

/// Tabelas densas desktop do Sanitário (quick task 260813-vvh) — a partir de
/// `Breakpoints.rail`. Larguras de coluna declaradas uma vez e reusadas pelo
/// cabeçalho e pelas linhas, molde `animais_table_view.dart`.
const _kColData = 92.0;
const _kColAnimais = 76.0;
const _kColUa = 72.0;
const _kColCusto = 104.0;
const _kColStatus = 100.0;
const _kColAcao = 44.0;
const _kFlexProduto = 3;
const _kFlexLote = 2;
const _kFlexPiquete = 2;

const _kColMlKg = 84.0;
const _kColMlUa = 92.0;
const _kColRsKg = 96.0;
const _kColRsUa = 96.0;
const _kColDoseStatus = 104.0;
const _kColDoseAcoes = 92.0;
const _kFlexDoseProduto = 3;
const _kFlexPrincipioAtivo = 3;

final _dateFmt = DateFormat('dd/MM/yyyy');

/// `#,##0.##` mL figures — mesmo par que `sanitario_screen.dart` já usa.
final NumberFormat _dosageFmt = NumberFormat('#,##0.##', 'pt_BR');

const _kDash = '—';

/// Tabela densa de Aplicações (aba "Aplicações", quick 260813-vvh). É
/// `ConsumerWidget` apenas para passar `ref` a [confirmEstorno] — não faz
/// `ref.watch` de listas, [rows] chega pronta da tela.
class AplicacoesTableView extends ConsumerWidget {
  const AplicacoesTableView({
    super.key,
    required this.rows,
    required this.reversedIds,
    required this.canEdit,
    required this.onOpen,
  });

  final List<SanitaryApplication> rows;
  final Set<String> reversedIds;
  final bool canEdit;
  final ValueChanged<SanitaryApplication> onOpen;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.surfaceVariant,
            child: const Row(
              children: [
                SizedBox(width: _kColData, child: _HeaderText('DATA')),
                Expanded(flex: _kFlexProduto, child: _HeaderText('PRODUTO')),
                Expanded(flex: _kFlexLote, child: _HeaderText('LOTE')),
                Expanded(flex: _kFlexPiquete, child: _HeaderText('PIQUETE')),
                SizedBox(
                  width: _kColAnimais,
                  child: _HeaderText('ANIMAIS', align: TextAlign.right),
                ),
                SizedBox(
                  width: _kColUa,
                  child: _HeaderText('UA', align: TextAlign.right),
                ),
                SizedBox(
                  width: _kColCusto,
                  child: _HeaderText('CUSTO', align: TextAlign.right),
                ),
                SizedBox(width: 12),
                SizedBox(
                    width: _kColStatus - 12,
                    child: _HeaderText('STATUS')),
                SizedBox(width: _kColAcao),
              ],
            ),
          ),
          Expanded(
            child: rows.isEmpty
                ? const Center(child: Text('Nenhuma aplicação encontrada.'))
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) =>
                        _buildRow(context, ref, rows[i]),
                  ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            alignment: Alignment.centerRight,
            child: Text(
              '1–${rows.length} de ${rows.length}',
              style: monoStyle(size: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(
    BuildContext context,
    WidgetRef ref,
    SanitaryApplication app,
  ) {
    final isReversed = reversedIds.contains(app.id);

    Widget? statusChip;
    if (isReversed) {
      statusChip = const StatusChip('Estornada', kind: StatusKind.danger);
    } else if (app.isReversal) {
      statusChip = const StatusChip('Estorno', kind: StatusKind.neutral);
    }

    final showEstornoAction =
        canEdit && !app.isReversal && !isReversed;

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kColData,
            child: Text(
              _dateFmt.format(app.appliedAt),
              style: monoStyle(size: 12),
            ),
          ),
          Expanded(
            flex: _kFlexProduto,
            child: Text(
              app.doseName,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                decoration: isReversed ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          Expanded(
            flex: _kFlexLote,
            child: Text(app.lotName, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexPiquete,
            child: Text(app.paddockName, overflow: TextOverflow.ellipsis),
          ),
          SizedBox(
            width: _kColAnimais,
            child: Text(
              '${app.animalCount.abs()}',
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColUa,
            child: Text(
              formatUa(app.totalUa.abs()),
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColCusto,
            child: Text(
              app.totalCost != null
                  ? formatCurrencyBrl(app.totalCost!.abs())
                  : _kDash,
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(width: _kColStatus, child: statusChip ?? const SizedBox.shrink()),
          SizedBox(
            width: _kColAcao,
            child: showEstornoAction
                ? IconButton(
                    icon: const Icon(Icons.undo, size: 18),
                    tooltip: 'Estornar aplicação',
                    onPressed: () => confirmEstorno(context, ref, app),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    return InkWell(
      hoverColor: AppColors.rowHover,
      onTap: () => onOpen(app),
      child: Opacity(opacity: isReversed ? 0.5 : 1, child: row),
    );
  }
}

/// Tabela densa do catálogo de Doses (aba "Doses", quick 260813-vvh),
/// limitada a 1040px e alinhada à esquerda — poucas linhas não justificam a
/// largura total.
class DosesTableView extends StatelessWidget {
  const DosesTableView({
    super.key,
    required this.doses,
    required this.kgPerUa,
    required this.canEdit,
    required this.onEdit,
    required this.onArchiveToggle,
  });

  final List<Dose> doses;
  final double kgPerUa;
  final bool canEdit;
  final ValueChanged<Dose> onEdit;
  final ValueChanged<Dose> onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1040),
        child: SingleChildScrollView(
          child: ColoredBox(
            color: AppColors.surface,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  constraints: const BoxConstraints(minHeight: 36),
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  color: AppColors.surfaceVariant,
                  child: const Row(
                    children: [
                      Expanded(
                        flex: _kFlexDoseProduto,
                        child: _HeaderText('PRODUTO'),
                      ),
                      Expanded(
                        flex: _kFlexPrincipioAtivo,
                        child: _HeaderText('PRINCÍPIO ATIVO'),
                      ),
                      SizedBox(
                        width: _kColMlKg,
                        child: _HeaderText('ML/KG', align: TextAlign.right),
                      ),
                      SizedBox(
                        width: _kColMlUa,
                        child: _HeaderText('ML/UA', align: TextAlign.right),
                      ),
                      SizedBox(
                        width: _kColRsKg,
                        child: _HeaderText('R\$/KG', align: TextAlign.right),
                      ),
                      SizedBox(
                        width: _kColRsUa,
                        child: _HeaderText('R\$/UA', align: TextAlign.right),
                      ),
                      SizedBox(width: 16),
                      SizedBox(
                        width: _kColDoseStatus - 16,
                        child: _HeaderText('STATUS'),
                      ),
                      SizedBox(width: _kColDoseAcoes),
                    ],
                  ),
                ),
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: doses.length,
                  itemBuilder: (context, i) => _buildRow(doses[i]),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
                  color: AppColors.surfaceVariant,
                  child: Text.rich(
                    TextSpan(
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                      children: [
                        const TextSpan(
                          text: 'Valores por UA calculados sobre ',
                        ),
                        TextSpan(
                          text: '${_dosageFmt.format(kgPerUa)} kg/UA',
                          style: monoStyle(
                            size: 11.5,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '. Doses já usadas em aplicações não podem ser '
                              'excluídas — apenas arquivadas.',
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRow(Dose dose) {
    final isArchived = dose.isArchived;
    final dosageUa = dosagePerUa(dose.dosagePerKg, kgPerUa);
    final costUa = costPerUa(dose.costPerKg, kgPerUa);

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _kFlexDoseProduto,
            child: Text(
              dose.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: _kFlexPrincipioAtivo,
            child: Text(
              dose.activeIngredient ?? _kDash,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          SizedBox(
            width: _kColMlKg,
            child: Text(
              _dosageFmt.format(dose.dosagePerKg),
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColMlUa,
            child: Text(
              _dosageFmt.format(dosageUa),
              textAlign: TextAlign.right,
              style: monoStyle(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.primaryDarkText,
              ),
            ),
          ),
          SizedBox(
            width: _kColRsKg,
            child: Text(
              dose.costPerKg != null
                  ? formatCurrencyBrl(dose.costPerKg!)
                  : _kDash,
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColRsUa,
            child: Text(
              costUa != null ? formatCurrencyBrl(costUa) : _kDash,
              textAlign: TextAlign.right,
              style: monoStyle(
                size: 13,
                weight: FontWeight.w700,
                color: AppColors.primaryDarkText,
              ),
            ),
          ),
          SizedBox(
            width: _kColDoseStatus,
            child: isArchived
                ? const StatusChip('Arquivada', kind: StatusKind.neutral)
                : const StatusChip('Ativa', kind: StatusKind.positive),
          ),
          SizedBox(
            width: _kColDoseAcoes,
            child: canEdit
                ? Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 16),
                        tooltip: 'Editar dose',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        onPressed: () => onEdit(dose),
                      ),
                      IconButton(
                        icon: Icon(
                          isArchived
                              ? Icons.unarchive_outlined
                              : Icons.archive_outlined,
                          size: 16,
                        ),
                        tooltip:
                            isArchived ? 'Reativar dose' : 'Arquivar dose',
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints.tightFor(
                          width: 28,
                          height: 28,
                        ),
                        onPressed: () => onArchiveToggle(dose),
                      ),
                    ],
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    return Opacity(opacity: isArchived ? 0.5 : 1, child: row);
  }
}

/// Texto de coluna do cabeçalho da tabela: mono 10.5px w700, caixa alta,
/// `letterSpacing 0.8` — idêntico ao de `animais_table_view.dart`.
class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label, {this.align = TextAlign.left});

  final String label;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: align,
      style: monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.primaryDarkText,
      ),
    );
  }
}
