import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/routes.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';

/// dd/MM/yyyy, no locale symbol data needed for this numeric pattern —
/// mirrors `aplicacao_detail_screen.dart`'s identical formatter.
final _dateFmt = DateFormat('dd/MM/yyyy');

/// Shared sanitary history section (SANI-04, SANI-05, D-20, D-25, D-37).
///
/// Two public, standalone widgets — [AnimalSanitaryHistorySection] (animal
/// ficha) and [LoteSanitaryHistorySection] (lote ficha) — render through the
/// same private outlined-card shell as `_ReproductiveHistorySection` and
/// `_PlaceholderSection` in `animal_detail_screen.dart`. Every rendered value
/// comes from the frozen [SanitaryApplication] row — never a live animal,
/// lot or dose model (D-03/D-04) — so a moved or archived animal still shows
/// the history it had at application time.
///
/// D-37 contract: [AnimalSanitaryHistorySection] takes nothing but an animal
/// id, so Phase 8's consolidated ficha can drop it in unchanged next to the
/// reproductive block without touching query or presentation code.

/// Animal-ficha variant (SANI-05, D-25). Watches
/// `sanitaryHistoryByAnimalProvider(animalId)`. Read-only for every role — no
/// mutation affordance lives on this section.
class AnimalSanitaryHistorySection extends ConsumerStatefulWidget {
  const AnimalSanitaryHistorySection({super.key, required this.animalId});

  final String animalId;

  @override
  ConsumerState<AnimalSanitaryHistorySection> createState() =>
      _AnimalSanitaryHistorySectionState();
}

class _AnimalSanitaryHistorySectionState
    extends ConsumerState<AnimalSanitaryHistorySection> {
  bool _showReversed = false;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      sanitaryHistoryByAnimalProvider(widget.animalId),
    );

    return _SanitaryHistoryCardShell(
      showReversed: _showReversed,
      onShowReversedChanged: (v) => setState(() => _showReversed = v),
      body: historyAsync.when(
        loading: () => const _SectionSpinner(),
        error: (err, st) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionMessage('Erro ao carregar histórico sanitário.'),
            TextButton(
              onPressed: () => ref.invalidate(
                sanitaryHistoryByAnimalProvider(widget.animalId),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
        data: (rows) {
          final visible = visibleApplications(
            rows,
            showReversed: _showReversed,
          );
          if (visible.isEmpty) {
            return const _SectionMessage(
              'Nenhuma aplicação sanitária registrada para este animal.',
            );
          }
          final reversedIds = reversedApplicationIds(rows);
          final hasMore = visible.length > 10;
          final rendered = visible.take(10).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final app in rendered)
                _buildAnimalRow(
                  context,
                  app,
                  isVoided: app.isReversal || reversedIds.contains(app.id),
                  badgeLabel: _badgeLabel(app, reversedIds),
                ),
              if (hasMore)
                _VerTodasButton(queryParameters: {'animal': widget.animalId}),
            ],
          );
        },
      ),
    );
  }
}

/// Lote-ficha variant (SANI-04, D-20). Watches
/// `sanitaryApplicationsByLotProvider(lotId)`. Read-only, same shell and
/// reversal semantics as the animal variant.
class LoteSanitaryHistorySection extends ConsumerStatefulWidget {
  const LoteSanitaryHistorySection({super.key, required this.lotId});

  final String lotId;

  @override
  ConsumerState<LoteSanitaryHistorySection> createState() =>
      _LoteSanitaryHistorySectionState();
}

class _LoteSanitaryHistorySectionState
    extends ConsumerState<LoteSanitaryHistorySection> {
  bool _showReversed = false;

  @override
  Widget build(BuildContext context) {
    final historyAsync = ref.watch(
      sanitaryApplicationsByLotProvider(widget.lotId),
    );

    return _SanitaryHistoryCardShell(
      showReversed: _showReversed,
      onShowReversedChanged: (v) => setState(() => _showReversed = v),
      body: historyAsync.when(
        loading: () => const _SectionSpinner(),
        error: (err, st) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _SectionMessage(
              'Erro ao carregar. Verifique sua conexão e tente novamente.',
            ),
            TextButton(
              onPressed: () => ref.invalidate(
                sanitaryApplicationsByLotProvider(widget.lotId),
              ),
              child: const Text('Tentar novamente'),
            ),
          ],
        ),
        data: (rows) {
          final visible = visibleApplications(
            rows,
            showReversed: _showReversed,
          );
          if (visible.isEmpty) {
            return const _SectionMessage(
              'Nenhuma aplicação registrada neste lote.',
            );
          }
          final reversedIds = reversedApplicationIds(rows);
          final hasMore = visible.length > 10;
          final rendered = visible.take(10).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final app in rendered)
                _buildLoteRow(
                  context,
                  app,
                  isVoided: app.isReversal || reversedIds.contains(app.id),
                  badgeLabel: _badgeLabel(app, reversedIds),
                ),
              if (hasMore)
                _VerTodasButton(queryParameters: {'lote': widget.lotId}),
            ],
          );
        },
      ),
    );
  }
}

/// "Estornada" for a reversed original, "Estorno" for the reversal record
/// itself, null for a normal, un-reversed application. Mutually exclusive —
/// a row cannot be both (D-31's uniqueness guarantee).
String? _badgeLabel(SanitaryApplication app, Set<String> reversedIds) {
  if (app.isReversal) return 'Estorno';
  if (reversedIds.contains(app.id)) return 'Estornada';
  return null;
}

