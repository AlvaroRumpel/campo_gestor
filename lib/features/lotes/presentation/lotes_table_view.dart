import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../piquetes/data/piquete_model.dart';
import '../../piquetes/presentation/piquetes_lotes_header.dart';
import '../data/lote_repository.dart';

/// Tabela mestre-detalhe desktop de lotes (quick task 260813-ugd) — a partir
/// de `Breakpoints.rail`. Molde: `reproducao_table_view.dart`. Larguras de
/// coluna declaradas uma vez e reusadas pelo cabeçalho e pelas linhas.
const _kColCab = 56.0;
const _kColUa = 76.0;
const _kColUltima = 108.0;
const _kColAlerta = 132.0;
const _kFlexLote = 3;
const _kFlexPiquete = 2;
const _kFlexComposicao = 4;

final _dateFmtShort = DateFormat('dd/MM/yy');

String _fmt1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

class LotesTableView extends StatefulWidget {
  const LotesTableView({
    super.key,
    required this.lots,
    required this.animalsByLot,
    required this.paddocks,
    required this.overloadedPaddockIds,
    required this.lastApplicationByLot,
    required this.paddockCount,
    required this.lotCount,
    required this.showLots,
    required this.onShowLotsChanged,
    required this.selectedId,
    required this.onSelect,
    required this.canEdit,
    required this.onCreate,
  });

  final List<LotWithPaddockCount> lots;
  final Map<String, List<Animal>> animalsByLot;
  final List<Paddock> paddocks;
  final Set<String> overloadedPaddockIds;
  final Map<String, DateTime> lastApplicationByLot;
  final int paddockCount;
  final int lotCount;
  final bool showLots;
  final ValueChanged<bool> onShowLotsChanged;
  final String? selectedId;
  final ValueChanged<String?> onSelect;
  final bool canEdit;
  final VoidCallback onCreate;

  @override
  State<LotesTableView> createState() => _LotesTableViewState();
}

class _LotesTableViewState extends State<LotesTableView> {
  // Default false = UA desc, matching the spec's default sort.
  bool _uaAsc = false;

  double _uaFor(LotWithPaddockCount item) =>
      calcTotalUa(widget.animalsByLot[item.lot.id] ?? const []);

