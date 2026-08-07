import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/router/routes.dart';
import '../../animais/data/animal_repository.dart';
import '../../auth/data/property_repository.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../../propriedades/data/propriedade_repository.dart';
import '../data/dose_model.dart';
import '../data/dose_repository.dart';
import '../data/sanitary_application_model.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';
import 'aplicacao_form_dialog.dart';
import 'dose_form_dialog.dart';

final _dateFmt = DateFormat('dd/MM/yyyy');

/// `#,##0.##` mL figures — mirrors `aplicacao_detail_screen.dart`'s
/// file-local dosage formatter (06-05 decision): none of the three shared
/// `sanitary_calculations.dart` helpers (UA/volume/currency) fit a plain
/// mL/kg or mL/UA number.
final NumberFormat _dosageFmt = NumberFormat('#,##0.##', 'pt_BR');

/// The sanitary module's whole two-tab shell (`/sanitario` shell branch,
/// D-16) — replaces the Phase 0 placeholder. Tab 1 is the global
/// applications list (SANI-04); Tab 2 is the dose cadastro (SANI-01). Both
/// FAB actions and the filter/toggle state below live on this single widget
/// so every child reads one source (D-26, D-29).
class SanitarioScreen extends ConsumerStatefulWidget {
  const SanitarioScreen({super.key});

  @override
  ConsumerState<SanitarioScreen> createState() => _SanitarioScreenState();
}

