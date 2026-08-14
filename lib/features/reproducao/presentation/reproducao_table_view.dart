import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../data/atf_repository.dart';

/// Tabela mestre-detalhe desktop de ciclos ATF (quick task 260813-r4s) —
/// a partir de `Breakpoints.rail`. Larguras de coluna declaradas uma vez e
/// reusadas pelo cabeçalho e pelas linhas, seguindo `animais_table_view.dart`.
const _kColImplante = 82.0;
const _kColInsem = 82.0;
const _kColFemeas = 68.0;
const _kColDgs = 84.0;
const _kColPrenhez = 132.0;
const _kColStatus = 148.0;
const _kFlexAtf = 3;
const _kFlexTouro = 2;

final _dateFmtShort = DateFormat('dd/MM/yy');

class ReproducaoTableView extends StatelessWidget {
  const ReproducaoTableView({
    super.key,
    required this.ativos,
    required this.encerrados,
    required this.shown,
    required this.showEncerrados,
    required this.onShowEncerradosChanged,
    required this.selectedId,
    required this.onSelect,
    required this.canEdit,
    required this.onCreate,
  });

  final List<AtfSummary> ativos;
  final List<AtfSummary> encerrados;
  final List<AtfSummary> shown;
  final bool showEncerrados;
  final ValueChanged<bool> onShowEncerradosChanged;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final bool canEdit;
  final VoidCallback onCreate;

  String _subtitle() {
    final pendentes = ativos.fold<int>(0, (a, s) => a + s.dgSummary.pending);
    final ativosWord = ativos.length == 1 ? 'ciclo ativo' : 'ciclos ativos';
    final encerradosWord = encerrados.length == 1 ? 'encerrado' : 'encerrados';
    final pendentesWord = pendentes == 1 ? 'DG pendente' : 'DGs pendentes';
    return '${ativos.length} $ativosWord · ${encerrados.length} '
        '$encerradosWord · $pendentes $pendentesWord';
  }

