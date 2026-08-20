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
import '../../animais/data/animal_repository.dart';
import '../../auth/data/property_repository.dart';
import '../../planilhas/domain/sheet_schema.dart';
import '../../planilhas/presentation/doses_grid_view.dart';
import '../../planilhas/presentation/export_button.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/dose_model.dart';
import '../data/dose_repository.dart';
import '../data/kg_per_ua_resolver.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';
import 'aplicacao_form_dialog.dart';
import 'dose_form_dialog.dart';
import 'registrar_aplicacao_screen.dart';
import 'sanitario_table_views.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// `#,##0.##` mL figures — mirrors `aplicacao_detail_screen.dart`'s
/// file-local dosage formatter (06-05 decision): none of the three shared
/// `sanitary_calculations.dart` helpers (UA/volume/currency) fit a plain
/// mL/kg or mL/UA number.
final NumberFormat _dosageFmt = NumberFormat('#,##0.##', 'pt_BR');

/// The sanitary module's whole two-tab shell (`/sanitario` shell branch,
/// D-16), redesigned per spec 4.11: `CampoAppBar` + segmented control
/// "Aplicações"/"Doses" (local state). Tab 1 is the global applications
/// list (SANI-04); Tab 2 is the dose cadastro (SANI-01). Both FAB actions
/// and the filter/toggle state below live on this single widget so every
/// child reads one source (D-26, D-29).
class SanitarioScreen extends ConsumerStatefulWidget {
  const SanitarioScreen({super.key});

  @override
  ConsumerState<SanitarioScreen> createState() => _SanitarioScreenState();
}

class _SanitarioScreenState extends ConsumerState<SanitarioScreen> {
  bool _dosesGridMode = false;

  /// 0 = Aplicações, 1 = Doses (segmented control, spec 4.11).
  int _tab = 0;

  /// Tracks the last-seeded raw query string (not a one-shot bool) so a
  /// second in-branch navigation with different `lote`/`animal` params
  /// (e.g. `Ver todas` from a different ficha) reseeds the filters instead
  /// of being silently dropped — this screen's `State` survives navigation
  /// within its `StatefulShellBranch` (WR-01). `GoRouterState.of(context)`
  /// cannot be read in `initState`, so seeding happens in `build`,
  /// synchronously before the tree is returned.
  String? _lastSeededQuery;

  // Applications tab filters (D-26) — held here so both the filter row and
  // the list below read the same source.
  bool _showReversed = false;
  String? _lotFilterId;
  String? _doseFilterId;
  DateTimeRange? _dateRangeFilter;
  String? _animalFilterId;

  // Doses tab.
  bool _showArchived = false;

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

  /// Reads `lote`/`animal` query parameters and seeds the matching filter
  /// (this is what makes the "Ver todas" action on the embedded history
  /// sections, `sanitary_history_section.dart`, land here pre-filtered),
  /// switching to the applications tab when either is present.
  void _seedFiltersFromQuery(BuildContext context) {
    final query = GoRouterState.of(context).uri.query;
    if (query == _lastSeededQuery) return;
    _lastSeededQuery = query;
    final queryParameters = GoRouterState.of(context).uri.queryParameters;
    final lote = queryParameters['lote'];
    final animal = queryParameters['animal'];
    if (lote != null) _lotFilterId = lote;
    if (animal != null) _animalFilterId = animal;
    if (lote != null || animal != null) _tab = 0;
  }