class _SanitarioScreenState extends ConsumerState<SanitarioScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  /// Guards the query-parameter seeding so it fires exactly once — mirrors
  /// `SanitaryAnimalSelectionScreen`'s `_seeded` one-shot guard (06-08).
  /// `GoRouterState.of(context)` cannot be read in `initState` (Flutter's
  /// `State.initState` docs explicitly forbid
  /// `dependOnInheritedWidgetOfExactType` there — `didChangeDependencies`/
  /// `build` is the earliest safe point), so seeding happens in `build`
  /// instead, synchronously before the tree is returned.
  bool _filtersSeeded = false;

  // Applications tab filters (D-26) — held here so both the filter row and
  // the list below read the same source.
  bool _showReversed = false;
  String? _lotFilterId;
  String? _doseFilterId;
  DateTimeRange? _dateRangeFilter;
  String? _animalFilterId;

  // Doses tab.
  bool _showArchived = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this)
      ..addListener(() {
        if (mounted) setState(() {});
      });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
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

  /// Reads `lote`/`animal` query parameters and seeds the matching filter
  /// (this is what makes the "Ver todas" action on the embedded history
  /// sections, `sanitary_history_section.dart`, land here pre-filtered),
  /// switching to the applications tab when either is present.
  void _seedFiltersFromQuery(BuildContext context) {
    if (_filtersSeeded) return;
    _filtersSeeded = true;
    final queryParameters = GoRouterState.of(context).uri.queryParameters;
    final lote = queryParameters['lote'];
    final animal = queryParameters['animal'];
    if (lote != null) _lotFilterId = lote;
    if (animal != null) _animalFilterId = animal;
    if (lote != null || animal != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _tabController.animateTo(0);
      });
    }
  }

  /// The active property's kg/UA factor (D-12) for the doses tab's computed
  /// per-UA figures — same join `DoseFormDialog`/`ResumoAplicacaoDialog` use
  /// (`currentPropertyProvider` only carries id+name).
  double _kgPerUa() {
    final selected = ref.watch(currentPropertyProvider).asData?.value;
    if (selected == null) return 400;
    final properties =
        ref.watch(propertyListProvider).asData?.value ?? const [];
    final match = properties.where((p) => p.id == selected.id);
    return match.isNotEmpty ? match.first.kgPerUa : 400;
  }

  Future<void> _openApplicationDialog() async {
    // The dialog pops itself before pushing the selection screen, so its own
    // future always completes with null — the count arrives through
    // onRegistered instead (06-11). Awaiting showDialog here would silently
    // drop the D-24 SnackBar.
    await showDialog<void>(
      context: context,
      builder: (_) => AplicacaoFormDialog(
        onRegistered: (count) {
          if (!mounted) return;
          ref.invalidate(sanitaryApplicationListByPropertyProvider);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(sanitaryRegisteredMessage(count))),
          );
        },
      ),
    );
  }

  Future<void> _openDoseDialog({Dose? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => DoseFormDialog(existing: existing),
    );
    if (saved != true || !mounted) return;
    ref.invalidate(doseListByPropertyProvider);
    ref.invalidate(archivedDoseListByPropertyProvider);
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
      ref.invalidate(doseListByPropertyProvider);
      ref.invalidate(archivedDoseListByPropertyProvider);
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
    if (_tabController.index == 0) {
      return FloatingActionButton(
        tooltip: 'Registrar aplicação',
        onPressed: _openApplicationDialog,
        child: const Icon(Icons.medical_services),
      );
    }
    return FloatingActionButton(
      tooltip: 'Nova dose',
      onPressed: () => _openDoseDialog(),
      child: const Icon(Icons.add),
    );
  }

  @override
  Widget build(BuildContext context) {
    _seedFiltersFromQuery(context);

    final currentPropAsync = ref.watch(currentPropertyProvider);
    final membersAsync = ref.watch(memberPropertiesProvider);
    final currentProperty = currentPropAsync.asData?.value;
    final canEdit = _canEdit(currentProperty, membersAsync.asData?.value);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Sanitário'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [Tab(text: 'Aplicações'), Tab(text: 'Doses')],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [_buildApplicationsTab(), _buildDosesTab(canEdit)],
      ),
      floatingActionButton: _buildFab(canEdit, currentProperty),
    );
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

  Widget _buildApplicationsTab() {
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
            error: (err, st) => const Center(
              child: Text(
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
              ),
            ),
            data: (rows) {
              final visible = visibleApplications(
                rows,
                showReversed: _showReversed,
              );
              final filtered = visible
                  .where(_matchesApplicationFilters)
                  .toList();
              final sorted = sortByAppliedAtDesc(filtered);

              if (sorted.isEmpty) {
                return rows.isEmpty
                    ? const _EmptyNoApplicationsState()
                    : const _EmptyFilteredApplicationsState();
              }

              final reversedIds = reversedApplicationIds(rows);
              return ListView.builder(
                itemCount: sorted.length,
                itemBuilder: (context, i) => _AplicacaoCard(
                  app: sorted[i],
                  isReversed: reversedIds.contains(sorted[i].id),
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

    final lotValue = lots.any((l) => l.id == _lotFilterId)
        ? _lotFilterId
        : null;
    final doseValue = doses.any((d) => d.id == _doseFilterId)
        ? _doseFilterId
        : null;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          DropdownButton<String?>(
            value: lotValue,
            hint: const Text('Todos os lotes'),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todos os lotes'),
              ),
              for (final l in lots)
                DropdownMenuItem<String?>(value: l.id, child: Text(l.name)),
            ],
            onChanged: (v) => setState(() => _lotFilterId = v),
          ),
          const SizedBox(width: 8),
          DropdownButton<String?>(
            value: doseValue,
            hint: const Text('Todas as doses'),
            underline: const SizedBox(),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('Todas as doses'),
              ),
              for (final d in doses)
                DropdownMenuItem<String?>(value: d.id, child: Text(d.name)),
            ],
            onChanged: (v) => setState(() => _doseFilterId = v),
          ),
          const SizedBox(width: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.date_range),
            label: Text(
              _dateRangeFilter == null
                  ? 'Período'
                  : '${_dateFmt.format(_dateRangeFilter!.start)} - '
                        '${_dateFmt.format(_dateRangeFilter!.end)}',
            ),
            onPressed: _pickDateRange,
          ),
          if (_dateRangeFilter != null)
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => setState(() => _dateRangeFilter = null),
            ),
          if (_animalFilterId != null) ...[
            const SizedBox(width: 8),
            _buildAnimalFilterChip(),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimalFilterChip() {
    final animal = ref
        .watch(animalByIdProvider(_animalFilterId!))
        .asData
        ?.value;
    return Chip(
      label: Text(animal != null ? '#${animal.number}' : 'Animal'),
      onDeleted: () => setState(() => _animalFilterId = null),
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
  // Doses tab (SANI-01)
  // ---------------------------------------------------------------------

  Widget _buildDosesTab(bool canEdit) {
    final dosesAsync = _showArchived
        ? ref.watch(archivedDoseListByPropertyProvider)
        : ref.watch(doseListByPropertyProvider);
    final kgPerUa = _kgPerUa();

    return Column(
      children: [
        _buildToggleRow(
          label: 'Mostrar arquivadas',
          value: _showArchived,
          onChanged: (v) => setState(() => _showArchived = v),
        ),
        Expanded(
          child: dosesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, st) => const Center(
              child: Text(
                'Erro ao carregar. Verifique sua conexão e tente novamente.',
              ),
            ),
            data: (doses) {
              if (doses.isEmpty) return const _EmptyDosesState();
              return ListView.builder(
                itemCount: doses.length,
                itemBuilder: (context, i) => _DoseCard(
                  dose: doses[i],
                  canEdit: canEdit,
                  kgPerUa: kgPerUa,
                  onEdit: () => _openDoseDialog(existing: doses[i]),
                  onArchiveToggle: () => _toggleArchive(doses[i]),
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(label),
          Switch(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Applications tab widgets
// ---------------------------------------------------------------------------

/// One application row (mirrors `_AtfCard`'s structure). Trailing badge is
/// mutually exclusive: "Estornada" when [isReversed] (this row has itself
/// been reversed), "Estorno" when the row is a reversal of another, or
/// neither.
class _AplicacaoCard extends StatelessWidget {
  const _AplicacaoCard({required this.app, required this.isReversed});

  final SanitaryApplication app;
  final bool isReversed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final parts = <String>[
      _dateFmt.format(app.appliedAt),
      app.lotName,
      Intl.plural(
        app.animalCount,
        one: '1 animal',
        other: '${app.animalCount} animais',
        locale: 'pt_BR',
      ),
      '${formatUa(app.totalUa)} UA',
    ];
    var subtitle = parts.join(' · ');
    if (app.totalCost != null) {
      subtitle = '$subtitle · ${formatCurrencyBrl(app.totalCost!)}';
    }

    Widget? badge;
    if (isReversed) {
      badge = _Badge(
        label: 'Estornada',
        background: colorScheme.errorContainer,
        foreground: colorScheme.onErrorContainer,
      );
    } else if (app.isReversal) {
      badge = _Badge(
        label: 'Estorno',
        background: colorScheme.surfaceContainerHigh,
        foreground: colorScheme.onSurface,
      );
    }

    return Card(
      color: colorScheme.surfaceContainerHighest,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: InkWell(
        onTap: () => context.go(AppRoutes.aplicacaoDetail(app.id)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      app.doseName,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (badge != null) ...[const SizedBox(width: 8), badge],
                ],
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurface.withValues(alpha: 0.6),
                ),
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

class _EmptyNoApplicationsState extends StatelessWidget {
  const _EmptyNoApplicationsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aplicação registrada',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Registre uma aplicação sanitária em um lote.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyFilteredApplicationsState extends StatelessWidget {
  const _EmptyFilteredApplicationsState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.medical_services_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma aplicação encontrada',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Tente ajustar os filtros.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Doses tab widgets
// ---------------------------------------------------------------------------

/// One dose row. Computed per-UA figures (primary-tinted) always come from
/// `dosagePerUa`/`costPerUa` (`sanitary_calculations.dart`) — never restated
/// inline (D-13). Cost chips are entirely absent when the dose has no known
/// cost (D-11).
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isArchived = dose.isArchived;
    final dosageUa = dosagePerUa(dose.dosagePerKg, kgPerUa);
    final costUa = costPerUa(dose.costPerKg, kgPerUa);
    final computedStyle = theme.textTheme.bodyMedium?.copyWith(
      color: colorScheme.primary,
    );

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Opacity(
        opacity: isArchived ? 0.38 : 1.0,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dose.name,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (dose.activeIngredient != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        dose.activeIngredient!,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          '${_dosageFmt.format(dose.dosagePerKg)} mL/kg',
                          style: theme.textTheme.bodyMedium,
                        ),
                        Text(
                          '${_dosageFmt.format(dosageUa)} mL/UA',
                          style: computedStyle,
                        ),
                        if (dose.costPerKg != null) ...[
                          Text(
                            '${formatCurrencyBrl(dose.costPerKg!)}/kg',
                            style: theme.textTheme.bodyMedium,
                          ),
                          Text(
                            '${formatCurrencyBrl(costUa!)}/UA',
                            style: computedStyle,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
              if (isArchived) ...[
                const SizedBox(width: 8),
                _Badge(
                  label: 'Arquivada',
                  background: colorScheme.surfaceContainerHigh,
                  foreground: colorScheme.onSurface,
                ),
              ],
              if (canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Editar dose',
                  onPressed: onEdit,
                ),
                IconButton(
                  icon: Icon(
                    isArchived
                        ? Icons.unarchive_outlined
                        : Icons.archive_outlined,
                  ),
                  tooltip: isArchived ? 'Reativar dose' : 'Arquivar dose',
                  onPressed: onArchiveToggle,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyDosesState extends StatelessWidget {
  const _EmptyDosesState();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.science_outlined,
              size: 64,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 16),
            Text(
              'Nenhuma dose cadastrada',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Cadastre uma dose para registrar aplicações sanitárias.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared
// ---------------------------------------------------------------------------

/// Small rounded status badge — same shape as `_HistoryBadge` in
/// `sanitary_history_section.dart` (private-per-file duplication is this
/// codebase's established convention for this exact widget).
class _Badge extends StatelessWidget {
  const _Badge({
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
