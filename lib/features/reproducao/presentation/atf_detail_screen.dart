import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/router/routes.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/breakpoints.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../auth/data/property_repository.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';
import 'atf_animal_selection_screen.dart';
import 'atf_dg_table_view.dart';
import 'encerrar_atf_dialog.dart';

/// ATF detail screen (`/atf/:atfId`, root-level per D-02) — redesign spec 4.9
/// ("celular no brete"): green header with the % prenhez KPI, the DG session
/// banner, ONE merged composição list where every animal row carries its
/// three DG segment buttons, and a fixed save footer.
///
/// The composição header count keeps counting ACTIVE memberships only, while
/// the row list reads the UNFILTERED membership roster (minus archived
/// animals, G-05-2) so a closed ATF still shows its full roster for DG
/// correction (D-16).
class AtfDetailScreen extends ConsumerWidget {
  const AtfDetailScreen({super.key, required this.atfId});
  final String atfId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final atfAsync = ref.watch(atfByIdProvider(atfId));
    final membershipsAsync = ref.watch(atfActiveMembershipsProvider(atfId));
    final allMembershipsAsync = ref.watch(atfMembershipsProvider(atfId));
    final dgRecordsAsync = ref.watch(dgRecordsByAtfProvider(atfId));
    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final canEdit = _canEdit(
      currentPropAsync.asData?.value,
      membersAsync.asData?.value,
    );

