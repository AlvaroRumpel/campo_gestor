import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../../reproducao/data/atf_model.dart';
import '../../reproducao/data/atf_repository.dart';
import '../../reproducao/data/dg_record_model.dart';
import '../../sanitario/data/sanitary_application_model.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import '../data/animal_constants.dart';
import '../data/animal_model.dart';
import '../data/animal_repository.dart';
import 'animal_edit_dialog.dart';
import 'baixa_dialog.dart';
import 'mover_animal_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

String _fmtUa(double ua) => ua.toStringAsFixed(1).replaceAll('.', ',');

/// Ficha do animal — timeline (spec 4.4, tela core).
///
/// Header verde com hero `#N` + badge UA circular + tiles glass Lote/Piquete;
/// barra de ações (vet only); card de estado (EC + observação); timeline
/// única mesclando eventos reprodutivos e sanitários (spec 3.11), lida dos
/// providers já existentes das features reproducao/sanitario.
class AnimalDetailScreen extends ConsumerStatefulWidget {
  const AnimalDetailScreen({super.key, required this.animalId});
  final String animalId;

  @override
  ConsumerState<AnimalDetailScreen> createState() =>
      _AnimalDetailScreenState();
}

enum _TimelineFilter { tudo, reproducao, sanitario }

class _AnimalDetailScreenState extends ConsumerState<AnimalDetailScreen> {
  _TimelineFilter _filter = _TimelineFilter.tudo;
  bool _showAllEvents = false;

  bool _canEdit(
    SelectedProperty? current,
    List<PropertyMembership>? members,
  ) {
    if (current == null || members == null) return false;
    final role = members
        .where((m) => m.property.id == current.id)
        .map((m) => m.role)
        .firstOrNull;
    return role == 'veterinarian';
  }

