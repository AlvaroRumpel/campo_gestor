import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../reproducao/data/iatf_model.dart';
import '../../reproducao/data/iatf_repository.dart';
import '../../reproducao/data/dg_record_model.dart';
import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import '../data/animal_model.dart';

/// Timeline mesclando eventos reprodutivos e sanitários (spec 3.11).
///
/// Extraído de `animal_detail_screen.dart` (Task 2, quick task 260813-p10)
/// para ser a única implementação, consumida pela ficha e pelo
/// `AnimalDetailPanel` desktop. Extração mecânica — nenhuma mudança de
/// comportamento.

final _dateFmt = DateFormat('dd/MM/yyyy');

// ---------------------------------------------------------------------------
// Filtros da timeline
// ---------------------------------------------------------------------------

enum AnimalTimelineFilter { tudo, reproducao, sanitario }

class AnimalTimelineFilterChips extends StatelessWidget {
  const AnimalTimelineFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final AnimalTimelineFilter value;
  final ValueChanged<AnimalTimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (f, label) in const [
            (AnimalTimelineFilter.tudo, 'Tudo'),
            (AnimalTimelineFilter.reproducao, 'Reprodução'),
            (AnimalTimelineFilter.sanitario, 'Sanitário'),
          ]) ...[
            FilterChip(
              label: Text(label),
              selected: value == f,
              onSelected: (_) => onChanged(f),
              showCheckmark: false,
              visualDensity: VisualDensity.compact,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Timeline (spec 3.11) — mescla reprodutivo + sanitário + cadastro
// ---------------------------------------------------------------------------

enum _EventKind { reproducao, sanitario, cadastro }

class _TimelineEvent {
  const _TimelineEvent({
    required this.date,
    required this.kind,
    required this.title,
    this.detail,
    required this.icon,
    required this.circleBg,
    required this.iconColor,
    this.chip,
    this.route,
    this.voided = false,
  });

  final DateTime date;
  final _EventKind kind;
  final String title;
  final String? detail;
  final IconData icon;
  final Color circleBg;
  final Color iconColor;
  final Widget? chip;
  final String? route;
  final bool voided;
}

/// Bg do círculo de DG vazia / evento estornado — rgba(163,45,20,0.08).
const _dangerCircleBg = Color(0x14A32D14);

/// Bg neutro do círculo sanitário — rgba(35,40,30,0.06).
const _neutralCircleBg = Color(0x0F23281E);

/// Ícone sanitário neutro — rgba(35,40,30,0.6).
const _neutralIconColor = Color(0x9923281E);

/// Ícone de estorno — rgba(163,45,20,0.7).
const _voidedIconColor = Color(0xB3A32D14);

List<_TimelineEvent> _reproEvents(List<ReproductiveHistoryEntry> entries) {
  final events = <_TimelineEvent>[];
  final shortFmt = DateFormat('dd/MM');

  _TimelineEvent dgEvent(
    ReproductiveHistoryEntry entry,
    DgResult result,
    DateTime date,
  ) {
    final (chip, circleBg, iconColor) = switch (result) {
      DgResult.pregnant => (
          const StatusChip('Prenhe', kind: StatusKind.positive, solid: true),
          AppColors.positiveChipBg,
          AppColors.primary,
        ),
      DgResult.notPregnant => (
          const StatusChip('Vazia', kind: StatusKind.danger),
          _dangerCircleBg,
          AppColors.danger,
        ),
      DgResult.doubtful => (
          const StatusChip('Duvidosa', kind: StatusKind.warning),
          AppColors.accentChipBg,
          AppColors.accentTextDark,
        ),
    };
    final detailParts = <String>[
      if (entry.bullName != null && entry.bullName!.trim().isNotEmpty)
        'touro: ${entry.bullName}',
      'insem. ${shortFmt.format(entry.inseminationDate)}',
      entry.iatfActive ? 'ciclo ativo' : 'ciclo encerrado',
    ];
    return _TimelineEvent(
      date: date,
      kind: _EventKind.reproducao,
      title: 'DG — ${entry.iatfName}',
      detail: detailParts.join(' · '),
      icon: Icons.favorite,
      circleBg: circleBg,
      iconColor: iconColor,
      chip: chip,
      route: AppRoutes.iatfDetail(entry.iatfBatchId),
    );
  }

  for (final entry in entries) {
    if (entry.dgRecords.isNotEmpty) {
      for (final dg in entry.dgRecords) {
        final result = DgResult.fromDb(dg.result);
        if (result == null) continue;
        events.add(dgEvent(entry, result, dg.examDate));
      }
    } else if (entry.lastDgResult != null) {
      // Entrada com resumo mas sem a lista de DGs — sintetiza um evento a
      // partir do último resultado conhecido.
      events.add(dgEvent(
        entry,
        entry.lastDgResult!,
        entry.lastDgDate ?? entry.inseminationDate,
      ));
    } else {
      // Sem DG ainda: evento de inseminação aguardando DG.
      final detailParts = <String>[
        if (entry.bullName != null && entry.bullName!.trim().isNotEmpty)
          'touro: ${entry.bullName}',
        'aguardando DG',
        entry.iatfActive ? 'ciclo ativo' : 'ciclo encerrado',
      ];
      events.add(_TimelineEvent(
        date: entry.inseminationDate,
        kind: _EventKind.reproducao,
        title: 'Inseminação — ${entry.iatfName}',
        detail: detailParts.join(' · '),
        icon: Icons.favorite,
        circleBg: AppColors.positiveChipBg,
        iconColor: AppColors.primary,
        route: AppRoutes.iatfDetail(entry.iatfBatchId),
      ));
    }
  }
  return events;
}

List<_TimelineEvent> _sanitaryEvents(List<SanitaryApplication> apps) {
  final shortFmt = DateFormat('dd/MM');
  // Mapa original -> registro de estorno (para data/motivo do subtítulo).
  final reversalByOriginal = <String, SanitaryApplication>{
    for (final app in apps)
      if (app.reversesApplicationId != null)
        app.reversesApplicationId!: app,
  };

  return [
    for (final app in apps)
      if (!app.isReversal)
        () {
          final reversal = reversalByOriginal[app.id];
          final voided = reversal != null;
          final String detail;
          if (voided) {
            final motivo = reversal.notes?.trim();
            detail = 'estornada em ${shortFmt.format(reversal.appliedAt)}'
                '${motivo == null || motivo.isEmpty ? '' : ' — $motivo'}';
          } else {
            detail =
                'lote da época: ${app.lotName} · ${_fmtDose(app.dosagePerUa)} mL/UA';
          }
          return _TimelineEvent(
            date: app.appliedAt,
            kind: _EventKind.sanitario,
            title: app.doseName,
            detail: detail,
            icon: voided ? Icons.block : Icons.medical_services_outlined,
            circleBg: voided ? _dangerCircleBg : _neutralCircleBg,
            iconColor: voided ? _voidedIconColor : _neutralIconColor,
            route: AppRoutes.aplicacaoDetail(app.id),
            voided: voided,
          );
        }(),
  ];
}

String _fmtDose(double mlPerUa) {
  final s = mlPerUa.toStringAsFixed(1).replaceAll('.', ',');
  return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
}

class AnimalTimelineCard extends ConsumerWidget {
  const AnimalTimelineCard({
    super.key,
    required this.animal,
    required this.filter,
    required this.showAll,
    required this.onShowAll,
    this.collapsedCount = 10,
  });

  final Animal animal;
  final AnimalTimelineFilter filter;
  final bool showAll;
  final VoidCallback onShowAll;

  /// Quantidade de eventos exibidos antes do "Ver histórico completo". A
  /// ficha usa o default (10); o painel lateral desktop passa 5.
  final int collapsedCount;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reproAsync =
        ref.watch(reproductiveHistoryByAnimalProvider(animal.id));
    final saniAsync = ref.watch(sanitaryHistoryByAnimalProvider(animal.id));

    final loading = reproAsync.isLoading || saniAsync.isLoading;

    final events = <_TimelineEvent>[
      ..._reproEvents(reproAsync.asData?.value ?? const []),
      ..._sanitaryEvents(saniAsync.asData?.value ?? const []),
    ]..sort((a, b) => b.date.compareTo(a.date));

    // Evento de cadastro sempre por último (spec 4.4).
    events.add(_TimelineEvent(
      date: animal.createdAt,
      kind: _EventKind.cadastro,
      title: 'Cadastrado no rebanho',
      icon: Icons.flag_outlined,
      circleBg: _neutralCircleBg,
      iconColor: _neutralIconColor,
    ));

    final visible = events.where((e) {
      if (e.kind == _EventKind.cadastro) return true;
      return switch (filter) {
        AnimalTimelineFilter.tudo => true,
        AnimalTimelineFilter.reproducao => e.kind == _EventKind.reproducao,
        AnimalTimelineFilter.sanitario => e.kind == _EventKind.sanitario,
      };
    }).toList();

    final truncated = !showAll && visible.length > collapsedCount;
    final rendered =
        truncated ? visible.take(collapsedCount).toList() : visible;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (reproAsync.hasError)
              _TimelineNotice(
                text: 'Erro ao carregar histórico reprodutivo.',
                onRetry: () => ref.invalidate(
                  reproductiveHistoryByAnimalProvider(animal.id),
                ),
              ),
            if (saniAsync.hasError)
              _TimelineNotice(
                text: 'Erro ao carregar histórico sanitário.',
                onRetry: () => ref.invalidate(
                  sanitaryHistoryByAnimalProvider(animal.id),
                ),
              ),
            if (loading)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ),
              )
            else ...[
              for (var i = 0; i < rendered.length; i++)
                _TimelineRow(
                  event: rendered[i],
                  isLast: i == rendered.length - 1,
                ),
              if (truncated) ...[
                const SizedBox(height: 10),
                Center(
                  child: OutlinedButton(
                    onPressed: onShowAll,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      shape: const StadiumBorder(),
                      foregroundColor: AppColors.primary,
                      textStyle: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    child:
                        Text('Ver histórico completo (${visible.length})'),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _TimelineNotice extends StatelessWidget {
  const _TimelineNotice({required this.text, required this.onRetry});

  final String text;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
        ),
        TextButton(onPressed: onRetry, child: const Text('Tentar novamente')),
      ],
    );
  }
}

/// Uma linha da timeline: coluna de 30px com ícone-círculo + conector 2px,
/// conteúdo (data mono + chip, título, detalhe) e chevron quando navegável.
class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});

  final _TimelineEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final voided = event.voided;
    final titleColor = voided ? AppColors.textTertiary : AppColors.ink;
    final detailColor =
        voided ? AppColors.textTertiary : AppColors.textSecondary;

    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 30,
            child: Column(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: event.circleBg,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(event.icon, size: 16, color: event.iconColor),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.symmetric(vertical: 3),
                      color: const Color(0x1A23281E),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        _dateFmt.format(event.date),
                        style: monoStyle(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: detailColor,
                        ),
                      ),
                      if (event.chip != null) ...[
                        const SizedBox(width: 8),
                        event.chip!,
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    event.title,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: titleColor,
                      decoration:
                          voided ? TextDecoration.lineThrough : null,
                    ),
                  ),
                  if (event.detail != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      event.detail!,
                      style: TextStyle(fontSize: 13, color: detailColor),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (event.route != null)
            const Padding(
              padding: EdgeInsets.only(top: 5),
              child: Icon(Icons.chevron_right,
                  size: 20, color: AppColors.textSecondary),
            ),
        ],
      ),
    );

    if (event.route == null) return row;
    return InkWell(
      onTap: () => context.go(event.route!),
      child: row,
    );
  }
}
