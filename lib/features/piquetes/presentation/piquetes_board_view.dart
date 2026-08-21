import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/piquete_model.dart';
import 'piquetes_lotes_header.dart';

String _fmt1(double v) => v.toStringAsFixed(1).replaceAll('.', ',');

/// Quadro (kanban) desktop da aba Piquetes de `/piquetes` (quick task
/// 260813-v19) — uma coluna por piquete, cards de lote arrastáveis entre
/// colunas. Widget puro de apresentação: não lê `ref`, não conhece
/// repositório nem diálogo, recebe dados prontos e devolve callbacks.
class PiquetesBoardView extends StatefulWidget {
  const PiquetesBoardView({
    super.key,
    required this.paddocks,
    required this.lots,
    required this.animalsByLot,
    required this.onShowLotsChanged,
    required this.selectedLotId,
    required this.onSelectLot,
    required this.onMoveLot,
    required this.canEdit,
    required this.onOpenPaddock,
    required this.onEditPaddock,
    required this.onDeletePaddock,
  });

  final List<Paddock> paddocks;
  final List<LotWithPaddockCount> lots;
  final Map<String, List<Animal>> animalsByLot;
  final ValueChanged<bool> onShowLotsChanged;
  final String? selectedLotId;
  final ValueChanged<String?> onSelectLot;
  final void Function(LotWithPaddockCount lot, Paddock target) onMoveLot;
  final bool canEdit;
  final ValueChanged<Paddock> onOpenPaddock;
  final ValueChanged<Paddock> onEditPaddock;
  final ValueChanged<Paddock> onDeletePaddock;

  @override
  State<PiquetesBoardView> createState() => _PiquetesBoardViewState();
}