  /// Redesigned entry point (spec 4.10): pushes the single-screen
  /// registration flow directly — no header dialog hop anymore.
  Future<void> _openRegistrarAplicacao() async {
    final count = await Navigator.of(context, rootNavigator: true).push<int>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => const RegistrarAplicacaoScreen(),
      ),
    );
    if (count == null || !mounted) return;
    ref.invalidatePropertyData();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(sanitaryRegisteredMessage(count))),
    );
  }

  Future<void> _openDoseForm({Dose? existing}) async {
    final saved = await showAdaptiveForm<bool>(
      context: context,
      builder: (_) => DoseFormDialog(existing: existing),
    );
    if (saved != true || !mounted) return;
    ref.invalidatePropertyData();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Dose salva.')));
  }

  Future<void> _toggleArchive(Dose dose) async {
    final repo = ref.read(doseRepositoryProvider);
    try {
      if (dose.isArchived) {
        await repo.restoreDose(dose.id);
      } else {
        await repo.archiveDose(dose.id);
      }
      ref.invalidatePropertyData();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            dose.isArchived
                ? 'Não foi possível reativar a dose. Tente novamente.'
                : 'Não foi possível arquivar a dose. Tente novamente.',
          ),
        ),
      );
    }
  }

  Widget? _buildFab(bool canEdit, SelectedProperty? property) {
    if (!canEdit || property == null) return null;
    if (_tab == 0) {
      return FloatingActionButton.extended(
        onPressed: _openRegistrarAplicacao,
        icon: const Icon(Icons.add),
        label: const Text('Aplicação'),
      );
    }
    return FloatingActionButton.extended(
      onPressed: () => _openDoseForm(),
      icon: const Icon(Icons.add),
      label: const Text('Dose'),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Reset local filters when the active property actually changes (not on
    // the first resolve, null -> A) — otherwise this fires on initial load
    // and wipes the `?lote=`/`?animal=` deep-link filters seeded in
    // `_seedFiltersFromQuery` above, which this screen's `build()` runs
    // before this listener would even have a "previous" value.
    ref.listen(currentPropertyProvider, (prev, next) {
      final prevId = prev?.value?.id;
      final nextId = next.value?.id;
      if (prevId == null || nextId == null || prevId == nextId) return;
      setState(() {
        _lotFilterId = null;
        _animalFilterId = null;
      });
    });

    _seedFiltersFromQuery(context);

    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final currentProperty = currentPropAsync.asData?.value;
    final canEdit = _canEdit(currentProperty, membersAsync.asData?.value);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isDesktop = constraints.maxWidth >= Breakpoints.rail;

        return Scaffold(
          appBar: const CampoAppBar(title: 'Sanitário'),
          body: Column(
            children: [
              if (isDesktop) _buildDesktopHeader(canEdit, currentProperty),
              Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
                child: isDesktop
                    ? Align(
                        alignment: Alignment.centerLeft,
                        child: SizedBox(
                          width: 320,
                          height: 40,
                          child: _buildSegmented(),
                        ),
                      )
                    : SizedBox(
                        width: double.infinity,
                        height: 40,
                        child: _buildSegmented(),
                      ),
              ),
              Expanded(
                child: _tab == 0
                    ? _buildApplicationsTab(canEdit, isDesktop)
                    : _buildDosesTab(canEdit, isDesktop),
              ),
            ],
          ),
          floatingActionButton:
              isDesktop ? null : _buildFab(canEdit, currentProperty),
        );
      },
    );
  }

  SegmentedButton<int> _buildSegmented() {
    return SegmentedButton<int>(
      segments: const [
        ButtonSegment(value: 0, label: Text('Aplicações')),
        ButtonSegment(value: 1, label: Text('Doses')),
      ],
      selected: {_tab},
      showSelectedIcon: false,
      style: SegmentedButton.styleFrom(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(11),
        ),
      ),
      onSelectionChanged: (s) => setState(() => _tab = s.first),
    );
  }

  /// Header desktop (>=1024px): título + subtítulo mono com contagens +
  /// botão primário da aba ativa. O segmented e o FAB continuam fora daqui.
  Widget _buildDesktopHeader(bool canEdit, SelectedProperty? currentProperty) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Sanitário',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  _desktopSubtitle(),
                  style: monoStyle(size: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          _buildExportButton(currentProperty),
          if (canEdit && currentProperty != null) ...[
            if (_tab == 0) ...[
              const SizedBox(width: 10),
              OutlinedButton.icon(
                onPressed: () => context.push(AppRoutes.sanitarioGrade),
                icon: const Icon(Icons.grid_on, size: 20),
                label: const Text('Grade'),
              ),
            ],
            const SizedBox(width: 10),
            OutlinedButton.icon(
              onPressed: () => context.push(AppRoutes.importarFor(
                  _tab == 0 ? 'sanitario' : 'doses')),
              icon: const Icon(Icons.upload_outlined, size: 20),
              label: const Text('Importar'),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              onPressed:
                  _tab == 0 ? _openRegistrarAplicacao : () => _openDoseForm(),
              icon: const Icon(Icons.add, size: 20),
              label: Text(_tab == 0 ? 'Nova aplicação' : 'Nova dose'),
            ),
          ],
        ],
      ),
    );
  }

  /// Exporta a tab ativa: Aplicações = 1 linha por animal do snapshot
  /// (após filtros da tela); Doses = catálogo visível.
  Widget _buildExportButton(SelectedProperty? currentProperty) {
    final propertyName = currentProperty?.name ?? '';
    if (_tab == 0) {
      final rows =
          ref.watch(sanitaryApplicationListByPropertyProvider).asData?.value ??
              const <SanitaryApplication>[];
      final reversedIds = reversedApplicationIds(rows);
      final filtered = _filteredApplications(rows)
          .where((a) => a.reversesApplicationId == null &&
              !reversedIds.contains(a.id))
          .toList();
      return ExportButton(
        schema: sanitarioSchema,
        fileName: exportFileName('sanitario', propertyName),
        rows: [
          for (final app in filtered)
            for (final e in app.compositionSnapshot)
              {
                'animal_number': e.number,
                'dose_name': app.doseName,
                'applied_at': app.appliedAt,
                'notes': app.notes,
                'lot_name': app.lotName,
                'category':
                    kCategoryLabels[e.category] ?? e.category,
              },
        ],
      );
    }
    final doses = (_showArchived
                ? ref.watch(archivedDoseListByPropertyProvider)
                : ref.watch(doseListByPropertyProvider))
            .asData
            ?.value ??
        const <Dose>[];
    return ExportButton(
      schema: dosesSchema,
      fileName: exportFileName('doses', propertyName),
      rows: [
        for (final d in doses)
          {
            'name': d.name,
            'active_ingredient': d.activeIngredient,
            'dosage_per_kg': d.dosagePerKg,
            'cost_per_kg': d.costPerKg,
          },
      ],
    );
  }

  String _desktopSubtitle() {
    if (_tab == 0) {
      final rows =
          ref.watch(sanitaryApplicationListByPropertyProvider).asData?.value ??
              const <SanitaryApplication>[];
      final filtered = _filteredApplications(rows);
      final totalUa = filtered.fold<double>(0, (sum, a) => sum + a.totalUa);
      final costs = [
        for (final a in filtered)
          if (a.totalCost != null) a.totalCost!,
      ];
      var subtitle = '${filtered.length} aplicações · ${formatUa(totalUa)} UA';
      if (costs.isNotEmpty) {
        final totalCost = costs.fold<double>(0, (sum, c) => sum + c);
        subtitle += ' · ${formatCurrencyBrl(totalCost)}';
      }
      return subtitle;
    }
    final dosesAsync = _showArchived
        ? ref.watch(archivedDoseListByPropertyProvider)
        : ref.watch(doseListByPropertyProvider);
    final n = dosesAsync.asData?.value.length ?? 0;
    return _showArchived ? '$n doses arquivadas' : '$n doses';
  }

  // ---------------------------------------------------------------------
  // Applications tab (SANI-04)
  // ---------------------------------------------------------------------

  bool _matchesApplicationFilters(SanitaryApplication app) {
    if (_lotFilterId != null && app.lotId != _lotFilterId) return false;
    if (_doseFilterId != null && app.doseId != _doseFilterId) return false;
    final range = _dateRangeFilter;
    if (range != null) {
      final applied = DateUtils.dateOnly(app.appliedAt);
      final start = DateUtils.dateOnly(range.start);
      final end = DateUtils.dateOnly(range.end);
      if (applied.isBefore(start) || applied.isAfter(end)) return false;
    }
    final animalId = _animalFilterId;
    if (animalId != null &&
        !app.compositionSnapshot.any((e) => e.animalId == animalId)) {
      return false;
    }
    return true;
  }

  /// Aplica o toggle "Mostrar estornadas", os filtros da faixa e a ordenação
  /// padrão — única definição do que está na tela, reusada pela aba e pelo
  /// subtítulo do header desktop.
  List<SanitaryApplication> _filteredApplications(
    List<SanitaryApplication> rows,
  ) {
    final visible = visibleApplications(rows, showReversed: _showReversed);
    final filtered = visible.where(_matchesApplicationFilters).toList();
    return sortByAppliedAtDesc(filtered);
  }

  Widget _buildApplicationsTab(bool canEdit, bool isDesktop) {
    final appsAsync = ref.watch(sanitaryApplicationListByPropertyProvider);
    return Column(
      children: [
        _buildFilterRow(),
        _buildToggleRow(
          label: 'Mostrar estornadas',
          value: _showReversed,
          onChanged: (v) => setState(() => _showReversed = v),
        ),
        Expanded(
          child: appsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(
              child: ErrorRetry(
                message:
                    'Erro ao carregar. Verifique sua conexão e tente novamente.',
                onRetry: () =>
                    ref.invalidate(sanitaryApplicationListByPropertyProvider),
              ),
            ),
            data: (rows) {
              final sorted = _filteredApplications(rows);

              if (sorted.isEmpty) {
                return rows.isEmpty
                    ? const EmptyState(
                        icon: Icons.medical_services_outlined,
                        title: 'Nenhuma aplicação registrada',
                        message:
                            'Registre uma aplicação sanitária em um lote.',
                      )
                    : const EmptyState(
                        icon: Icons.medical_services_outlined,
                        title: 'Nenhuma aplicação encontrada',
                        message: 'Tente ajustar os filtros.',
                      );
              }

              final reversedIds = reversedApplicationIds(rows);

              if (isDesktop) {
                return AplicacoesTableView(
                  rows: sorted,
                  reversedIds: reversedIds,
                  canEdit: canEdit,
                  onOpen: (app) =>
                      context.go(AppRoutes.aplicacaoDetail(app.id)),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 88),
                itemCount: sorted.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _AplicacaoCard(
                    app: sorted[i],
                    isReversed: reversedIds.contains(sorted[i].id),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterRow() {
    final lotsAsync = ref.watch(loteListByPropertyProvider);
    final dosesAsync = ref.watch(doseListByPropertyProvider);
    final lots = lotsAsync.asData?.value ?? const <Lot>[];
    final doses = dosesAsync.asData?.value ?? const <Dose>[];

    final selectedLot =
        lots.where((l) => l.id == _lotFilterId).firstOrNull;
    final selectedDose =
        doses.where((d) => d.id == _doseFilterId).firstOrNull;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Row(
        children: [
          _FilterChipButton(
            label: selectedLot?.name ?? 'Todos os lotes',
            active: selectedLot != null,
            onTap: () => _pickFilterOption<Lot>(
              title: 'Lote',
              allLabel: 'Todos os lotes',
              options: lots,
              labelOf: (l) => l.name,
              onSelected: (l) => setState(() => _lotFilterId = l?.id),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: selectedDose?.name ?? 'Todas as doses',
            active: selectedDose != null,
            onTap: () => _pickFilterOption<Dose>(
              title: 'Dose',
              allLabel: 'Todas as doses',
              options: doses,
              labelOf: (d) => d.name,
              onSelected: (d) => setState(() => _doseFilterId = d?.id),
            ),
          ),
          const SizedBox(width: 8),
          _FilterChipButton(
            label: _dateRangeFilter == null
                ? 'Período'
                : '${_dateFmt.format(_dateRangeFilter!.start)} - '
                    '${_dateFmt.format(_dateRangeFilter!.end)}',
            active: _dateRangeFilter != null,
            mono: _dateRangeFilter != null,
            onTap: _pickDateRange,
            onClear: _dateRangeFilter == null
                ? null
                : () => setState(() => _dateRangeFilter = null),
          ),
          if (_animalFilterId != null) ...[
            const SizedBox(width: 8),
            _buildAnimalFilterChip(),
          ],
        ],
      ),
    );
  }

  /// Bottom-sheet option picker shared by the lote/dose filter chips —
  /// the "all" row clears the filter (null).
  Future<void> _pickFilterOption<T>({
    required String title,
    required String allLabel,
    required List<T> options,
    required String Function(T) labelOf,
    required void Function(T?) onSelected,
  }) async {
    final picked = await showModalBottomSheet<_FilterChoice<T>>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: Text(
                title,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
            ListTile(
              title: Text(allLabel),
              onTap: () =>
                  Navigator.pop(ctx, const _FilterChoice(null)),
            ),
            for (final option in options)
              ListTile(
                title: Text(labelOf(option)),
                onTap: () => Navigator.pop(ctx, _FilterChoice(option)),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) onSelected(picked.value);
  }

  Widget _buildAnimalFilterChip() {
    final animal = ref
        .watch(animalByIdProvider(_animalFilterId!))
        .asData
        ?.value;
    return _FilterChipButton(
      label: animal != null ? '#${animal.number}' : 'Animal',
      active: true,
      mono: animal != null,
      onTap: () {},
      onClear: () => setState(() => _animalFilterId = null),
    );
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      initialDateRange: _dateRangeFilter,
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _dateRangeFilter = picked);
    }
  }

  // ---------------------------------------------------------------------
  // Doses tab (SANI-01, spec 4.11)
  // ---------------------------------------------------------------------

  Widget _buildDosesTab(bool canEdit, bool isDesktop) {
    final dosesAsync = _showArchived
        ? ref.watch(archivedDoseListByPropertyProvider)
        : ref.watch(doseListByPropertyProvider);
    final kgPerUa = resolveActiveKgPerUa(ref);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildToggleRow(
                label: 'Mostrar arquivadas',
                value: _showArchived,
                onChanged: (v) => setState(() => _showArchived = v),
              ),
            ),
            if (isDesktop && canEdit)
              Padding(
                padding: const EdgeInsets.only(right: 14),
                child: SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(
                      value: false,
                      icon: Icon(Icons.view_list_outlined, size: 18),
                      tooltip: 'Lista',
                    ),
                    ButtonSegment(
                      value: true,
                      icon: Icon(Icons.grid_on, size: 18),
                      tooltip: 'Editar em grade',
                    ),
                  ],
                  selected: {_dosesGridMode},
                  showSelectedIcon: false,
                  onSelectionChanged: (sel) =>
                      setState(() => _dosesGridMode = sel.first),
                ),
              ),
          ],
        ),
        Expanded(
          child: dosesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => Center(
              child: ErrorRetry(
                message:
                    'Erro ao carregar. Verifique sua conexão e tente novamente.',
                onRetry: () => ref.invalidate(
                  _showArchived
                      ? archivedDoseListByPropertyProvider
                      : doseListByPropertyProvider,
                ),
              ),
            ),
            data: (doses) {
              if (doses.isEmpty) {
                return const EmptyState(
                  icon: Icons.science_outlined,
                  title: 'Nenhuma dose cadastrada',
                  message:
                      'Cadastre uma dose para registrar aplicações sanitárias.',
                );
              }

              if (isDesktop) {
                final property =
                    ref.read(currentPropertyProvider).asData?.value;
                if (_dosesGridMode && canEdit && property != null) {
                  return DosesGridView(
                    doses: doses,
                    propertyId: property.id,
                  );
                }
                return DosesTableView(
                  doses: doses,
                  kgPerUa: kgPerUa,
                  canEdit: canEdit,
                  onEdit: (d) => _openDoseForm(existing: d),
                  onArchiveToggle: _toggleArchive,
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(14, 4, 14, 88),
                itemCount: doses.length,
                itemBuilder: (context, i) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _DoseCard(
                    dose: doses[i],
                    canEdit: canEdit,
                    kgPerUa: kgPerUa,
                    onEdit: () => _openDoseForm(existing: doses[i]),
                    onArchiveToggle: () => _toggleArchive(doses[i]),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildToggleRow({
    required String label,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Wrapper so the sheet can distinguish "picked the all/clear row" (value
/// null) from "dismissed the sheet" (result null).
class _FilterChoice<T> {
  const _FilterChoice(this.value);
  final T? value;
}

/// Stadium dropdown-chip used by the applications filter row: label +
/// expand_more (or close when clearable), green-tinted when active.
class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.active,
    required this.onTap,
    this.onClear,
    this.mono = false,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback? onClear;
  final bool mono;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: active ? AppColors.positiveChipBg : AppColors.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppColors.chipBorder),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: mono
                  ? monoStyle(
                      size: 13,
                      weight: FontWeight.w600,
                      color: active
                          ? AppColors.primaryDarkText
                          : AppColors.ink,
                    )
                  : TextStyle(
                      fontSize: 13,
                      fontWeight:
                          active ? FontWeight.w600 : FontWeight.w400,
                      color: active
                          ? AppColors.primaryDarkText
                          : AppColors.ink,
                    ),
            ),
            const SizedBox(width: 4),
            if (onClear != null)
              InkWell(
                onTap: onClear,
                child: const Icon(
                  Icons.close,
                  size: 18,
                  color: AppColors.textSecondary,
                ),
              )
            else
              const Icon(
                Icons.expand_more,
                size: 18,
                color: AppColors.textSecondary,
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Applications tab widgets
// ---------------------------------------------------------------------------

/// One application card: dose name (riscado quando estornada — nunca
/// removida da lista, regra transversal 4) + "dd/MM/yyyy · lote · N animais
/// · X UA · R$ Y" com números em mono. Trailing chip is mutually exclusive:
/// "Estornada" when [isReversed] (this row has itself been reversed),
/// "Estorno" when the row is a reversal of another, or neither.
class _AplicacaoCard extends StatelessWidget {
  const _AplicacaoCard({required this.app, required this.isReversed});

  final SanitaryApplication app;
  final bool isReversed;

  @override
  Widget build(BuildContext context) {
    final titleColor = isReversed ? AppColors.textTertiary : AppColors.ink;
    final subColor =
        isReversed ? AppColors.textTertiary : AppColors.textSecondary;

    TextSpan monoSpan(String text) => TextSpan(
          text: text,
          style: monoStyle(size: 13, weight: FontWeight.w600, color: subColor),
        );

    final subtitle = TextSpan(
      style: TextStyle(fontSize: 13, color: subColor),
      children: [
        monoSpan(_dateFmt.format(app.appliedAt)),
        TextSpan(text: ' · ${app.lotName} · '),
        monoSpan('${app.animalCount.abs()}'),
        TextSpan(
          text:
              ' ${Intl.plural(app.animalCount.abs(), one: 'animal', other: 'animais', locale: 'pt_BR')} · ',
        ),
        monoSpan(formatUa(app.totalUa.abs())),
        const TextSpan(text: ' UA'),
        if (app.totalCost != null) ...[
          const TextSpan(text: ' · '),
          monoSpan(formatCurrencyBrl(app.totalCost!.abs())),
        ],
      ],
    );

    Widget? chip;
    if (isReversed) {
      chip = const StatusChip('Estornada', kind: StatusKind.danger);
    } else if (app.isReversal) {
      chip = const StatusChip('Estorno', kind: StatusKind.neutral);
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => context.go(AppRoutes.aplicacaoDetail(app.id)),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.doseName,
                      style: TextStyle(
                        fontSize: 15.5,
                        fontWeight: FontWeight.w700,
                        color: titleColor,
                        decoration:
                            isReversed ? TextDecoration.lineThrough : null,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (chip != null) ...[const SizedBox(width: 8), chip],
                ],
              ),
              const SizedBox(height: 5),
              Text.rich(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doses tab widgets (spec 4.11)
// ---------------------------------------------------------------------------

/// One dose card: nome 16.5/700 + ícones edit/archive; princípio ativo 13
/// secundário; tiles DOSAGEM e CUSTO (bg bone r10) com o valor por UA
/// computado via `dosagePerUa`/`costPerUa` (`sanitary_calculations.dart`) —
/// never restated inline (D-13). The CUSTO tile is entirely absent when the
/// dose has no known cost (D-11). Archived: opacity 0.5 + chip "Arquivada"
/// + unarchive icon.
class _DoseCard extends StatelessWidget {
  const _DoseCard({
    required this.dose,
    required this.canEdit,
    required this.kgPerUa,
    required this.onEdit,
    required this.onArchiveToggle,
  });

  final Dose dose;
  final bool canEdit;
  final double kgPerUa;
  final VoidCallback onEdit;
  final VoidCallback onArchiveToggle;

  @override
  Widget build(BuildContext context) {
    final isArchived = dose.isArchived;
    final dosageUa = dosagePerUa(dose.dosagePerKg, kgPerUa);
    final costUa = costPerUa(dose.costPerKg, kgPerUa);

    return Card(
      child: Opacity(
        opacity: isArchived ? 0.5 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(14),
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
                          dose.name,
                          style: const TextStyle(
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (dose.activeIngredient != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            dose.activeIngredient!,
                            style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (isArchived) ...[
                    const SizedBox(width: 8),
                    const StatusChip('Arquivada', kind: StatusKind.neutral),
                  ],
                  if (canEdit) ...[
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, size: 20),
                      tooltip: 'Editar dose',
                      onPressed: onEdit,
                    ),
                    IconButton(
                      icon: Icon(
                        isArchived
                            ? Icons.unarchive_outlined
                            : Icons.archive_outlined,
                        size: 20,
                      ),
                      tooltip: isArchived ? 'Reativar dose' : 'Arquivar dose',
                      onPressed: onArchiveToggle,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: _DoseInfoTile(
                      label: 'Dosagem',
                      base: '${_dosageFmt.format(dose.dosagePerKg)} mL/kg',
                      computed: '${_dosageFmt.format(dosageUa)} mL/UA',
                    ),
                  ),
                  if (dose.costPerKg != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: _DoseInfoTile(
                        label: 'Custo',
                        base: '${formatCurrencyBrl(dose.costPerKg!)}/kg',
                        computed: '${formatCurrencyBrl(costUa!)}/UA',
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tile bone r10 do card de dose: overline + valor base mono + valor por UA
/// mono 700 verde.
class _DoseInfoTile extends StatelessWidget {
  const _DoseInfoTile({
    required this.label,
    required this.base,
    required this.computed,
  });

  final String label;
  final String base;
  final String computed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          OverlineLabel(label),
          const SizedBox(height: 4),
          Text(base, style: monoStyle(size: 14, weight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(
            computed,
            style: monoStyle(
              size: 14,
              weight: FontWeight.w700,
              color: AppColors.primaryDarkText,
            ),
          ),
        ],
      ),
    );
  }
}