/// Animal-ficha row (D-25): "[dose_name] — [applied_at DD/MM/AAAA] · lote:
/// [lote_name congelado]".
Widget _buildAnimalRow(
  BuildContext context,
  SanitaryApplication app, {
  required bool isVoided,
  required String? badgeLabel,
}) {
  final theme = Theme.of(context);
  final title = Text(
    '${app.doseName} — ${_dateFmt.format(app.appliedAt)} · '
    'lote: ${app.lotName}',
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyLarge?.copyWith(
      decoration: isVoided ? TextDecoration.lineThrough : null,
    ),
  );
  return _HistoryRowShell(
    title: title,
    applicationId: app.id,
    badgeLabel: badgeLabel,
  );
}

/// Lote-ficha row (D-20): "[applied_at DD/MM/AAAA] · [dose_name] · [N
/// animais]" + " · R$ [total_cost]" only when the frozen total is non-null
/// (D-11 — never render a dangling "R$ 0,00").
Widget _buildLoteRow(
  BuildContext context,
  SanitaryApplication app, {
  required bool isVoided,
  required String? badgeLabel,
}) {
  final theme = Theme.of(context);
  final parts = <String>[
    _dateFmt.format(app.appliedAt),
    app.doseName,
    Intl.plural(
      app.animalCount.abs(),
      one: '1 animal',
      other: '${app.animalCount.abs()} animais',
    ),
  ];
  var line = parts.join(' · ');
  if (app.totalCost != null) {
    line = '$line · ${formatCurrencyBrl(app.totalCost!.abs())}';
  }
  final title = Text(
    line,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: theme.textTheme.bodyLarge?.copyWith(
      decoration: isVoided ? TextDecoration.lineThrough : null,
    ),
  );
  return _HistoryRowShell(
    title: title,
    applicationId: app.id,
    badgeLabel: badgeLabel,
  );
}

/// Private outlined-card shell shared by both variants — the exact shape
/// `_ReproductiveHistorySection`/`_PlaceholderSection` already use in
/// `animal_detail_screen.dart` (borderRadius 12, outline 38%,
/// colorScheme.surface, padding 16). Header: locked section label, a
/// spacer, and the "Mostrar estornadas" toggle. Each placement owns its own
/// toggle value — no shared provider, since it is a per-surface view
/// preference, not application state.
class _SanitaryHistoryCardShell extends StatelessWidget {
  const _SanitaryHistoryCardShell({
    required this.showReversed,
    required this.onShowReversedChanged,
    required this.body,
  });

  final bool showReversed;
  final ValueChanged<bool> onShowReversedChanged;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: theme.colorScheme.outline.withValues(alpha: 0.38),
        ),
      ),
      color: theme.colorScheme.surface,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Histórico Sanitário',
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Text(
                  'Mostrar estornadas',
                  style: theme.textTheme.bodyMedium,
                ),
                Switch(value: showReversed, onChanged: onShowReversedChanged),
              ],
            ),
            const SizedBox(height: 8),
            body,
          ],
        ),
      ),
    );
  }
}

/// Row shell shared by both variants: tap-to-detail, badge slot. Each
/// variant supplies its own already-styled [title] (maxLines/ellipsis
/// applied by the caller so the row format stays variant-specific).
class _HistoryRowShell extends StatelessWidget {
  const _HistoryRowShell({
    required this.title,
    required this.applicationId,
    required this.badgeLabel,
  });

  final Widget title;
  final String applicationId;
  final String? badgeLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (badgeLabel) {
      'Estornada' => (colorScheme.errorContainer, colorScheme.onErrorContainer),
      'Estorno' => (colorScheme.surfaceContainerHigh, colorScheme.onSurface),
      _ => (null, null),
    };

    return InkWell(
      onTap: () => context.go(AppRoutes.aplicacaoDetail(applicationId)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            Expanded(child: title),
            if (badgeLabel != null) ...[
              const SizedBox(width: 8),
              _HistoryBadge(
                label: badgeLabel!,
                background: background!,
                foreground: foreground!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Small rounded status badge — matches `_StatusChip` in
/// `aplicacao_detail_screen.dart`.
class _HistoryBadge extends StatelessWidget {
  const _HistoryBadge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: foreground),
      ),
    );
  }
}

/// "Ver todas" action (pagination cross-cutting contract) — navigates to the
/// global Aplicações list pre-filtered by this lote/animal via a query
/// parameter, which `SanitarioScreen` (06-10) reads to seed its filters.
class _VerTodasButton extends StatelessWidget {
  const _VerTodasButton({required this.queryParameters});

  final Map<String, String> queryParameters;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: TextButton(
        onPressed: () => context.go(
          Uri(
            path: AppRoutes.sanitario,
            queryParameters: queryParameters,
          ).toString(),
        ),
        child: const Text('Ver todas'),
      ),
    );
  }
}

/// Section-local centred spinner — never blanks the whole ficha.
class _SectionSpinner extends StatelessWidget {
  const _SectionSpinner();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: CircularProgressIndicator(),
      ),
    );
  }
}

/// Muted section-local message — used for both the empty and error states,
/// matching `_ReproductiveHistorySection`'s tone (no icon).
class _SectionMessage extends StatelessWidget {
  const _SectionMessage(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Text(
      text,
      style: theme.textTheme.bodyMedium?.copyWith(
        color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
      ),
    );
  }
}