class _PiquetesBoardViewState extends State<PiquetesBoardView> {
  LotWithPaddockCount? _dragging;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: AppColors.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PiquetesLotesHeader(
            paddocks: widget.paddocks,
            animalsByLot: widget.animalsByLot,
            paddockCount: widget.paddocks.length,
            lotCount: widget.lots.length,
            showLots: false,
            onShowLotsChanged: widget.onShowLotsChanged,
            action: null,
          ),
          Expanded(
            child: widget.paddocks.isEmpty
                ? const EmptyState(
                    icon: Icons.fence_outlined,
                    title: 'Nenhum piquete cadastrado',
                    message:
                        'Adicione piquetes para começar a organizar os lotes da fazenda.',
                  )
                : Padding(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < widget.paddocks.length; i++) ...[
                          if (i > 0) const SizedBox(width: 12),
                          Expanded(
                            child: _PaddockColumn(
                              paddock: widget.paddocks[i],
                              lots: widget.lots
                                  .where((l) =>
                                      l.lot.paddockId ==
                                      widget.paddocks[i].id)
                                  .toList()
                                ..sort((a, b) {
                                  final uaA = calcTotalUa(
                                      widget.animalsByLot[a.lot.id] ??
                                          const []);
                                  final uaB = calcTotalUa(
                                      widget.animalsByLot[b.lot.id] ??
                                          const []);
                                  final cmp = uaB.compareTo(uaA);
                                  return cmp != 0
                                      ? cmp
                                      : a.lot.name.compareTo(b.lot.name);
                                }),
                              animalsByLot: widget.animalsByLot,
                              dragging: _dragging,
                              selectedLotId: widget.selectedLotId,
                              onSelectLot: widget.onSelectLot,
                              onMoveLot: widget.onMoveLot,
                              canEdit: widget.canEdit,
                              onOpenPaddock: widget.onOpenPaddock,
                              onEditPaddock: widget.onEditPaddock,
                              onDeletePaddock: widget.onDeletePaddock,
                              onDragStarted: (item) =>
                                  setState(() => _dragging = item),
                              onDragEnd: () => setState(() => _dragging = null),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Coluna de um piquete: header de semáforo + lista de cards de lote com
/// drop-target para receber lotes arrastados de outras colunas.
class _PaddockColumn extends StatelessWidget {
  const _PaddockColumn({
    required this.paddock,
    required this.lots,
    required this.animalsByLot,
    required this.dragging,
    required this.selectedLotId,
    required this.onSelectLot,
    required this.onMoveLot,
    required this.canEdit,
    required this.onOpenPaddock,
    required this.onEditPaddock,
    required this.onDeletePaddock,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  final Paddock paddock;
  final List<LotWithPaddockCount> lots;
  final Map<String, List<Animal>> animalsByLot;
  final LotWithPaddockCount? dragging;
  final String? selectedLotId;
  final ValueChanged<String?> onSelectLot;
  final void Function(LotWithPaddockCount lot, Paddock target) onMoveLot;
  final bool canEdit;
  final ValueChanged<Paddock> onOpenPaddock;
  final ValueChanged<Paddock> onEditPaddock;
  final ValueChanged<Paddock> onDeletePaddock;
  final ValueChanged<LotWithPaddockCount> onDragStarted;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final ua = lots.fold<double>(
      0,
      (sum, item) => sum + calcTotalUa(animalsByLot[item.lot.id] ?? const []),
    );
    final ratio = paddock.uaCapacity > 0 ? ua / paddock.uaCapacity : 0.0;
    final over = ratio >= 1.0;
    final uaHa = paddock.areaHa > 0 ? ua / paddock.areaHa : 0.0;
    final showDropZone = dragging != null && dragging!.lot.paddockId != paddock.id;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => onOpenPaddock(paddock),
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(14),
            ),
            child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: over ? AppColors.dangerContainer : AppColors.surfaceVariant,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(14),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        paddock.name,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: over ? AppColors.onDangerContainer : AppColors.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${_fmt1(paddock.areaHa)} ha',
                      style: monoStyle(size: 11.5, color: AppColors.textSecondary),
                    ),
                    if (over) ...[
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.warning_amber_rounded,
                        size: 16,
                        color: AppColors.danger,
                      ),
                    ],
                    if (canEdit)
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: PopupMenuButton<String>(
                          padding: EdgeInsets.zero,
                          iconSize: 18,
                          tooltip: 'Ações do piquete',
                          onSelected: (v) {
                            if (v == 'edit') onEditPaddock(paddock);
                            if (v == 'delete') onDeletePaddock(paddock);
                          },
                          itemBuilder: (_) => const [
                            PopupMenuItem(
                                value: 'edit', child: Text('Editar')),
                            PopupMenuItem(
                              value: 'delete',
                              child: Text(
                                'Remover',
                                style: TextStyle(color: AppColors.danger),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Text(
                      '${_fmt1(ua)} / ${_fmt1(paddock.uaCapacity)} UA',
                      style: monoStyle(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: over ? AppColors.danger : AppColors.ink,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${_fmt1(uaHa)} UA/ha',
                      style: monoStyle(size: 11.5, color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                CapacityBar(current: ua, capacity: paddock.uaCapacity, height: 4),
              ],
            ),
            ),
          ),
          Expanded(
            child: DragTarget<LotWithPaddockCount>(
              onWillAcceptWithDetails: (d) => d.data.lot.paddockId != paddock.id,
              onAcceptWithDetails: (d) => onMoveLot(d.data, paddock),
              builder: (context, candidateData, rejectedData) => ListView(
                key: ValueKey('board-drop-${paddock.id}'),
                padding: const EdgeInsets.all(8),
                children: [
                  for (final item in lots)
                    _LotCard(
                      item: item,
                      animalsByLot: animalsByLot,
                      selected: item.lot.id == selectedLotId,
                      onSelectLot: onSelectLot,
                      canEdit: canEdit,
                      onDragStarted: onDragStarted,
                      onDragEnd: onDragEnd,
                    ),
                  if (showDropZone)
                    _DropZone(
                      currentUa: ua,
                      capacity: paddock.uaCapacity,
                      draggedUa: calcTotalUa(
                        animalsByLot[dragging!.lot.id] ?? const [],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Drop-zone tracejada com preview "fica X / Y UA" — cor pelo semáforo de
/// lotação resultante.
class _DropZone extends StatelessWidget {
  const _DropZone({
    required this.currentUa,
    required this.capacity,
    required this.draggedUa,
  });

  final double currentUa;
  final double capacity;
  final double draggedUa;

  @override
  Widget build(BuildContext context) {
    final uaResultante = currentUa + draggedUa;
    final ratio = capacity > 0 ? uaResultante / capacity : 0.0;
    final previewColor = AppColors.capacityColor(ratio);
    return Container(
      height: 56,
      margin: const EdgeInsets.only(bottom: 8),
      child: CustomPaint(
        painter: _DashedBorderPainter(color: previewColor, radius: 12),
        child: Center(
          child: Text(
            'fica ${_fmt1(uaResultante)} / ${_fmt1(capacity)} UA',
            style: monoStyle(size: 12.5, weight: FontWeight.w600, color: previewColor),
          ),
        ),
      ),
    );
  }
}

/// Pinta uma borda tracejada arredondada — traços de 6px a cada 10px.
class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = RRect.fromRectAndRadius(
      Offset.zero & size,
      Radius.circular(radius),
    );
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final metric in path.computeMetrics()) {
      var d = 0.0;
      while (d < metric.length) {
        final next = (d + 6).clamp(0.0, metric.length);
        canvas.drawPath(metric.extractPath(d, next), paint);
        d += 10;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Card de lote — cabeças/UA + indicador de arrasto. Arrastável quando
/// `canEdit`; caso contrário renderizado direto (quadro somente leitura).
/// `Draggable` (não `LongPressDraggable`): no web o arrasto com mouse
/// precisa ser imediato, e o clique parado ainda chega ao `InkWell` porque
/// o reconhecedor só vence a arena quando o ponteiro se move.
class _LotCard extends StatelessWidget {
  const _LotCard({
    required this.item,
    required this.animalsByLot,
    required this.selected,
    required this.onSelectLot,
    required this.canEdit,
    required this.onDragStarted,
    required this.onDragEnd,
  });

  final LotWithPaddockCount item;
  final Map<String, List<Animal>> animalsByLot;
  final bool selected;
  final ValueChanged<String?> onSelectLot;
  final bool canEdit;
  final ValueChanged<LotWithPaddockCount> onDragStarted;
  final VoidCallback onDragEnd;

  @override
  Widget build(BuildContext context) {
    final animals = animalsByLot[item.lot.id] ?? const <Animal>[];
    final ua = calcTotalUa(animals);
    final card = Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(12),
        border: selected ? Border.all(color: AppColors.primary, width: 2) : null,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => onSelectLot(item.lot.id),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              const Icon(
                Icons.drag_indicator,
                size: 18,
                color: AppColors.textTertiary,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.lot.name,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${animals.length} an. · ${_fmt1(ua)} UA',
                      style: monoStyle(size: 12, color: AppColors.textSecondary),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!canEdit) return card;

    return Draggable<LotWithPaddockCount>(
      data: item,
      onDragStarted: () => onDragStarted(item),
      onDragEnd: (_) => onDragEnd(),
      feedback: Material(
        color: Colors.transparent,
        elevation: 6,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(width: 240, child: card),
      ),
      childWhenDragging: Opacity(opacity: 0.35, child: card),
      child: card,
    );
  }
}