    return atfAsync.when(
      loading: () => Scaffold(
        appBar: _appBar(context),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: _appBar(context),
        body: Center(
          child: ErrorRetry(
            message:
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
            onRetry: () => ref.invalidate(atfByIdProvider(atfId)),
          ),
        ),
      ),
      data: (atf) {
        if (atf == null) {
          return Scaffold(
            appBar: _appBar(context),
            body: const Center(
              child: Text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
            ),
          );
        }

        final activeMemberships = membershipsAsync.asData?.value ?? const [];
        final dgRecords = dgRecordsAsync.asData?.value ?? const [];
        // `summarizeDg(...).pending` counts every animal that EVER had a DG
        // for this ATF, including ones since removed or baixa'd (D-20 —
        // correct for the % prenhez header on AtfHeaderCard below). As a
        // live "is every CURRENT member covered" question it answers a
        // different one: when composition churns, the historical total can
        // reach the new composition count and clamp `pending` to 0 even
        // though none of the CURRENT members have a DG (G-05-3). The
        // encerramento gate below needs the live question, so it derives its
        // own per-current-member count instead.
        final dgAnimalIds = dgRecords.map((d) => d.animalId).toSet();
        final pendingMembers = activeMemberships
            .where((m) => !dgAnimalIds.contains(m.animalId))
            .length;
        // Encerramento affordances (AppBar action + banner) are gated on
        // atf.active AND the veterinarian role — never on the banner's own
        // condition, since the AppBar action must stay reachable even when
        // DGs are pending (T-05-49, T-05-53).
        final showEncerrarAction = atf.active && canEdit;
        final showBanner = atf.active &&
            canEdit &&
            activeMemberships.isNotEmpty &&
            pendingMembers == 0;

        return Scaffold(
          appBar: _appBar(
            context,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _GlassStatusPill(active: atf.active),
                if (showEncerrarAction)
                  IconButton(
                    icon: const Icon(Icons.event_busy,
                        color: AppColors.onGreen),
                    tooltip: 'Encerrar ATF',
                    onPressed: () => _showEncerrarDialog(
                      context,
                      atfId: atf.id,
                      atfName: atf.name,
                      pendingCount: pendingMembers,
                    ),
                  ),
              ],
            ),
          ),
          body: LayoutBuilder(
            builder: (context, constraints) {
              final allMemberships =
                  allMembershipsAsync.asData?.value ?? const [];
              if (constraints.maxWidth >= Breakpoints.rail) {
                // >=1024px (quick task 260813-tos): dense table with inline
                // DG registration + batch selection, replacing the mobile
                // green header + merged composição/DG list below.
                final visibleRows =
                    allMemberships.where((m) => !m.animalDeleted).toList();
                return AtfDgTableView(
                  atf: atf,
                  rows: visibleRows,
                  activeMemberships: activeMemberships,
                  dgRecords: dgRecords,
                  pendingMembers: pendingMembers,
                  canEdit: canEdit,
                );
              }
              return Column(
                children: [
                  AtfHeaderCard(
                    atf: atf,
                    activeMemberships: activeMemberships,
                    dgRecords: dgRecords,
                  ),
                  Expanded(
                    child: _AtfDgBody(
                      atf: atf,
                      activeMemberships: activeMemberships,
                      memberships: allMemberships,
                      dgRecords: dgRecords,
                      dgAnimalIds: dgAnimalIds,
                      canEdit: canEdit,
                      showEncerrarBanner: showBanner,
                      pendingMembers: pendingMembers,
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  PreferredSizeWidget _appBar(BuildContext context, {Widget? trailing}) {
    return DetailAppBar(
      parentLabel: 'Reprodução',
      contextPill: trailing,
      // `/atf/:atfId` is a root-level GoRoute reached via `context.go(...)`,
      // which replaces the whole nav stack, so `canPop()` is false on
      // arrival (G-05-1-nav). Falls back to the reproducao shell branch.
      onBack: () {
        if (context.canPop()) {
          context.pop();
          return;
        }
        context.go(AppRoutes.reproducao);
      },
    );
  }

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
}

/// Glass status badge on the green app bar ("Ativo" / "Encerrado", spec 3.1).
class _GlassStatusPill extends StatelessWidget {
  const _GlassStatusPill({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: AppColors.glassPill,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active ? 'Ativo' : 'Encerrado',
        style: const TextStyle(
          fontSize: 11.5,
          fontWeight: FontWeight.w600,
          color: AppColors.onGreen,
        ),
      ),
    );
  }
}

/// Opens [EncerrarAtfDialog] and shows the success confirmation
/// (05-UI-SPEC section 5: "On success ... SnackBar: 'ATF encerrado.'").
/// Provider invalidation happens inside the dialog itself — this helper only
/// surfaces the confirmation once the dialog pops `true`.
Future<void> _showEncerrarDialog(
  BuildContext context, {
  required String atfId,
  required String atfName,
  required int pendingCount,
}) async {
  final confirmed = await showAdaptiveForm<bool>(
    context: context,
    builder: (_) => EncerrarAtfDialog(
      atfId: atfId,
      atfName: atfName,
      pendingCount: pendingCount,
    ),
  );
  if (confirmed == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('ATF encerrado.')),
    );
  }
}

/// Green header block (spec 4.9): ATF name, % prenhez KPI (REPR-04),
/// implantação/inseminação dates, touro link (D-05/WR-01) and observação.
class AtfHeaderCard extends StatelessWidget {
  const AtfHeaderCard({
    super.key,
    required this.atf,
    required this.activeMemberships,
    required this.dgRecords,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> activeMemberships;
  final List<DgRecord> dgRecords;

  @override
  Widget build(BuildContext context) {
    final dateFmt = DateFormat('dd/MM/yyyy');

    final summary = summarizeDg(
      dgRecords,
      compositionCount: activeMemberships.length,
    );
    final percent = summary.percent;
    // A closed ATF has zero active memberships — never show "de 0" under a
    // non-zero DG total.
    final denominator = activeMemberships.length > summary.total
        ? activeMemberships.length
        : summary.total;

    return Container(
      width: double.infinity,
      color: AppColors.primary,
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            atf.name,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.onGreen,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (percent == null)
                const Text(
                  '— · aguardando DG',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.onGreenSecondary,
                  ),
                )
              else ...[
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '$percent',
                        style: monoStyle(
                          size: 30,
                          weight: FontWeight.w700,
                          color: AppColors.onGreen,
                          height: 1,
                        ),
                      ),
                      TextSpan(
                        text: '%',
                        style: monoStyle(
                          size: 15,
                          weight: FontWeight.w700,
                          color: AppColors.onGreenSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(
                    'prenhez · ${summary.total} de $denominator',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppColors.onGreenSecondary,
                    ),
                  ),
                ),
              ],
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  _DateLine(label: 'impl. ', value: dateFmt.format(atf.implantationDate)),
                  const SizedBox(height: 2),
                  _DateLine(label: 'insem. ', value: dateFmt.format(atf.inseminationDate)),
                ],
              ),
            ],
          ),
          if (atf.bullName != null || atf.bullAnimalId != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                const Text(
                  'touro: ',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.onGreenSecondary,
                  ),
                ),
                Flexible(child: _buildBullValue(context)),
              ],
            ),
          ],
          if (atf.observation != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Observação',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: AppColors.onGreenSecondary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    atf.observation!,
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.onGreen,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildBullValue(BuildContext context) {
    if (atf.bullAnimalId != null) {
      // WR-01: bullAnimalId is a navigation target only — it must never be
      // rendered as user-facing text. A legacy row created before the
      // WR-01 fix has bullAnimalId set with bullName null; fall back to a
      // readable link placeholder instead of the raw uuid.
      return InkWell(
        onTap: () => context.go(AppRoutes.animalDetail(atf.bullAnimalId!)),
        child: Text(
          atf.bullName ?? 'Ver touro',
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: AppColors.gold,
            decoration: TextDecoration.underline,
            decorationColor: AppColors.gold,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }
    return Text(
      atf.bullName ?? '—',
      style: const TextStyle(fontSize: 13, color: AppColors.onGreen),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _DateLine extends StatelessWidget {
  const _DateLine({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 11.5,
            color: AppColors.onGreenSecondary,
          ),
        ),
        Text(
          value,
          style: monoStyle(
            size: 12.5,
            weight: FontWeight.w600,
            color: AppColors.onGreen,
          ),
        ),
      ],
    );
  }
}

/// One DG segment button (spec 4.9): Prenhe / Vazia / Duvidosa, h48 r12,
/// result-colored when selected, white outline otherwise. Public so widget
/// tests can pin the selected state per row.
class DgSegmentButton extends StatelessWidget {
  const DgSegmentButton({
    super.key,
    required this.result,
    required this.selected,
    this.onTap,
  });

  final DgResult result;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (Color bg, Color fg) = switch (result) {
      DgResult.pregnant => (AppColors.primary, AppColors.onGreen),
      DgResult.notPregnant => (AppColors.danger, AppColors.onDanger),
      DgResult.doubtful => (AppColors.accent, AppColors.onAccent),
    };

    return Material(
      color: selected ? bg : AppColors.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: selected
            ? BorderSide.none
            : const BorderSide(color: AppColors.outlineBorder),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          height: 48,
          alignment: Alignment.center,
          child: Text(
            result.label,
            style: TextStyle(
              fontSize: 14.5,
              fontWeight: FontWeight.w600,
              color: selected ? fg : AppColors.ink,
            ),
          ),
        ),
      ),
    );
  }
}

