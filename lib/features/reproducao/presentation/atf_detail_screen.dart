import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../animais/data/animal_constants.dart';
import '../../auth/data/property_repository.dart';
import '../data/atf_model.dart';
import '../data/atf_repository.dart';
import '../data/dg_record_model.dart';
import '../data/dg_summary.dart';
import 'atf_animal_selection_screen.dart';

/// ATF detail screen (`/atf/:atfId`, root-level per D-02).
///
/// This plan (05-04) built the shell + [AtfHeaderCard]. Plan 05-06 adds
/// [_CompositionSection] and the remove-animal flow. DG entry and the
/// encerramento banner/action are added in later waves (05-08, 05-09) that
/// edit this same file.
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
        appBar: AppBar(title: const Text('ATF')),
        body: const Center(child: CircularProgressIndicator()),
      ),
      error: (err, st) => Scaffold(
        appBar: AppBar(title: const Text('ATF')),
        body: const Center(
          child: Text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
        ),
      ),
      data: (atf) {
        if (atf == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('ATF')),
            body: const Center(
              child: Text('Erro ao carregar. Verifique sua conexão e tente novamente.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(atf.name)),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              AtfHeaderCard(
                atf: atf,
                activeMemberships: membershipsAsync.asData?.value ?? const [],
                dgRecords: dgRecordsAsync.asData?.value ?? const [],
              ),
              const SizedBox(height: 16),
              _CompositionSection(
                atf: atf,
                activeMemberships: membershipsAsync.asData?.value ?? const [],
                dgRecords: dgRecordsAsync.asData?.value ?? const [],
                canEdit: canEdit,
              ),
              const SizedBox(height: 16),
              _DgSection(
                atf: atf,
                memberships: allMembershipsAsync.asData?.value ?? const [],
                dgRecords: dgRecordsAsync.asData?.value ?? const [],
                canEdit: canEdit,
              ),
            ],
          ),
        );
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

/// Header card: ATF name + status badge, key-value rows (implantação,
/// inseminação, touro, observação), and the % prenhez indicator (REPR-04).
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final dateFmt = DateFormat('dd/MM/yyyy');

    final summary = summarizeDg(
      dgRecords,
      compositionCount: activeMemberships.length,
    );
    final compositionCount = activeMemberships.length;
    final progress = compositionCount == 0
        ? 0.0
        : (summary.total / compositionCount).clamp(0.0, 1.0);

    return Card(
      color: colorScheme.surfaceContainerHighest,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.favorite_border),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(atf.name, style: theme.textTheme.titleMedium),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    atf.active ? 'Ativo' : 'Encerrado',
                    style: theme.textTheme.labelSmall
                        ?.copyWith(color: colorScheme.onSurface),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data de implantação',
              value: Text(dateFmt.format(atf.implantationDate)),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Data de inseminação',
              value: Text(dateFmt.format(atf.inseminationDate)),
            ),
            const SizedBox(height: 8),
            _KvRow(
              label: 'Touro',
              value: _buildBullValue(context),
            ),
            if (atf.observation != null) ...[
              const SizedBox(height: 8),
              _KvRow(
                label: 'Observação',
                value: Text(atf.observation!),
              ),
            ],
            const SizedBox(height: 12),
            Text(
              formatPrenhez(summary),
              style: theme.textTheme.bodyLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: colorScheme.primary,
              ),
            ),
            const SizedBox(height: 4),
            LinearProgressIndicator(value: progress),
          ],
        ),
      ),
    );
  }

  Widget _buildBullValue(BuildContext context) {
    if (atf.bullAnimalId != null) {
      return InkWell(
        onTap: () => context.go(AppRoutes.animalDetail(atf.bullAnimalId!)),
        child: Text(
          atf.bullName ?? atf.bullAnimalId!,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            decoration: TextDecoration.underline,
          ),
        ),
      );
    }
    return Text(atf.bullName ?? '—');
  }
}

