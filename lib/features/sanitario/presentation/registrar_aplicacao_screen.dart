import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/dose_model.dart';
import '../data/dose_repository.dart';
import '../data/kg_per_ua_resolver.dart';
import '../data/sanitary_application_exception.dart';
import '../data/sanitary_application_repository.dart';
import '../data/sanitary_calculations.dart';

/// Resolves the active property's lots with each one's active-animal count
/// (D-18's gate mirrored here: a lot with zero active animals cannot be an
/// application target).
final _lotsWithActiveAnimalsProvider =
    FutureProvider<List<LotWithPaddockCount>>((ref) async {
      final property = await ref.watch(currentPropertyProvider.future);
      if (property == null) return const [];
      final repo = ref.watch(loteRepositoryProvider);
      return repo.fetchLotsWithCountByProperty(property.id);
    });

/// Registro sanitário em UMA tela (spec 4.10) — substitui o antigo fluxo em
/// 3 passos (AplicacaoFormDialog → SanitaryAnimalSelectionScreen →
/// ResumoAplicacaoDialog). Header verde com tiles glass Lote/Dose/Data,
/// faixa de totais ao vivo, checklist com todos os animais ativos do lote
/// pré-marcados (SANI-03, D-22) e rodapé com aviso de imutabilidade + CTA.
///
/// Pops with the registered animal count on success (same contract the old
/// selection screen honored) — callers show the D-24 success snackbar.
///
/// Preserved semantics from the old flow:
/// - duplicate detection (same dose + lote + data, D-34) surfaces as a
///   confirm dialog with a forced checkbox before the RPC fires;
/// - D-32/D-33 recovery: a stale-composition rejection offers "Recarregar",
///   which re-fetches the lot preserving still-valid deselections;
/// - discard confirm only after a real deselection.
class RegistrarAplicacaoScreen extends ConsumerStatefulWidget {
  const RegistrarAplicacaoScreen({super.key, this.initialLotId});

  /// Pre-selects the lot (entry point from LoteDetailScreen). The lot stays
  /// changeable — the tile is a picker either way.
  final String? initialLotId;

  @override
  ConsumerState<RegistrarAplicacaoScreen> createState() =>
      _RegistrarAplicacaoScreenState();
}