  Future<void> _onEdit(Animal animal) async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => AnimalEditDialog(animal: animal),
    );
    if (ok == true) {
      ref.invalidate(animalByIdProvider(widget.animalId));
    }
  }

  Future<void> _onBaixa(Animal animal) async {
    final ok = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => BaixaDialog(animal: animal),
    );
    if (ok == true) {
      ref.invalidate(animalByIdProvider(widget.animalId));
    }
  }

  Future<void> _onMover(Animal animal) async {
    final result = await showAdaptiveForm<Map<String, String>>(
      context: context,
      builder: (_) => MoverAnimalDialog(animal: animal),
    );
    if (result != null && mounted) {
      final lotName = result['lotName'] ?? '';
      ref.invalidate(animalByIdProvider(widget.animalId));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Animal movido para $lotName')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalAsync = ref.watch(animalByIdProvider(widget.animalId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);

    final propertyName = currentPropAsync.asData?.value?.name;
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    final appBar = DetailAppBar(
      parentLabel: 'Animais',
      contextPill:
          propertyName == null ? null : FarmContextPill(name: propertyName),
    );

    return animalAsync.when(
      loading: () => Scaffold(
        appBar: appBar,
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: appBar,
        body: const Center(child: Text('Erro ao carregar animal.')),
      ),
      data: (animal) {
        if (animal == null) {
          return Scaffold(
            appBar: appBar,
            body: const Center(child: Text('Animal não encontrado.')),
          );
        }

        final isActive = animal.deletedAt == null;

        return Scaffold(
          appBar: appBar,
          body: ListView(
            padding: EdgeInsets.zero,
            children: [
              _GreenHeader(animal: animal),
              Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!isActive) ...[
                      _BaixaBanner(animal: animal),
                      const SizedBox(height: 12),
                    ],
                    if (canEdit) ...[
                      _ActionBar(
                        isActive: isActive,
                        onEdit: () => _onEdit(animal),
                        onMover: () => _onMover(animal),
                        onBaixa: () => _onBaixa(animal),
                      ),
                      const SizedBox(height: 12),
                    ],
                    _StateCard(animal: animal),
                    const SizedBox(height: 12),
                    _TimelineFilterChips(
                      value: _filter,
                      onChanged: (f) => setState(() => _filter = f),
                    ),
                    const SizedBox(height: 10),
                    _TimelineCard(
                      animal: animal,
                      filter: _filter,
                      showAll: _showAllEvents,
                      onShowAll: () => setState(() => _showAllEvents = true),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Header verde (spec 4.4)
// ---------------------------------------------------------------------------

class _GreenHeader extends ConsumerWidget {
  const _GreenHeader({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final categoryLabel = kCategoryLabels[animal.category] ?? animal.category;
    final ua = kUaWeights[animal.category] ?? 0.0;
    final lotAsync = ref.watch(loteWithPaddockByIdProvider(animal.lotId));
    final lotData = lotAsync.asData?.value;

    // "raça · EC n/5 · desde dd/MM/yyyy" — números/datas em mono (regra 3).
    final metaSpans = <InlineSpan>[
      if (animal.breed != null && animal.breed!.trim().isNotEmpty)
        TextSpan(text: animal.breed),
      if (animal.bodyCondition != null)
        TextSpan(children: [
          const TextSpan(text: 'EC '),
          TextSpan(
            text: '${animal.bodyCondition}/5',
            style: monoStyle(size: 14, color: AppColors.onGreenSecondary),
          ),
        ]),
      TextSpan(children: [
        const TextSpan(text: 'desde '),
        TextSpan(
          text: _dateFmt.format(animal.createdAt.toLocal()),
          style: monoStyle(size: 14, color: AppColors.onGreenSecondary),
        ),
      ]),
    ];

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.primary,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '#${animal.number}',
                      style: monoStyle(
                        size: 44,
                        weight: FontWeight.w600,
                        color: AppColors.onGreen,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      categoryLabel,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: AppColors.onGreen,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: const TextStyle(
                          fontSize: 14,
                          color: AppColors.onGreenSecondary,
                        ),
                        children: [
                          for (var i = 0; i < metaSpans.length; i++) ...[
                            if (i > 0) const TextSpan(text: ' · '),
                            metaSpans[i],
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _UaBadge(ua: ua),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: GlassTile(
                  label: 'Lote',
                  value: lotData?.lot.name ?? '—',
                  onTap: lotData == null
                      ? null
                      : () =>
                          context.go(AppRoutes.loteDetail(lotData.lot.id)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: GlassTile(
                  label: 'Piquete',
                  value: lotData?.paddockName ?? '—',
                  onTap: lotData == null
                      ? null
                      : () => context
                          .go('/piquetes/${lotData.lot.paddockId}'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Badge UA circular 66px laranja (spec 3.10).
class _UaBadge extends StatelessWidget {
  const _UaBadge({required this.ua});

  final double ua;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 66,
      height: 66,
      decoration: const BoxDecoration(
        color: AppColors.accent,
        shape: BoxShape.circle,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            _fmtUa(ua),
            style: monoStyle(
              size: 19,
              weight: FontWeight.w700,
              color: AppColors.onAccent,
            ),
          ),
          const Text(
            'UA',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1,
              color: AppColors.onAccent,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Barra de ações (vet only)
// ---------------------------------------------------------------------------

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isActive,
    required this.onEdit,
    required this.onMover,
    required this.onBaixa,
  });

  final bool isActive;
  final VoidCallback onEdit;
  final VoidCallback onMover;
  final VoidCallback onBaixa;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: FilledButton.icon(
            onPressed: onEdit,
            icon: const Icon(Icons.edit_outlined, size: 20),
            label: const Text('Editar'),
          ),
        ),
        if (isActive) ...[
          const SizedBox(width: 8),
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onMover,
              icon: const Icon(Icons.swap_horiz, size: 20),
              label: const Text('Mover'),
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 48,
            height: 48,
            child: OutlinedButton(
              onPressed: onBaixa,
              style: OutlinedButton.styleFrom(
                padding: EdgeInsets.zero,
                side: const BorderSide(color: Color(0x4DA32D14)),
                foregroundColor: AppColors.danger,
              ),
              child: const Tooltip(
                message: 'Dar baixa',
                child: Icon(Icons.arrow_downward,
                    size: 22, color: AppColors.danger),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Card de estado (EC + observação)
// ---------------------------------------------------------------------------

class _StateCard extends StatelessWidget {
  const _StateCard({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final observation = animal.observation?.trim();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineLabel('Estado corporal'),
                    const SizedBox(height: 8),
                    if (animal.bodyCondition != null)
                      // FittedBox: EcMeter tem largura fixa (~150px) e a
                      // coluna esmaga a 360px de viewport.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: EcMeter(score: animal.bodyCondition!),
                      )
                    else
                      const Text('—',
                          style: TextStyle(color: AppColors.textSecondary)),
                  ],
                ),
              ),
              const VerticalDivider(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const OverlineLabel('Observação'),
                    const SizedBox(height: 6),
                    Text(
                      observation == null || observation.isEmpty
                          ? '—'
                          : observation,
                      style: const TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: AppColors.ink,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filtros da timeline
// ---------------------------------------------------------------------------

class _TimelineFilterChips extends StatelessWidget {
  const _TimelineFilterChips({required this.value, required this.onChanged});

  final _TimelineFilter value;
  final ValueChanged<_TimelineFilter> onChanged;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (final (f, label) in const [
            (_TimelineFilter.tudo, 'Tudo'),
            (_TimelineFilter.reproducao, 'Reprodução'),
            (_TimelineFilter.sanitario, 'Sanitário'),
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
      entry.atfActive ? 'ciclo ativo' : 'ciclo encerrado',
    ];
    return _TimelineEvent(
      date: date,
      kind: _EventKind.reproducao,
      title: 'DG — ${entry.atfName}',
      detail: detailParts.join(' · '),
      icon: Icons.favorite,
      circleBg: circleBg,
      iconColor: iconColor,
      chip: chip,
      route: AppRoutes.atfDetail(entry.atfBatchId),
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
        entry.atfActive ? 'ciclo ativo' : 'ciclo encerrado',
      ];
      events.add(_TimelineEvent(
        date: entry.inseminationDate,
        kind: _EventKind.reproducao,
        title: 'Inseminação — ${entry.atfName}',
        detail: detailParts.join(' · '),
        icon: Icons.favorite,
        circleBg: AppColors.positiveChipBg,
        iconColor: AppColors.primary,
        route: AppRoutes.atfDetail(entry.atfBatchId),
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

class _TimelineCard extends ConsumerWidget {
  const _TimelineCard({
    required this.animal,
    required this.filter,
    required this.showAll,
    required this.onShowAll,
  });

  final Animal animal;
  final _TimelineFilter filter;
  final bool showAll;
  final VoidCallback onShowAll;

  static const _collapsedCount = 10;

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
        _TimelineFilter.tudo => true,
        _TimelineFilter.reproducao => e.kind == _EventKind.reproducao,
        _TimelineFilter.sanitario => e.kind == _EventKind.sanitario,
      };
    }).toList();

    final truncated = !showAll && visible.length > _collapsedCount;
    final rendered =
        truncated ? visible.take(_collapsedCount).toList() : visible;

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

// ---------------------------------------------------------------------------
// Banner de baixa (D-12..D-15, SC-4) — anuncia algo que já aconteceu.
// ---------------------------------------------------------------------------

class _BaixaBanner extends StatelessWidget {
  const _BaixaBanner({required this.animal});

  final Animal animal;

  @override
  Widget build(BuildContext context) {
    final reasonLabel = switch (animal.baixaReason) {
      'sale' => 'Vendido',
      'death' => 'Morto',
      'discard' => 'Descartado',
      _ => 'Arquivado',
    };
    final dateStr = animal.baixaDate != null
        ? ' em ${_dateFmt.format(animal.baixaDate!)}'
        : '';
    final observation = animal.observation;
    final hasObservation =
        observation != null && observation.trim().isNotEmpty;
    final text = hasObservation
        ? '$reasonLabel$dateStr — $observation'
        : '$reasonLabel$dateStr';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.dangerContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.info_outline,
              size: 20, color: AppColors.onDangerContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: AppColors.onDangerContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