/// Key-value row: label (fixed width 120) + expanded value widget.
///
/// Copied from `animal_detail_screen.dart`'s `_KvRow` rather than shared
/// across features — matches the codebase's established duplication
/// convention for this widget (A-KVROW-DUP).
class _KvRow extends StatelessWidget {
  const _KvRow({required this.label, required this.value});

  final String label;
  final Widget value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context)
                      .colorScheme
                      .onSurface
                      .withValues(alpha: 0.6),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}

/// Composition section (D-06/D-07/D-08, REPR-02): the active membership list
/// plus the "+ Animais" affordance and the remove-animal flow.
///
/// Renders from already-resolved lists (mirrors [AtfHeaderCard]'s
/// convention) rather than watching the providers itself — 05-UI-SPEC E5
/// "loading/error inherited from the parent screen, no independent spinner".
class _CompositionSection extends ConsumerWidget {
  const _CompositionSection({
    required this.atf,
    required this.activeMemberships,
    required this.dgRecords,
    required this.canEdit,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> activeMemberships;
  final List<DgRecord> dgRecords;
  final bool canEdit;

  void _openSelection(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            AtfAnimalSelectionScreen(atfId: atf.id, atfName: atf.name),
      ),
    );
  }

  Future<void> _confirmRemove(
    BuildContext context,
    WidgetRef ref,
    AtfMembershipView membership,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => _RemoveAnimalConfirmDialog(
        animalNumber: membership.animalNumber,
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(atfRepositoryProvider).removeAnimalFromAtf(
            atfBatchId: atf.id,
            animalId: membership.animalId,
          );
      if (!context.mounted) return;
      ref.invalidate(atfActiveMembershipsProvider(atf.id));
      ref.invalidate(atfMembershipsProvider(atf.id));
      ref.invalidate(atfListByPropertyProvider);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao remover animal. Tente novamente.'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final showAddButton = atf.active && canEdit;
    final dgAnimalIds = dgRecords.map((d) => d.animalId).toSet();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text('Composição', style: theme.textTheme.titleMedium),
            const SizedBox(width: 8),
            Text(
              '(${activeMemberships.length} animais)',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const Spacer(),
            if (showAddButton)
              OutlinedButton.icon(
                onPressed: () => _openSelection(context),
                icon: const Icon(Icons.add),
                label: const Text('Animais'),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (activeMemberships.isEmpty)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Nenhum animal neste ATF.',
                style: theme.textTheme.bodyMedium,
              ),
              if (showAddButton) ...[
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => _openSelection(context),
                  child: const Text('Adicionar animais'),
                ),
              ],
            ],
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeMemberships.length,
            itemBuilder: (context, i) {
              final m = activeMemberships[i];
              final hasDg = dgAnimalIds.contains(m.animalId);
              final canRemove = atf.active && canEdit && !hasDg;
              return ListTile(
                title: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '#${m.animalNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text:
                            ' · ${kCategoryLabels[m.animalCategory] ?? m.animalCategory}',
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                onTap: () => context.go(AppRoutes.animalDetail(m.animalId)),
                trailing: canRemove
                    ? IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Remover do ATF',
                        onPressed: () => _confirmRemove(context, ref, m),
                      )
                    : null,
              );
            },
          ),
      ],
    );
  }
}

/// Minimal confirm dialog for removing an animal from the ATF (D-08).
///
/// Unlike [BaixaDialog], this is a correction, not data loss — the confirm
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

/// DG mass-entry section (D-10, D-11, D-12, REPR-03, 05-UI-SPEC E6): the
/// phone-in-the-corral surface — one session date, one row per animal, three
/// chips per row, one batch save.
///
/// Reads the UNFILTERED [memberships] list (`atfMembershipsProvider`, not the
/// active-only one) so a closed ATF still shows its full roster for
/// correction (D-16, RESEARCH Pattern 3). [canEdit] gates on role only, never
/// on `atf.active` — DG correction stays possible after encerramento.
class _DgSection extends ConsumerStatefulWidget {
  const _DgSection({
    required this.atf,
    required this.memberships,
    required this.dgRecords,
    required this.canEdit,
  });