  String _emptyMessage() {
    if (ativos.isEmpty && encerrados.isEmpty) return 'Nenhum ATF cadastrado';
    return showEncerrados ? 'Nenhum ATF encerrado' : 'Nenhum ATF ativo';
  }

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Reprodução',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(),
                        style: monoStyle(
                          size: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                if (canEdit) ...[
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: onCreate,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Novo ATF'),
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Row(
              children: [
                AtfScopeChip(
                  label: 'Ativos',
                  count: ativos.length,
                  selected: !showEncerrados,
                  onTap: () => onShowEncerradosChanged(false),
                ),
                const SizedBox(width: 8),
                AtfScopeChip(
                  label: 'Encerrados',
                  count: encerrados.length,
                  selected: showEncerrados,
                  onTap: () => onShowEncerradosChanged(true),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.surfaceVariant,
            child: const Row(
              children: [
                Expanded(flex: _kFlexAtf, child: _HeaderText('ATF')),
                SizedBox(
                  width: _kColImplante,
                  child: _HeaderText('IMPLANTE'),
                ),
                SizedBox(
                  width: _kColInsem,
                  child: _HeaderText('INSEMIN.'),
                ),
                Expanded(flex: _kFlexTouro, child: _HeaderText('TOURO')),
                SizedBox(
                  width: _kColFemeas,
                  child: _HeaderText('FÊMEAS', align: TextAlign.right),
                ),
                SizedBox(
                  width: _kColDgs,
                  child: _HeaderText('DGS', align: TextAlign.right),
                ),
                SizedBox(
                  width: _kColPrenhez,
                  child: _HeaderText('PRENHEZ'),
                ),
                SizedBox(
                  width: _kColStatus,
                  child: _HeaderText('STATUS'),
                ),
              ],
            ),
          ),
          Expanded(
            child: shown.isEmpty
                ? Center(child: Text(_emptyMessage()))
                : ListView.builder(
                    itemCount: shown.length,
                    itemBuilder: (context, i) => _buildRow(shown[i]),
                  ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            alignment: Alignment.centerRight,
            child: Text(
              '1–${shown.length} de ${ativos.length + encerrados.length}',
              style: monoStyle(size: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(AtfSummary s) {
    final atf = s.atf;
    final dg = s.dgSummary;
    final selected = atf.id == selectedId;
    // Same rule as _AtfCard: closed ATFs report zero active memberships, so
    // the denominator never falls below the DG total already recorded.
    final denominator = math.max(s.animalCount, dg.total);
    final percent = dg.percent;
    final hasPending = atf.active && dg.pending > 0;

    final row = Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: selected ? AppColors.rowSelected : null,
        border: Border(
          left: BorderSide(
            color: selected ? AppColors.primary : Colors.transparent,
            width: 3,
          ),
          bottom: const BorderSide(color: AppColors.divider),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            flex: _kFlexAtf,
            child: Text(
              atf.name,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          SizedBox(
            width: _kColImplante,
            child: Text(
              _dateFmtShort.format(atf.implantationDate),
              style: monoStyle(size: 12.5),
            ),
          ),
          SizedBox(
            width: _kColInsem,
            child: Text(
              _dateFmtShort.format(atf.inseminationDate),
              style: monoStyle(size: 12.5),
            ),
          ),
          Expanded(
            flex: _kFlexTouro,
            child: Text(
              atf.bullName ?? '—',
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _kColFemeas,
            child: Text(
              '${s.animalCount}',
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColDgs,
            child: Text(
              '${dg.total} / $denominator',
              textAlign: TextAlign.right,
              style: monoStyle(size: 13),
            ),
          ),
          SizedBox(
            width: _kColPrenhez,
            child: Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  StackedBar(
                    height: 6,
                    segments: denominator == 0
                        ? const []
                        : [
                            StackedBarSegment(
                              dg.pregnant / denominator,
                              AppColors.primary,
                            ),
                            StackedBarSegment(
                              (dg.total - dg.pregnant) / denominator,
                              AppColors.accent,
                            ),
                          ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    percent == null ? '—' : '$percent%',
                    style: monoStyle(
                      size: 12,
                      weight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          SizedBox(
            width: _kColStatus,
            child: !atf.active
                ? const StatusChip('Encerrado', kind: StatusKind.neutral)
                : hasPending
                    ? StatusChip(
                        dg.pending == 1
                            ? '1 DG pendente'
                            : '${dg.pending} DGs pendentes',
                        kind: StatusKind.warning,
                      )
                    : dg.total > 0
                        ? const StatusChip('Completo', kind: StatusKind.positive)
                        : const SizedBox.shrink(),
          ),
        ],
      ),
    );

    return InkWell(
      hoverColor: AppColors.rowHover,
      onTap: () => onSelect(atf.id),
      child: row,
    );
  }
}

/// Chip de escopo Ativos/Encerrados com contagem mono embutida (spec 3.5,
/// era `_FilterCountChip` privado em `reproducao_screen.dart`). Mesma
/// implementação nas duas larguras — mobile e desktop.
class AtfScopeChip extends StatelessWidget {
  const AtfScopeChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onTap(),
      // Text + Text separados (não Text.rich com um único TextSpan): mantém
      // `label` como texto exato-igual (`find.text(label)`), condição de
      // que widgets consumidores (ex.: PiquetesScreen desktop) dependem
      // para localizar o chip por nome sem ambiguidade com a contagem.
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
              color: selected ? AppColors.onGreen : AppColors.ink,
            ),
          ),
          Text(
            ' $count',
            style: monoStyle(
              size: 11.5,
              weight: FontWeight.w600,
              color: selected
                  ? AppColors.onGreenSecondary
                  : AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Texto de coluna do cabeçalho da tabela: mono 10.5px w700, caixa alta,
/// `letterSpacing 0.8` — idêntico a `_HeaderText` de `animais_table_view.dart`.
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