/// Everything below the green header: DG session banner, encerramento
/// suggestion banner, the merged composição + DG list (D-06..D-16, REPR-02,
/// REPR-03) and the fixed save footer.
///
/// Reads the UNFILTERED [memberships] list (`atfMembershipsProvider`, not the
/// active-only one) so a closed ATF still shows its full roster for
/// correction (D-16, RESEARCH Pattern 3) — that half of the "unfiltered"
/// claim is about `active` and stays true. It is NOT true of archived
/// animals: [build] filters out any membership whose
/// [AtfMembershipView.animalDeleted] is true, so a baixa'd animal stops
/// appearing as an editable row (G-05-2). Do not "simplify" this into a
/// single filter on `active` — that would resurrect the D-16 regression
/// this split exists to prevent. [canEdit] gates on role only, never on
/// `atf.active` — DG correction stays possible after encerramento.
class _AtfDgBody extends ConsumerStatefulWidget {
  const _AtfDgBody({
    required this.atf,
    required this.activeMemberships,
    required this.memberships,
    required this.dgRecords,
    required this.dgAnimalIds,
    required this.canEdit,
    required this.showEncerrarBanner,
    required this.pendingMembers,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> activeMemberships;
  final List<AtfMembershipView> memberships;
  final List<DgRecord> dgRecords;

  /// Animal ids with at least one PERSISTED DG for this ATF — hoisted once in
  /// [AtfDetailScreen.build] and shared with the encerrar banner gate, the
  /// AppBar pending count, and the per-row remove gate (G-05-3), so they can
  /// never drift from each other.
  final Set<String> dgAnimalIds;
  final bool canEdit;
  final bool showEncerrarBanner;
  final int pendingMembers;

  @override
  ConsumerState<_AtfDgBody> createState() => _AtfDgBodyState();
}

class _AtfDgBodyState extends ConsumerState<_AtfDgBody> {
  // dd/MM/yyyy pattern doesn't need locale symbol data — safe to create eagerly.
  final _dateFmt = DateFormat('dd/MM/yyyy');
  // yyyy-MM-dd, no timezone conversion — for the date-only exam_date field
  // sent to save_dg_records (WR-03).
  final _dateOnlyFmt = DateFormat('yyyy-MM-dd');

  DateTime _sessionDate = DateTime.now();

  /// Staged (not-yet-saved) selection per animal id — separate from the
  /// "currently displayed" value so the changed-rows set stays computable
  /// (D-12: a re-tap stages a NEW record rather than overwriting history).
  final Map<String, DgResult> _staged = {};
  final Map<String, DateTime> _dateOverrides = {};
  final Set<String> _expandedObservation = {};
  final Map<String, TextEditingController> _obsControllers = {};
  bool _saving = false;

  @override
  void dispose() {
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Most-recent DG for [animalId] in this ATF (D-12's tie-breaker: the
  /// exam-date rule in [isLaterDg], G-05-4). Delegates to [latestDgFor] —
  /// the single shared implementation `AtfDgTableView` also uses.
  DgResult? _mostRecentDg(String animalId) {
    final latest = latestDgFor(widget.dgRecords, animalId);
    return latest == null ? null : DgResult.fromDb(latest.result);
  }

  /// Animal ids whose staged selection differs from the currently-displayed
  /// (most-recent) DG — the batch-save payload is built from exactly these.
  Set<String> _changedAnimalIds() {
    final changed = <String>{};
    for (final entry in _staged.entries) {
      if (entry.value != _mostRecentDg(entry.key)) changed.add(entry.key);
    }
    // CR-01 (05-REVIEW.md): a typed observation must be saved even when the
    // DG chip selection for that row never changed — otherwise it is
    // silently dropped whenever some OTHER row in the batch has a real
    // change (which is what makes the save button enabled at all). Guarded
    // on a resolvable result because dg_records.result is NOT NULL — a row
    // with no DG history AND no staged chip has nothing to persist yet.
    for (final entry in _obsControllers.entries) {
      if (entry.value.text.trim().isEmpty) continue;
      final animalId = entry.key;
      if (_staged.containsKey(animalId) || _mostRecentDg(animalId) != null) {
        changed.add(animalId);
      }
    }
    return changed;
  }

  Future<void> _pickSessionDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _sessionDate = picked);
    }
  }

  Future<void> _pickRowDate(String animalId) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateOverrides[animalId] ?? _sessionDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _dateOverrides[animalId] = picked);
    }
  }

  void _toggleObservation(String animalId) {
    setState(() {
      if (_expandedObservation.contains(animalId)) {
        _expandedObservation.remove(animalId);
      } else {
        _expandedObservation.add(animalId);
        _obsControllers.putIfAbsent(animalId, () => TextEditingController());
      }
    });
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

  Future<void> _confirmRemove(AtfMembershipView membership) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveAnimalConfirmDialog(
        animalNumber: membership.animalNumber,
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(atfRepositoryProvider).removeAnimalFromAtf(
            atfBatchId: widget.atf.id,
            animalId: membership.animalId,
          );
      if (!mounted) return;
      ref.invalidatePropertyData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover animal. Tente novamente.'),
        ),
      );
    }
  }

  Future<void> _save() async {
    final changed = _changedAnimalIds();
    if (changed.isEmpty) return;

    final records = [
      for (final animalId in changed)
        {
          'animal_id': animalId,
          // Obs-only rows (chip untouched) have no _staged entry — fall
          // back to the currently-displayed (most-recent persisted) DG so
          // 'result' is never force-unwrapped null (CR-01, 05-REVIEW.md).
          'result': (_staged[animalId] ?? _mostRecentDg(animalId))!.dbValue,
          'exam_date': _dateOnlyFmt
              .format(_dateOverrides[animalId] ?? _sessionDate),
          if ((_obsControllers[animalId]?.text.trim() ?? '').isNotEmpty)
            'observation': _obsControllers[animalId]!.text.trim(),
        },
    ];

    setState(() => _saving = true);
    try {
      await ref.read(atfRepositoryProvider).saveDgRecords(
            atfBatchId: widget.atf.id,
            records: records,
          );
      if (!mounted) return;
      ref.invalidatePropertyData();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('DGs registrados.')),
      );
    } catch (_) {
      // Staged selections are intentionally NOT cleared here — the vet does
      // not re-walk the herd because of a bad connection in the field.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao salvar DGs. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Archived animals never render a row (G-05-2) — NOT gated on the
    // `active` flag, since a closed ATF's rows report active:false yet must
    // still render for D-16 correction.
    final rows = widget.memberships.where((m) => !m.animalDeleted).toList();

    final editable = widget.canEdit && !_saving;
    final changedIds = _changedAnimalIds();
    final showAddButton = widget.atf.active && widget.canEdit;
    final activeCount = widget.activeMemberships.length;

    return Column(
      children: [
        if (widget.canEdit && rows.isNotEmpty)
          _SessionBanner(
            dateLabel: _dateFmt.format(_sessionDate),
            onAlterar: editable ? _pickSessionDate : null,
          ),
        Expanded(
          child: Container(
            color: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (widget.showEncerrarBanner)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                    child: _EncerrarBanner(
                      atfId: widget.atf.id,
                      atfName: widget.atf.name,
                      pendingCount: widget.pendingMembers,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 8, 4),
                  child: Row(
                    children: [
                      const OverlineLabel('Composição'),
                      const SizedBox(width: 8),
                      Text(
                        '$activeCount '
                        '${activeCount == 1 ? 'animal' : 'animais'}',
                        style: monoStyle(
                          size: 12.5,
                          weight: FontWeight.w600,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const Spacer(),
                      if (showAddButton)
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding:
                                const EdgeInsets.symmetric(horizontal: 12),
                            shape: const StadiumBorder(),
                            foregroundColor: AppColors.primaryDarkText,
                          ),
                          onPressed: _openSelection,
                          icon: const Icon(Icons.add, size: 18),
                          label: const Text('Animais'),
                        ),
                    ],
                  ),
                ),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Nenhum animal neste ATF.'),
                        if (showAddButton) ...[
                          const SizedBox(height: 10),
                          OutlinedButton(
                            onPressed: _openSelection,
                            child: const Text('Adicionar animais'),
                          ),
                        ],
                      ],
                    ),
                  )
                else
                  for (final m in rows) _buildRow(m, editable, changedIds),
              ],
            ),
          ),
        ),
        if (widget.canEdit && rows.isNotEmpty)
          _SaveFooter(
            changedCount: changedIds.length,
            saving: _saving,
            onSave:
                (changedIds.isEmpty || _saving) ? null : _save,
          ),
      ],
    );
  }

  Widget _buildRow(
    AtfMembershipView m,
    bool editable,
    Set<String> changedIds,
  ) {
    final selected = _staged[m.animalId] ?? _mostRecentDg(m.animalId);
    final expanded = _expandedObservation.contains(m.animalId);
    final hasDg = widget.dgAnimalIds.contains(m.animalId);
    final canRemove =
        widget.atf.active && widget.canEdit && m.active && !hasDg;
    final changed = changedIds.contains(m.animalId);

    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: () =>
                      context.go(AppRoutes.animalDetail(m.animalId)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '#${m.animalNumber}',
                            style: monoStyle(
                              size: 17,
                              weight: FontWeight.w700,
                            ),
                          ),
                          TextSpan(
                            text:
                                '  ${kCategoryLabels[m.animalCategory] ?? m.animalCategory}',
                            style: const TextStyle(
                              fontSize: 14,
                              color: AppColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ),
              if (changed) ...[
                const StatusChip('não salvo', kind: StatusKind.warning),
                const SizedBox(width: 2),
              ],
              // Papel negado (widget.canEdit false) vê estes dois controles
              // AUSENTES, nunca desabilitados — segue o mesmo padrão de
              // `canRemove` logo abaixo. `editable` (que também considera
              // `_saving`) governaria a variante desabilitada durante o
              // save, mas isso só se aplica ao veterinário; o gate de
              // presença/ausência é sempre `widget.canEdit`.
              if (widget.canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.event, size: 20),
                  tooltip: 'Alterar data deste animal',
                  onPressed: editable ? () => _pickRowDate(m.animalId) : null,
                ),
                IconButton(
                  icon: const Icon(Icons.notes, size: 20),
                  tooltip: 'Adicionar observação',
                  onPressed:
                      editable ? () => _toggleObservation(m.animalId) : null,
                ),
              ],
              if (canRemove)
                IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Remover do ATF',
                  onPressed: () => _confirmRemove(m),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: widget.canEdit
                ? Row(
                    children: [
                      for (final r in DgResult.values) ...[
                        if (r != DgResult.values.first)
                          const SizedBox(width: 8),
                        Expanded(
                          child: DgSegmentButton(
                            result: r,
                            selected: selected == r,
                            onTap: editable
                                ? () =>
                                    setState(() => _staged[m.animalId] = r)
                                : null,
                          ),
                        ),
                      ],
                    ],
                  )
                // Papel negado: resultado do DG como texto estático, nunca
                // um segmento desabilitado (T-g9j-09).
                : Align(
                    alignment: Alignment.centerLeft,
                    child: selected == null
                        ? const Text(
                            'Sem DG',
                            style: TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                          )
                        : StatusChip(
                            selected.label,
                            kind: switch (selected) {
                              DgResult.pregnant => StatusKind.positive,
                              DgResult.notPregnant => StatusKind.danger,
                              DgResult.doubtful => StatusKind.warning,
                            },
                          ),
                  ),
          ),
          if (expanded && _obsControllers[m.animalId] != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, right: 8),
              child: TextFormField(
                controller: _obsControllers[m.animalId],
                enabled: editable,
                // CR-01 (05-REVIEW.md): typing alone must recompute
                // changedCount so "Salvar DGs" reflects an obs-only edit —
                // without this the button stays stuck disabled since typing
                // into the controller does not otherwise trigger a rebuild.
                onChanged: (_) => setState(() {}),
                // Obs box bg #F5F3EB (spec 4.9).
                decoration: const InputDecoration(
                  labelText: 'Observação',
                  filled: true,
                  fillColor: AppColors.background,
                ),
                minLines: 1,
                maxLines: null,
              ),
            ),
        ],
      ),
    );
  }
}

