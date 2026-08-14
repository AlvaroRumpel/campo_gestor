import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/atf_model.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';
import 'atf_animal_selection_screen.dart';

/// Larguras de coluna declaradas uma vez e reusadas pelo cabeçalho e pelas
/// linhas (mesma convenção de `animais_table_view.dart`/`reproducao_table_view.dart`).
/// A coluna de checkbox e o conteúdo da célula RESULTADO entram na Task 2
/// (quick task 260813-tos) — aqui só a largura final é reservada.
const _kColNumber = 72.0;
const _kColIa = 82.0;
const _kColDg = 82.0;
const _kColResultado = 250.0;
const _kFlexCategoria = 2;
const _kFlexLote = 2;

final _dateFmtShort = DateFormat('dd/MM/yy');
final _iaSubtitleFmt = DateFormat('dd/MM');

/// Tabela desktop densa do detalhe do ATF (>=`Breakpoints.rail`, quick task
/// 260813-tos): registro de DG inline por linha + seleção múltipla com barra
/// contextual, sobre o mesmo `saveDgRecords`/`removeAnimalFromAtf` que o
/// fluxo mobile usa. Abaixo do corte, `AtfDetailScreen` renderiza o fluxo de
/// hoje sem uma linha alterada — este widget é dono de tudo a partir dele.
class AtfDgTableView extends ConsumerStatefulWidget {
  const AtfDgTableView({
    super.key,
    required this.atf,
    required this.rows,
    required this.activeMemberships,
    required this.dgRecords,
    required this.pendingMembers,
    required this.canEdit,
  });

  final AtfBatch atf;

  /// Roster completo (memberships menos animalDeleted, G-05-2/D-16) — o
  /// pai já filtra, nunca por `active` (D-16: correção continua possível
  /// depois do encerramento).
  final List<AtfMembershipView> rows;
  final List<AtfMembershipView> activeMemberships;
  final List<DgRecord> dgRecords;

  /// Contagem por membro ATUAL sem DG (G-05-3) — a mesma que o AppBar e o
  /// diálogo de encerrar já usam, nunca `summarizeDg(...).pending`.
  final int pendingMembers;
  final bool canEdit;

  @override
  ConsumerState<AtfDgTableView> createState() => _AtfDgTableViewState();
}

class _AtfDgTableViewState extends ConsumerState<AtfDgTableView> {
  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(animalListByPropertyProvider);
    final animalsById = <String, AnimalWithContext>{
      for (final aw
          in animalsAsync.asData?.value ?? const <AnimalWithContext>[])
        aw.animal.id: aw,
    };

    final summary = summarizeDg(
      widget.dgRecords,
      compositionCount: widget.activeMemberships.length,
    );

    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBlock(summary),
          _buildColumnHeader(),
          Expanded(
            child: widget.rows.isEmpty
                ? const Center(child: Text('Nenhum animal neste ATF.'))
                : ListView.builder(
                    itemCount: widget.rows.length,
                    itemBuilder: (context, i) =>
                        _buildRow(widget.rows[i], animalsById),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopBlock(DgSummary summary) {
    final bullSegment = (widget.atf.bullName?.trim().isEmpty ?? true)
        ? null
        : widget.atf.bullName;
    final percentLabel =
        summary.percent == null ? '—' : '${summary.percent}%';
    final subtitle = [
      'IA ${_iaSubtitleFmt.format(widget.atf.inseminationDate)}',
      if (bullSegment != null) bullSegment,
      '${widget.rows.length} fêmeas',
      'prenhez $percentLabel',
    ].join(' · ');
    final showAddButton = widget.atf.active && widget.canEdit;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        widget.atf.name,
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 10),
                    _statusBadge(),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: monoStyle(size: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          if (showAddButton) ...[
            const SizedBox(width: 12),
            OutlinedButton.icon(
              onPressed: _openSelection,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Animais'),
            ),
          ],
        ],
      ),
    );
  }

  /// Mesma derivação de `_AtfCard`/`ReproducaoTableView`, mas gated em
  /// `widget.pendingMembers` (por membro ATUAL, G-05-3) — nunca
  /// `summarizeDg(...).pending`.
  Widget _statusBadge() {
    if (!widget.atf.active) {
      return const StatusChip('Encerrado', kind: StatusKind.neutral);
    }
    if (widget.pendingMembers > 0) {
      return StatusChip(
        widget.pendingMembers == 1
            ? '1 DG pendente'
            : '${widget.pendingMembers} DGs pendentes',
        kind: StatusKind.warning,
      );
    }
    if (widget.dgRecords.isNotEmpty) {
      return const StatusChip('Completo', kind: StatusKind.positive);
    }
    return const SizedBox.shrink();
  }

  Widget _buildColumnHeader() {
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.surfaceVariant,
      child: const Row(
        children: [
          SizedBox(width: _kColNumber, child: _HeaderText('Nº')),
          Expanded(flex: _kFlexCategoria, child: _HeaderText('CATEGORIA')),
          Expanded(flex: _kFlexLote, child: _HeaderText('LOTE')),
          SizedBox(width: _kColIa, child: _HeaderText('IA')),
          SizedBox(width: _kColDg, child: _HeaderText('DG')),
          SizedBox(width: _kColResultado, child: _HeaderText('RESULTADO')),
        ],
      ),
    );
  }

  Widget _buildRow(
    AtfMembershipView m,
    Map<String, AnimalWithContext> animalsById,
  ) {
    final aw = animalsById[m.animalId];
    final breed = aw?.animal.breed;
    final categoryLabel =
        kCategoryLabels[m.animalCategory] ?? m.animalCategory;
    final categoryText = (breed == null || breed.trim().isEmpty)
        ? categoryLabel
        : '$categoryLabel · $breed';
    final lotName = aw?.lotName;
    final lastDg = latestDgFor(widget.dgRecords, m.animalId);

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: _kColNumber,
            child: Text(
              '#${m.animalNumber}',
              style: monoStyle(size: 15, weight: FontWeight.w700),
            ),
          ),
          Expanded(
            flex: _kFlexCategoria,
            child: Text(categoryText, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            flex: _kFlexLote,
            child: Text(
              lotName == null || lotName.trim().isEmpty ? '—' : lotName,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: _kColIa,
            child: Text(
              _dateFmtShort.format(widget.atf.inseminationDate),
              style: monoStyle(size: 12.5),
            ),
          ),
          SizedBox(
            width: _kColDg,
            child: Text(
              lastDg == null ? '—' : _dateFmtShort.format(lastDg.examDate),
              style: monoStyle(size: 12.5),
            ),
          ),
          const SizedBox(width: _kColResultado),
        ],
      ),
    );
  }

  void _openSelection() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AtfAnimalSelectionScreen(
          atfId: widget.atf.id,
          atfName: widget.atf.name,
        ),
      ),
    );
  }
}

/// Texto de coluna do cabeçalho da tabela: mono 10.5px w700, caixa alta,
/// `letterSpacing 0.8`, `AppColors.primaryDarkText` — idêntico às outras
/// duas tabelas desktop.
class _HeaderText extends StatelessWidget {
  const _HeaderText(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: monoStyle(
        size: 10.5,
        weight: FontWeight.w700,
        letterSpacing: 0.8,
        color: AppColors.primaryDarkText,
      ),
    );
  }
}