  final AtfBatch atf;
  final List<AtfMembershipView> memberships;
  final List<DgRecord> dgRecords;
  final bool canEdit;

  @override
  ConsumerState<_DgSection> createState() => _DgSectionState();
}

class _DgSectionState extends ConsumerState<_DgSection> {
  // dd/MM/yyyy pattern doesn't need locale symbol data — safe to create eagerly.
  final _dateFmt = DateFormat('dd/MM/yyyy');

  DateTime _sessionDate = DateTime.now();
  late final TextEditingController _sessionDateCtrl;

  /// Staged (not-yet-saved) selection per animal id — separate from the
  /// "currently displayed" value so the changed-rows set stays computable
  /// (D-12: a re-tap stages a NEW record rather than overwriting history).
  final Map<String, DgResult> _staged = {};
  final Map<String, DateTime> _dateOverrides = {};
  final Set<String> _expandedObservation = {};
  final Map<String, TextEditingController> _obsControllers = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _sessionDateCtrl = TextEditingController(text: _dateFmt.format(_sessionDate));
  }

  @override
  void dispose() {
    _sessionDateCtrl.dispose();
    for (final c in _obsControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  /// Most-recent DG for [animalId] in this ATF (D-12's tie-breaker:
  /// `createdAt`, per A-DG-ORDER).
  DgResult? _mostRecentDg(String animalId) {
    DgRecord? latest;
    for (final r in widget.dgRecords) {
      if (r.animalId != animalId) continue;
      if (latest == null || r.createdAt.isAfter(latest.createdAt)) {
        latest = r;
      }
    }
    return latest == null ? null : DgResult.fromDb(latest.result);
  }

  /// Animal ids whose staged selection differs from the currently-displayed
  /// (most-recent) DG — the batch-save payload is built from exactly these.
  Set<String> _changedAnimalIds() {
    final changed = <String>{};
    for (final entry in _staged.entries) {
      if (entry.value != _mostRecentDg(entry.key)) changed.add(entry.key);
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
      setState(() {
        _sessionDate = picked;
        _sessionDateCtrl.text = _dateFmt.format(picked);
      });
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

  Future<void> _save() async {
    final changed = _changedAnimalIds();
    if (changed.isEmpty) return;

    final records = [
      for (final animalId in changed)
        {
          'animal_id': animalId,
          'result': _staged[animalId]!.dbValue,
          'exam_date': (_dateOverrides[animalId] ?? _sessionDate)
              .toUtc()
              .toIso8601String()
              .substring(0, 10),
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
      ref.invalidate(dgRecordsByAtfProvider(widget.atf.id));
      ref.invalidate(atfByIdProvider(widget.atf.id));
      ref.invalidate(atfListByPropertyProvider);
      for (final animalId in changed) {
        ref.invalidate(reproductiveHistoryByAnimalProvider(animalId));
      }
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
    // Hidden entirely when the ATF has no memberships at all (05-UI-SPEC E4)
    // — NOT gated on the `active` flag per row, since a closed ATF's rows
    // report active:false yet must still render for D-16 correction.
    if (widget.memberships.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final editable = widget.canEdit && !_saving;
    final changedCount = _changedAnimalIds().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Registrar DG', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        TextFormField(
          readOnly: true,
          controller: _sessionDateCtrl,
          decoration: InputDecoration(
            labelText: 'Data da sessão',
            border: const OutlineInputBorder(),
            suffixIcon: IconButton(
              icon: const Icon(Icons.calendar_today),
              tooltip: 'Alterar data da sessão',
              onPressed: editable ? _pickSessionDate : null,
            ),
          ),
        ),
        const SizedBox(height: 8),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: widget.memberships.length,
          itemBuilder: (context, i) {
            final m = widget.memberships[i];
            final selected = _staged[m.animalId] ?? _mostRecentDg(m.animalId);
            final expanded = _expandedObservation.contains(m.animalId);
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: _DgChipRow(
                membership: m,
                selected: selected,
                canEdit: editable,
                observationExpanded: expanded,
                observationController: _obsControllers[m.animalId],
                onSelect: (r) => setState(() => _staged[m.animalId] = r),
                onPickDate: () => _pickRowDate(m.animalId),
                onToggleObservation: () => _toggleObservation(m.animalId),
              ),
            );
          },
        ),
        if (widget.canEdit) ...[
          const SizedBox(height: 8),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: (changedCount == 0 || _saving) ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Salvar DGs'),
            ),
          ),
        ],
      ],
    );
  }
}