  @override
  Widget build(BuildContext context) {
    final sorted = [...widget.lots]
      ..sort((a, b) {
        final cmp = _uaFor(a).compareTo(_uaFor(b));
        final ordered = _uaAsc ? cmp : -cmp;
        return ordered != 0 ? ordered : a.lot.name.compareTo(b.lot.name);
      });

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PiquetesLotesHeader(
            paddocks: widget.paddocks,
            animalsByLot: widget.animalsByLot,
            paddockCount: widget.paddockCount,
            lotCount: widget.lotCount,
            showLots: widget.showLots,
            onShowLotsChanged: widget.onShowLotsChanged,
            action: widget.canEdit
                ? FilledButton.icon(
                    onPressed: widget.onCreate,
                    icon: const Icon(Icons.add, size: 20),
                    label: const Text('Novo lote'),
                  )
                : null,
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 36),
            padding: const EdgeInsets.symmetric(horizontal: 14),
            color: AppColors.surfaceVariant,
            child: Row(
              children: [
                const Expanded(flex: _kFlexLote, child: _HeaderText('LOTE')),
                const Expanded(
                  flex: _kFlexPiquete,
                  child: _HeaderText('PIQUETE'),
                ),
                const Expanded(
                  flex: _kFlexComposicao,
                  child: _HeaderText('COMPOSIÇÃO'),
                ),
                const SizedBox(
                  width: _kColCab,
                  child: _HeaderText('CAB.', align: TextAlign.right),
                ),
                SizedBox(
                  width: _kColUa,
                  child: InkWell(
                    onTap: () => setState(() => _uaAsc = !_uaAsc),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        const _HeaderText('UA', align: TextAlign.right),
                        Icon(
                          _uaAsc ? Icons.arrow_drop_up : Icons.arrow_drop_down,
                          size: 16,
                          color: AppColors.primaryDarkText,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(
                  width: _kColUltima,
                  child: _HeaderText('ÚLT. APLICAÇÃO'),
                ),
                const SizedBox(
                  width: _kColAlerta,
                  child: _HeaderText('ALERTA'),
                ),
              ],
            ),
          ),
          Expanded(
            child: sorted.isEmpty
                ? const EmptyState(
                    icon: Icons.group_work_outlined,
                    title: 'Nenhum lote cadastrado',
                    message: 'Crie um lote para começar a registrar animais.',
                  )
                : ListView.builder(
                    itemCount: sorted.length,
                    itemBuilder: (context, i) => _buildRow(sorted[i]),
                  ),
          ),
          Container(
            constraints: const BoxConstraints(minHeight: 34),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            color: AppColors.surfaceVariant,
            alignment: Alignment.centerRight,
            child: Text(
              '1–${sorted.length} de ${sorted.length}',
              style: monoStyle(size: 11.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(LotWithPaddockCount item) {
    final selected = item.lot.id == widget.selectedId;
    final animals = widget.animalsByLot[item.lot.id] ?? const <Animal>[];
    final counts = <String, int>{};
    for (final a in animals) {
      counts[a.category] = (counts[a.category] ?? 0) + 1;
    }
    final presentCats =
        kCategories.where((c) => (counts[c] ?? 0) > 0).toList();
    final shownCats = presentCats.take(3).toList();
    final extra = presentCats.length - shownCats.length;
    final ua = calcTotalUa(animals);
    final lastApplication = widget.lastApplicationByLot[item.lot.id];
    final overloaded = widget.overloadedPaddockIds.contains(item.lot.paddockId);

    return InkWell(
      hoverColor: AppColors.rowHover,
      onTap: () => widget.onSelect(item.lot.id),
      child: Container(
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
              flex: _kFlexLote,
              child: Text(
                item.lot.name,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            Expanded(
              flex: _kFlexPiquete,
              child: Text(
                item.paddockName,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Expanded(
              flex: _kFlexComposicao,
              child: ClipRect(
                child: Row(
                  children: [
                    for (final cat in shownCats) ...[
                      _CatChip(
                        count: counts[cat]!,
                        label: counts[cat] == 1
                            ? kCategoryLabels[cat]!
                            : kCategoryLabelsPlural[cat]!,
                      ),
                      const SizedBox(width: 4),
                    ],
                    if (extra > 0) _CatChip(count: extra),
                  ],
                ),
              ),
            ),
            SizedBox(
              width: _kColCab,
              child: Text(
                '${animals.length}',
                textAlign: TextAlign.right,
                style: monoStyle(size: 13),
              ),
            ),
            SizedBox(
              width: _kColUa,
              child: Text(
                _fmt1(ua),
                textAlign: TextAlign.right,
                style: monoStyle(size: 13, weight: FontWeight.w700),
              ),
            ),
            SizedBox(
              width: _kColUltima,
              child: lastApplication == null
                  ? const Text(
                      'sem registro',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: AppColors.textTertiary,
                      ),
                    )
                  : Text(
                      _dateFmtShort.format(lastApplication),
                      style: monoStyle(size: 12.5),
                    ),
            ),
            SizedBox(
              width: _kColAlerta,
              child: overloaded
                  ? const StatusChip('Piquete lotado', kind: StatusKind.danger)
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip compacto de composição por categoria — "3 Vacas" quando [label] é
/// informado, "+N" (sem label) quando representa categorias excedentes.
class _CatChip extends StatelessWidget {
  const _CatChip({required this.count, this.label});

  final int count;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(8),
      ),
      child: label == null
          ? Text('+$count', style: monoStyle(size: 12, weight: FontWeight.w600))
          : Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$count ',
                    style: monoStyle(size: 12, weight: FontWeight.w600),
                  ),
                  TextSpan(
                    text: label,
                    style: const TextStyle(fontSize: 12, color: AppColors.ink),
                  ),
                ],
              ),
            ),
    );
  }
}

/// Texto de coluna do cabeçalho da tabela: mono 10.5px w700, caixa alta,
/// `letterSpacing 0.8` — idêntico a `_HeaderText` de `reproducao_table_view.dart`.
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