/// Orange DG session-date banner (spec 4.9): the date every staged DG uses
/// unless the row has its own override via the per-row `event` icon.
class _SessionBanner extends StatelessWidget {
  const _SessionBanner({required this.dateLabel, this.onAlterar});

  final String dateLabel;
  final VoidCallback? onAlterar;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.accentContainer,
        border: Border(bottom: BorderSide(color: AppColors.accentBorder)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: Row(
        children: [
          const Icon(Icons.event_available,
              size: 20, color: AppColors.accentDark),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const OverlineLabel(
                  'Sessão de DG',
                  color: AppColors.accentTextDark,
                ),
                const SizedBox(height: 2),
                Text(
                  dateLabel,
                  style: monoStyle(size: 15, weight: FontWeight.w700),
                ),
              ],
            ),
          ),
          OutlinedButton(
            style: OutlinedButton.styleFrom(
              minimumSize: const Size(0, 36),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              shape: const StadiumBorder(),
              backgroundColor: Colors.transparent,
              foregroundColor: AppColors.accentTextDark,
              side: const BorderSide(color: Color(0x598A4413)),
              textStyle: const TextStyle(
                fontFamily: AppFonts.ui,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            onPressed: onAlterar,
            child: const Text('Alterar'),
          ),
        ],
      ),
    );
  }
}