/// One DG entry row: animal number/category, three result chips, and the
/// per-animal date-override / observation icon actions.
///
/// Reuses [AnimalEditDialog]'s EC `ChoiceChip` `Wrap` pattern with the
/// DG-specific semantic color mapping (05-UI-SPEC `## Color`) and the raised
/// 48px touch target (05-UI-SPEC `## Spacing Scale` mobile exception).
class _DgChipRow extends StatelessWidget {
  const _DgChipRow({
    required this.membership,
    required this.selected,
    required this.canEdit,
    required this.observationExpanded,
    required this.observationController,
    required this.onSelect,
    required this.onPickDate,
    required this.onToggleObservation,
  });

  final AtfMembershipView membership;
  final DgResult? selected;
  final bool canEdit;
  final bool observationExpanded;
  final TextEditingController? observationController;
  final ValueChanged<DgResult> onSelect;
  final VoidCallback onPickDate;
  final VoidCallback onToggleObservation;

  Color _selectedBg(ColorScheme cs, DgResult r) => switch (r) {
        DgResult.pregnant => cs.primaryContainer,
        DgResult.notPregnant => cs.errorContainer,
        DgResult.doubtful => cs.tertiaryContainer,
      };

  Color _selectedFg(ColorScheme cs, DgResult r) => switch (r) {
        DgResult.pregnant => cs.onPrimaryContainer,
        DgResult.notPregnant => cs.onErrorContainer,
        DgResult.doubtful => cs.onTertiaryContainer,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    Widget buildChip(DgResult r) {
      final isSelected = selected == r;
      return ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: ChoiceChip(
          label: Text(
            r.label,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isSelected
                  ? _selectedFg(colorScheme, r)
                  : colorScheme.onSurface,
            ),
          ),
          selected: isSelected,
          showCheckmark: false,
          selectedColor: _selectedBg(colorScheme, r),
          side: isSelected ? null : BorderSide(color: colorScheme.outline),
          onSelected: canEdit ? (_) => onSelect(r) : null,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 90,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(
                        text: '#${membership.animalNumber}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      TextSpan(
                        text: ' · ${kCategoryLabels[membership.animalCategory] ?? membership.animalCategory}',
                      ),
                    ],
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            Expanded(
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: DgResult.values.map(buildChip).toList(),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.event),
              tooltip: 'Alterar data deste animal',
              onPressed: canEdit ? onPickDate : null,
            ),
            IconButton(
              icon: const Icon(Icons.notes),
              tooltip: 'Adicionar observação',
              onPressed: canEdit ? onToggleObservation : null,
            ),
          ],
        ),
        if (observationExpanded && observationController != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: TextFormField(
              controller: observationController,
              enabled: canEdit,
              decoration: const InputDecoration(
                labelText: 'Observação',
                border: OutlineInputBorder(),
              ),
              minLines: 1,
              maxLines: null,
            ),
          ),
        const Divider(height: 16),
      ],
    );
  }
}