class _RegistrarAplicacaoScreenState
    extends ConsumerState<RegistrarAplicacaoScreen> {
  static final _tileDateFmt = DateFormat('dd/MM');

  String? _lotId;
  String? _lotName;
  Dose? _dose;
  DateTime _appliedAt = DateTime.now();

  final Set<String> _selectedIds = {};

  /// Which lot the default-all seeding last ran for — a lot change reseeds
  /// (everyone checked again); an unrelated rebuild never undoes the user's
  /// deselections.
  String? _seededLotId;

  /// Set the moment the user unchecks a row — the discard-confirm dialog
  /// only appears when there is real work to lose.
  bool _hasDeselected = false;

  bool _saving = false;
  bool _reloading = false;
  SanitaryApplicationException? _error;

  @override
  void initState() {
    super.initState();
    _lotId = widget.initialLotId;
  }

  // ---------------------------------------------------------------------
  // Pickers (tiles glass)
  // ---------------------------------------------------------------------

  Future<void> _pickLot() async {
    final lots = await ref.read(_lotsWithActiveAnimalsProvider.future);
    if (!mounted) return;
    final eligible = lots.where((l) => l.activeAnimalCount > 0).toList();
    final picked = await showModalBottomSheet<LotWithPaddockCount>(
      context: context,
      builder: (ctx) => _PickerSheet<LotWithPaddockCount>(
        title: 'Lote',
        options: eligible,
        emptyMessage: 'Nenhum lote com animais ativos.',
        labelOf: (l) => l.lot.name,
        detailOf: (l) => Intl.plural(
          l.activeAnimalCount,
          one: '1 animal',
          other: '${l.activeAnimalCount} animais',
          locale: 'pt_BR',
        ),
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _lotId = picked.lot.id;
      _lotName = picked.lot.name;
    });
  }

  Future<void> _pickDose() async {
    final doses = await ref.read(doseListByPropertyProvider.future);
    if (!mounted) return;
    final picked = await showModalBottomSheet<Dose>(
      context: context,
      builder: (ctx) => _PickerSheet<Dose>(
        title: 'Dose',
        options: doses,
        emptyMessage: 'Nenhuma dose cadastrada — cadastre uma dose primeiro',
        labelOf: (d) => d.name,
        detailOf: (d) => d.activeIngredient ?? '',
      ),
    );
    if (picked == null || !mounted) return;
    setState(() => _dose = picked);
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _appliedAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() => _appliedAt = picked);
    }
  }

  // ---------------------------------------------------------------------
  // Selection
  // ---------------------------------------------------------------------

  void _toggle(String animalId, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(animalId);
      } else {
        _selectedIds.remove(animalId);
        _hasDeselected = true;
      }
    });
  }

  void _selectAll(List<Animal> animals) {
    setState(() => _selectedIds.addAll(animals.map((a) => a.id)));
  }

  void _clearAll() {
    setState(() {
      if (_selectedIds.isNotEmpty) _hasDeselected = true;
      _selectedIds.clear();
    });
  }

  Future<void> _onClosePressed() async {
    if (!_hasDeselected) {
      Navigator.pop(context);
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Descartar seleção?'),
        content: const Text('A seleção de animais será perdida.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.pop(context);
  }

  /// D-32/D-33 recovery: re-fetches the lot's active animals after the RPC
  /// rejected a stale composition. Animals that left the lot disappear (set
  /// intersection), animals still present keep their check-state, newly
  /// arrived animals come pre-checked (set union).
  Future<void> _reload() async {
    final lotId = _lotId;
    if (lotId == null) return;
    setState(() => _reloading = true);
    try {
      ref.invalidate(animalListByLotProvider(lotId));
      final fresh = await ref.read(animalListByLotProvider(lotId).future);
      final freshActiveIds = fresh
          .where((a) => a.deletedAt == null)
          .map((a) => a.id)
          .toSet();
      final preserved = _selectedIds.intersection(freshActiveIds);
      final newlyArrived = freshActiveIds.difference(_selectedIds);
      if (!mounted) return;
      setState(() {
        _error = null;
        _selectedIds
          ..clear()
          ..addAll(preserved)
          ..addAll(newlyArrived);
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Erro ao atualizar a lista de animais. Tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _reloading = false);
    }
  }

  // ---------------------------------------------------------------------
  // Save (duplicate gate + RPC)
  // ---------------------------------------------------------------------

  Future<void> _submit(List<Animal> selected) async {
    final lotId = _lotId;
    final dose = _dose;
    if (lotId == null || dose == null || selected.isEmpty) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    // D-34: a lookup failure is treated as "no duplicate found" — blocking a
    // legitimate write over a lookup hiccup is the worse outcome.
    String? duplicateId;
    try {
      duplicateId = await ref
          .read(sanitaryApplicationRepositoryProvider)
          .findRecentIdenticalApplication(
            lotId: lotId,
            doseId: dose.id,
            appliedAt: _appliedAt,
          );
    } catch (_) {
      duplicateId = null;
    }
    if (!mounted) return;

    if (duplicateId != null) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => const _DuplicateConfirmDialog(),
      );
      if (confirmed != true) {
        if (mounted) setState(() => _saving = false);
        return;
      }
    }

    try {
      await ref
          .read(sanitaryApplicationRepositoryProvider)
          .registerApplication(
            lotId: lotId,
            doseId: dose.id,
            appliedAt: _appliedAt,
            animalIds: [for (final a in selected) a.id],
          );
      if (!mounted) return;
      ref.invalidate(sanitaryApplicationListByPropertyProvider);
      ref.invalidate(sanitaryApplicationsByLotProvider(lotId));
      for (final animal in selected) {
        ref.invalidate(sanitaryHistoryByAnimalProvider(animal.id));
      }
      Navigator.pop(context, selected.length);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = asSanitaryException(
          e,
          fallbackMessage:
              'Não foi possível registrar a aplicação. Tente novamente.',
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ---------------------------------------------------------------------
  // Build
  // ---------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    var lotName = _lotName;
    if (_lotId != null && lotName == null) {
      lotName = ref.watch(loteByIdProvider(_lotId!)).asData?.value?.name;
    }

    return Scaffold(
      backgroundColor: AppColors.surface,
      body: Column(
        children: [
          _buildHeader(lotName),
          Expanded(child: _buildAnimalsArea()),
        ],
      ),
    );
  }

  Widget _buildHeader(String? lotName) {
    return Container(
      color: AppColors.primary,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 4, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.close,
                      size: 24,
                      color: AppColors.onGreen,
                    ),
                    tooltip: 'Fechar',
                    onPressed: _onClosePressed,
                  ),
                  const Text(
                    'Registrar aplicação',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.onGreen,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.only(left: 8),
                // IntrinsicHeight bounds the stretch so the three tiles share
                // the tallest tile's height (the Column gives the Row
                // unbounded height otherwise).
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 10,
                        child: GlassTile(
                          label: 'Lote',
                          value: lotName ?? 'Selecionar',
                          onTap: _pickLot,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        // Spec 4.10: dose tile flex 1.3 vs lote 1.
                        flex: 13,
                        child: GlassTile(
                          label: 'Dose',
                          value: _dose?.name ?? 'Selecionar',
                          onTap: _pickDose,
                        ),
                      ),
                      const SizedBox(width: 8),
                      GlassTile(
                        label: 'Data',
                        value: _tileDateFmt.format(_appliedAt),
                        mono: true,
                        onTap: _pickDate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAnimalsArea() {
    final lotId = _lotId;
    if (lotId == null) {
      return const EmptyState(
        icon: Icons.pets_outlined,
        title: 'Escolha o lote',
        message: 'Selecione o lote para carregar os animais.',
      );
    }
    final animalsAsync = ref.watch(animalListByLotProvider(lotId));
    return animalsAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => const Center(
        child: Text(
          'Erro ao carregar. Verifique sua conexão e tente novamente.',
        ),
      ),
      data: (allAnimals) {
        final animals = allAnimals.where((a) => a.deletedAt == null).toList()
          ..sort((a, b) => a.number.compareTo(b.number));
        if (_seededLotId != lotId) {
          _seededLotId = lotId;
          _hasDeselected = false;
          _selectedIds
            ..clear()
            ..addAll(animals.map((a) => a.id));
        }
        return _buildBody(animals);
      },
    );
  }

  Widget _buildBody(List<Animal> animals) {
    final kgPerUa = resolveActiveKgPerUa(ref);
    final selected = animals.where((a) => _selectedIds.contains(a.id)).toList();
    final totalUa = totalUaForCategories(selected.map((a) => a.category));
    final dose = _dose;
    final volumeMl = dose != null
        ? totalVolumeMl(totalUa, dose.dosagePerKg, kgPerUa)
        : null;
    final cost = dose != null
        ? totalCost(totalUa, dose.costPerKg, kgPerUa)
        : null;

    return Column(
      children: [
        _buildStatsStrip(
          count: selected.length,
          total: animals.length,
          totalUa: totalUa,
          volumeMl: volumeMl,
          cost: cost,
        ),
        Expanded(
          child: ListView.builder(
            itemCount: animals.length + 1,
            itemBuilder: (context, i) =>
                i == 0 ? _buildMasterRow(animals) : _buildRow(animals[i - 1]),
          ),
        ),
        _buildFooter(selected, cost),
      ],
    );
  }

  Widget _buildStatsStrip({
    required int count,
    required int total,
    required double totalUa,
    required double? volumeMl,
    required double? cost,
  }) {
    return StatsStrip(
      child: Row(
        children: [
          _StatCell(value: '$count de $total', label: 'selecionados'),
          const _StatDivider(),
          _StatCell(value: formatUa(totalUa), label: 'UA somadas'),
          if (volumeMl != null) ...[
            const _StatDivider(),
            _StatCell(value: formatVolumeMl(volumeMl), label: 'volume'),
          ],
          const Spacer(),
          if (cost != null)
            _StatCell(
              value: formatCurrencyBrl(cost),
              label: 'custo',
              valueColor: AppColors.accentDark,
              alignEnd: true,
            ),
        ],
      ),
    );
  }

  Widget _buildMasterRow(List<Animal> animals) {
    final allSelected =
        animals.isNotEmpty && _selectedIds.length == animals.length;
    return Container(
      height: 52,
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: AppColors.divider)),
      ),
      child: Row(
        children: [
          Checkbox(
            value: allSelected,
            onChanged: (checked) =>
                checked == true ? _selectAll(animals) : _clearAll(),
          ),
          const SizedBox(width: 4),
          const Expanded(
            child: Text(
              'Todos os animais do lote',
              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w600),
            ),
          ),
          TextButton(
            onPressed: _selectedIds.isEmpty ? null : _clearAll,
            child: const Text('Desmarcar'),
          ),
        ],
      ),
    );
  }

  Widget _buildRow(Animal animal) {
    final checked = _selectedIds.contains(animal.id);
    final catLabel = kCategoryLabels[animal.category] ?? animal.category;
    final subtitle = animal.breed == null
        ? catLabel
        : '$catLabel · ${animal.breed}';
    final ua = kUaWeights[animal.category] ?? 0.0;
    final inkColor = checked ? AppColors.ink : AppColors.textTertiary;
    final subColor = checked ? AppColors.textSecondary : AppColors.textTertiary;

    return InkWell(
      onTap: () => _toggle(animal.id, !checked),
      child: SizedBox(
        height: 52,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              Checkbox(value: checked, onChanged: (v) => _toggle(animal.id, v)),
              const SizedBox(width: 4),
              SizedBox(
                width: 42,
                child: Text(
                  '#${animal.number}',
                  style: monoStyle(
                    size: 16,
                    weight: FontWeight.w700,
                    color: inkColor,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  subtitle,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14.5, color: subColor),
                ),
              ),
              Text(
                '${formatUa(ua)} UA',
                style: monoStyle(size: 12.5, color: subColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter(List<Animal> selected, double? cost) {
    final count = selected.length;
    final canSubmit =
        count > 0 && _dose != null && _lotId != null && !_saving && !_reloading;
    var label = Intl.plural(
      count,
      zero: 'Registrar',
      one: 'Registrar 1 animal',
      other: 'Registrar $count animais',
      locale: 'pt_BR',
    );
    if (cost != null && count > 0) {
      label = '$label · ${formatCurrencyBrl(cost)}';
    }

    return Container(
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      padding: const EdgeInsets.all(14),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_error != null) ...[
              _buildErrorSlot(_error!),
              const SizedBox(height: 10),
            ],
            const ImmutabilityNotice(),
            const SizedBox(height: 12),
            SizedBox(
              height: 54,
              child: FilledButton(
                onPressed: canSubmit ? () => _submit(selected) : null,
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(label),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// D-35/D-36: the RPC's mapped message, plus the "Recarregar" recovery
  /// action only for the composition-changed reason (D-32). Never a snackbar.
  Widget _buildErrorSlot(SanitaryApplicationException error) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            error.message,
            style: const TextStyle(fontSize: 13, color: AppColors.danger),
          ),
        ),
        if (error.reason == SanitaryApplicationErrorReason.compositionChanged)
          TextButton(onPressed: _reload, child: const Text('Recarregar')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Live-totals cells
// ---------------------------------------------------------------------------

class _StatCell extends StatelessWidget {
  const _StatCell({
    required this.value,
    required this.label,
    this.valueColor = AppColors.ink,
    this.alignEnd = false,
  });

  final String value;
  final String label;
  final Color valueColor;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: monoStyle(
            size: 15,
            weight: FontWeight.w700,
            color: valueColor,
          ),
        ),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}

class _StatDivider extends StatelessWidget {
  const _StatDivider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 26,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      color: AppColors.chipBorder,
    );
  }
}

// ---------------------------------------------------------------------------
// Duplicate confirm (D-34 — forced checkbox before the write)
// ---------------------------------------------------------------------------

class _DuplicateConfirmDialog extends StatefulWidget {
  const _DuplicateConfirmDialog();

  @override
  State<_DuplicateConfirmDialog> createState() =>
      _DuplicateConfirmDialogState();
}

class _DuplicateConfirmDialogState extends State<_DuplicateConfirmDialog> {
  bool _acknowledged = false;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Aplicação duplicada?'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Uma aplicação idêntica (mesma dose, lote e data) já foi '
            'registrada recentemente. Confirmar mesmo assim?',
          ),
          const SizedBox(height: 8),
          CheckboxListTile(
            value: _acknowledged,
            onChanged: (v) => setState(() => _acknowledged = v ?? false),
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: EdgeInsets.zero,
            title: const Text(
              'Sim, registrar mesmo assim',
              style: TextStyle(fontSize: 14, color: AppColors.ink),
            ),
          ),
        ],
      ),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _acknowledged ? () => Navigator.pop(context, true) : null,
          child: const Text('Registrar mesmo assim'),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Bottom-sheet picker for the glass tiles
// ---------------------------------------------------------------------------

class _PickerSheet<T> extends StatelessWidget {
  const _PickerSheet({
    required this.title,
    required this.options,
    required this.emptyMessage,
    required this.labelOf,
    required this.detailOf,
  });

  final String title;
  final List<T> options;
  final String emptyMessage;
  final String Function(T) labelOf;
  final String Function(T) detailOf;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
            child: Text(
              title,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
          ),
          if (options.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
              child: Text(
                emptyMessage,
                style: const TextStyle(
                  fontSize: 13.5,
                  color: AppColors.textSecondary,
                ),
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final option in options)
                    ListTile(
                      title: Text(labelOf(option)),
                      subtitle: detailOf(option).isEmpty
                          ? null
                          : Text(detailOf(option)),
                      onTap: () => Navigator.pop(context, option),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