/// Fixed save footer (spec 4.9): changed-rows count + "Salvar DGs".
class _SaveFooter extends StatelessWidget {
  const _SaveFooter({
    required this.changedCount,
    required this.saving,
    required this.onSave,
  });

  final int changedCount;
  final bool saving;
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            Expanded(
              child: Text.rich(
                TextSpan(
                  children: [
                    TextSpan(
                      text: '$changedCount',
                      style: monoStyle(size: 17, weight: FontWeight.w700),
                    ),
                    TextSpan(
                      text:
                          ' ${changedCount == 1 ? 'alteração' : 'alterações'}',
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: SizedBox(
                height: 52,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  onPressed: onSave,
                  child: saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Salvar DGs'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Minimal confirm dialog for removing an animal from the ATF (D-08).
///
/// Unlike `BaixaDialog`, this is a correction, not data loss — the confirm
/// button keeps the default primary color rather than `colorScheme.error`.
class _RemoveAnimalConfirmDialog extends StatelessWidget {
  const _RemoveAnimalConfirmDialog({required this.animalNumber});

  final int animalNumber;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Remover #$animalNumber do ATF?'),
      content: const Text('O animal deixa de fazer parte deste ciclo.'),
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
    );
  }
}

/// Encerramento suggestion banner (D-15, 05-UI-SPEC section 3): a suggestion,
/// never an action taken on the vet's behalf. Rendered by the parent only
/// when the ATF is active, the viewer is a veterinarian, the composition is
/// non-empty, and every CURRENT member has a DG ([pendingCount] is zero) —
/// the caller computes and gates on that condition; this widget only owns
/// its own session-local dismissal state.
///
/// Dismissal does not persist: it is lost on any rebuild that recreates this
/// widget (e.g. navigating away and back), by design (D-15's "reappears on
/// the next visit" while the underlying condition still holds — A-BANNER-PERSIST).
class _EncerrarBanner extends StatefulWidget {
  const _EncerrarBanner({
    required this.atfId,
    required this.atfName,
    required this.pendingCount,
  });

  final String atfId;
  final String atfName;

  /// Same per-current-member pending count the parent gated `showBanner` on
  /// (G-05-3). Passed straight through to [_showEncerrarDialog] so the
  /// confirm dialog can never disagree with the banner that summoned it.
  final int pendingCount;

  @override
  State<_EncerrarBanner> createState() => _EncerrarBannerState();
}

class _EncerrarBannerState extends State<_EncerrarBanner> {
  bool _dismissed = false;

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    return WarningBanner(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
        child: Row(
          children: [
            const Icon(Icons.pending_actions,
                size: 20, color: AppColors.accentDark),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Todos os animais têm DG registrado.',
                style: TextStyle(
                  fontSize: 13.5,
                  color: AppColors.accentTextDark,
                ),
              ),
            ),
            TextButton(
              onPressed: () => _showEncerrarDialog(
                context,
                atfId: widget.atfId,
                atfName: widget.atfName,
                pendingCount: widget.pendingCount,
              ),
              child: const Text('Encerrar ATF'),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Dispensar aviso',
              onPressed: () => setState(() => _dismissed = true),
            ),
          ],
        ),
      ),
    );
  }
}
