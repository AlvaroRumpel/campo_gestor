import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';
import 'atf_animal_selection_screen.dart';

/// Larguras de coluna declaradas uma vez e reusadas pelo cabeçalho e pelas
/// linhas (mesma convenção de `animais_table_view.dart`/`reproducao_table_view.dart`).
const _kColCheckbox = 44.0;
const _kColNumber = 72.0;
const _kColIa = 82.0;
const _kColDg = 82.0;
const _kColResultado = 250.0;
const _kFlexCategoria = 2;
const _kFlexLote = 2;

final _dateFmtShort = DateFormat('dd/MM/yy');
final _iaSubtitleFmt = DateFormat('dd/MM');
final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

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
  final Set<String> _selectedIds = {};
  bool _saving = false;

  /// Cliques Prenhe/Vazia acumulados (item 8 dos ajustes 2026-08-20):
  /// cada clique inline entra aqui e um debounce de 2s dispara UM
  /// `saveDgRecords` com todos, e UMA snackbar com a contagem.
  final Map<String, DgResult> _pending = {};
  Timer? _flushTimer;

  @override
  void dispose() {
    _flushTimer?.cancel();
    if (_pending.isNotEmpty) {
      // Navegou com pendências: grava sem aguardar (fire-and-forget).
      _flushNow(showFeedback: false);
    }
    super.dispose();
  }

  void _queueDg(String animalId, DgResult result) {
    setState(() {
      final latest = latestDgFor(widget.dgRecords, animalId);
      final current = _pending[animalId] ??
          (latest == null ? null : DgResult.fromDb(latest.result));
      if (current == result && !_pending.containsKey(animalId)) {
        return; // no-op: já é esse resultado no banco
      }
      final saved = latest == null ? null : DgResult.fromDb(latest.result);
      if (saved == result) {
        _pending.remove(animalId); // clique de volta cancela o pendente
      } else {
        _pending[animalId] = result;
      }
    });
    _flushTimer?.cancel();
    _flushTimer = Timer(const Duration(seconds: 2), _flushNow);
  }

  Future<void> _flushNow({bool showFeedback = true}) async {
    _flushTimer?.cancel();
    if (_pending.isEmpty) return;
    final batch = Map<String, DgResult>.of(_pending);
    _pending.clear();
    final examDate = _dateOnlyFmt.format(DateTime.now());
    final records = [
      for (final e in batch.entries)
        {
          'animal_id': e.key,
          'result': e.value.dbValue,
          'exam_date': examDate,
        },
    ];
    try {
      await ref.read(atfRepositoryProvider).saveDgRecords(
            atfBatchId: widget.atf.id,
            records: records,
          );
      if (!mounted || !showFeedback) return;
      ref.invalidatePropertyData();
      final n = batch.length;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(n == 1
            ? '1 animal atualizado'
            : '$n animais atualizados'),
      ));
    } catch (_) {
      if (!mounted || !showFeedback) return;
      setState(() => _pending.addAll(batch)); // devolve para nova tentativa
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar DGs. Tente novamente.')),
      );
    }
  }

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
          if (_selectedIds.isNotEmpty) _buildContextBar(),
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

  /// Escrita única, usada pelo botão inline (lista de 1) e pela barra
  /// contextual (lista de N) — assunção 4/8. Filtra fora animais cujo
  /// [latestDgFor] já é [result] (no-op de re-registro); se sobrar zero,
  /// não chama `saveDgRecords`.
  Future<void> _registerDg(List<String> animalIds, DgResult result) async {
    final filtered = animalIds.where((id) {
      final latest = latestDgFor(widget.dgRecords, id);
      return latest == null || DgResult.fromDb(latest.result) != result;
    }).toList();
    if (filtered.isEmpty) return;

    final examDate = _dateOnlyFmt.format(DateTime.now());
    final records = [
      for (final id in filtered)
        {'animal_id': id, 'result': result.dbValue, 'exam_date': examDate},
    ];

    setState(() => _saving = true);
    try {
      await ref.read(atfRepositoryProvider).saveDgRecords(
            atfBatchId: widget.atf.id,
            records: records,
          );
      if (!mounted) return;
      ref.invalidatePropertyData();
      setState(_selectedIds.clear);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DGs registrados.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erro ao salvar DGs. Tente novamente.')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Portão de "Remover do ATF" em lote — mesmo do ícone mobile (assunção
  /// 13): ativo + canEdit + nenhuma linha selecionada já tem DG.
  bool get _canRemoveSelected {
    if (!(widget.atf.active && widget.canEdit) || _selectedIds.isEmpty) {
      return false;
    }
    return _selectedIds
        .every((id) => latestDgFor(widget.dgRecords, id) == null);
  }

  Future<void> _confirmRemoveSelected() async {
    final ids = _selectedIds.toList();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text('Remover ${ids.length} do ATF?'),
        content: const Text('Os animais deixam de fazer parte deste ciclo.'),
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
      ),
    );
    if (confirmed != true) return;

    final repo = ref.read(atfRepositoryProvider);
    try {
      await Future.wait([
        for (final id in ids)
          repo.removeAnimalFromAtf(atfBatchId: widget.atf.id, animalId: id),
      ]);
      if (!mounted) return;
      ref.invalidatePropertyData();
      setState(_selectedIds.clear);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover animal. Tente novamente.'),
        ),
      );
    }
  }

  /// Barra contextual (assunção 11): fundo `AppColors.primaryDarkText`,
  /// texto `AppColors.onGreen`, altura 48.
  Widget _buildContextBar() {
    final count = _selectedIds.length;
    return Container(
      height: 48,
      color: AppColors.primaryDarkText,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: Row(
        children: [
          Text(
            count == 1 ? '1 selecionada' : '$count selecionadas',
            style: monoStyle(
              size: 13,
              weight: FontWeight.w700,
              color: AppColors.onGreen,
            ),
          ),
          const SizedBox(width: 16),
          TextButton(
            onPressed: _saving
                ? null
                : () =>
                    _registerDg(_selectedIds.toList(), DgResult.pregnant),
            child: const Text(
              'Marcar prenhe',
              style: TextStyle(color: AppColors.onGreen),
            ),
          ),
          TextButton(
            onPressed: _saving
                ? null
                : () =>
                    _registerDg(_selectedIds.toList(), DgResult.notPregnant),
            child: const Text(
              'Marcar vazia',
              style: TextStyle(color: AppColors.onGreen),
            ),
          ),
          TextButton(
            onPressed:
                (_saving || !_canRemoveSelected) ? null : _confirmRemoveSelected,
            child: const Text(
              'Remover do ATF',
              style: TextStyle(color: AppColors.onGreen),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: const Icon(Icons.close, color: AppColors.onGreen),
            tooltip: 'Limpar seleção',
            onPressed: () => setState(_selectedIds.clear),
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
    final allSelected =
        widget.rows.isNotEmpty && _selectedIds.length == widget.rows.length;
    return Container(
      constraints: const BoxConstraints(minHeight: 36),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      color: AppColors.surfaceVariant,
      child: Row(
        children: [
          if (widget.canEdit)
            SizedBox(
              width: _kColCheckbox,
              child: Checkbox(
                tristate: true,
                value: _selectedIds.isEmpty ? false : (allSelected ? true : null),
                onChanged: (_) => setState(() {
                  if (allSelected) {
                    _selectedIds.clear();
                  } else {
                    _selectedIds
                      ..clear()
                      ..addAll(widget.rows.map((m) => m.animalId));
                  }
                }),
              ),
            ),
          const SizedBox(width: _kColNumber, child: _HeaderText('Nº')),
          const Expanded(
              flex: _kFlexCategoria, child: _HeaderText('CATEGORIA')),
          const Expanded(flex: _kFlexLote, child: _HeaderText('LOTE')),
          const SizedBox(width: _kColIa, child: _HeaderText('IA')),
          const SizedBox(width: _kColDg, child: _HeaderText('DG')),
          const SizedBox(
              width: _kColResultado, child: _HeaderText('RESULTADO')),
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
    final lastResult =
        lastDg == null ? null : DgResult.fromDb(lastDg.result);

    return Container(
      constraints: const BoxConstraints(minHeight: 44),
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          if (widget.canEdit)
            SizedBox(
              width: _kColCheckbox,
              child: Checkbox(
                value: _selectedIds.contains(m.animalId),
                onChanged: (checked) => setState(() {
                  if (checked ?? false) {
                    _selectedIds.add(m.animalId);
                  } else {
                    _selectedIds.remove(m.animalId);
                  }
                }),
              ),
            ),
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
          _buildResultCell(m, lastResult),
        ],
      ),
    );
  }

  /// Célula RESULTADO: fora de `canEdit`, só o rótulo do resultado atual
  /// (assunção 7/12). Com `canEdit`, um chip "Duvidosa" quando o DG mais
  /// recente é `doubtful` (assunção 9, o desktop nunca registra esse
  /// resultado) seguido do par Prenhe/Vazia inline.
  Widget _buildResultCell(AtfMembershipView m, DgResult? lastResult) {
    if (!widget.canEdit) {
      return SizedBox(
        width: _kColResultado,
        child: Text(lastResult?.label ?? '—'),
      );
    }
    final isDoubtful = lastResult == DgResult.doubtful;
    // Pendente (debounce em voo) vence o último DG salvo na exibição.
    final effectiveResult = _pending[m.animalId] ?? lastResult;
    return SizedBox(
      width: _kColResultado,
      child: Row(
        children: [
          if (isDoubtful) ...[
            const StatusChip('Duvidosa', kind: StatusKind.warning),
            const SizedBox(width: 6),
          ],
          Expanded(
            child: _ResultButton(
              label: 'Prenhe',
              color: AppColors.primary,
              onColor: AppColors.onGreen,
              selected: effectiveResult == DgResult.pregnant,
              enabled: !_saving,
              onTap: () => _queueDg(m.animalId, DgResult.pregnant),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: _ResultButton(
              label: 'Vazia',
              color: AppColors.danger,
              onColor: AppColors.onDanger,
              selected: effectiveResult == DgResult.notPregnant,
              enabled: !_saving,
              onTap: () => _queueDg(m.animalId, DgResult.notPregnant),
            ),
          ),
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

/// Botão inline de resultado (Prenhe/Vazia), h32 r8 — outline em [color]
/// quando não selecionado, preenchido com [color]/[onColor] quando
/// selecionado (assunção 8).
class _ResultButton extends StatelessWidget {
  const _ResultButton({
    required this.label,
    required this.color,
    required this.onColor,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final String label;
  final Color color;
  final Color onColor;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? color : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: selected ? BorderSide.none : BorderSide(color: color),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          height: 32,
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w600,
              color: selected ? onColor : color,
            ),
          ),
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
