import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/atf_repository.dart';

/// Animal selection screen for adding animals to an ATF (REPR-02, D-06..D-09)
/// — redesign spec 4.17: green header with close + "LOTE BASE" glass tile,
/// info strip, pre-checked lot list, "Avulsos de outros lotes" search
/// section, fixed footer.
///
/// Pushed via `Navigator.push`, not a GoRoute — transient selection workflow
/// with no deep-link requirement (05-UI-SPEC section 4). Two data sources
/// feed the same [eligibleAnimalsForAtfProvider] list: a "Lote base" picker
/// that pre-checks every eligible animal of the chosen lot (D-06), and an
/// "Avulsos" search+filter row for animals from any other lot. An animal
/// already active in a DIFFERENT ATF renders disabled with its reason
/// (D-07) — it is never filtered out of either list.
class AtfAnimalSelectionScreen extends ConsumerStatefulWidget {
  const AtfAnimalSelectionScreen({
    super.key,
    required this.atfId,
    required this.atfName,
  });

  final String atfId;
  final String atfName;

  @override
  ConsumerState<AtfAnimalSelectionScreen> createState() =>
      _AtfAnimalSelectionScreenState();
}

class _AtfAnimalSelectionScreenState
    extends ConsumerState<AtfAnimalSelectionScreen> {
  // D-09: the picker only ever offers these two categories.
  static const _eligibleCategories = ['vaca', 'novilha'];

  final Set<String> _selectedIds = {};
  String? _selectedLotId;
  String _query = '';
  String? _categoryFilter; // null = both eligible categories
  Timer? _debounce;
  final _searchCtrl = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _debounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _onSearchChanged(String v) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () {
      if (mounted) setState(() => _query = v.trim());
    });
  }

  Future<void> _onClosePressed() async {
    if (_selectedIds.isEmpty) {
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

  void _onLotChanged(String? lotId, List<EligibleAnimal> eligible) {
    setState(() {
      _selectedLotId = lotId;
      if (lotId != null) {
        for (final e in eligible) {
          if (e.animal.lotId == lotId && e.blockedByAtfName == null) {
            _selectedIds.add(e.animal.id);
          }
        }
      }
    });
  }

  Future<void> _openLotPicker(
    List<Lot> lots,
    List<EligibleAnimal> eligible,
  ) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 8),
              child: OverlineLabel('Lote base'),
            ),
            for (final lot in lots)
              ListTile(
                title: Text(lot.name),
                selected: lot.id == _selectedLotId,
                trailing: lot.id == _selectedLotId
                    ? const Icon(Icons.check_circle,
                        size: 22, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(ctx, lot.id),
              ),
          ],
        ),
      ),
    );
    if (picked != null && mounted) {
      _onLotChanged(picked, eligible);
    }
  }

  void _toggle(String animalId, bool? checked) {
    setState(() {
      if (checked == true) {
        _selectedIds.add(animalId);
      } else {
        _selectedIds.remove(animalId);
      }
    });
  }

  Future<void> _confirm() async {
    if (_selectedIds.isEmpty) return;
    setState(() => _saving = true);
    try {
      await ref.read(atfRepositoryProvider).addAnimalsToAtf(
            atfBatchId: widget.atfId,
            animalIds: _selectedIds.toList(),
          );
      if (!mounted) return;
      ref.invalidate(atfActiveMembershipsProvider(widget.atfId));
      ref.invalidate(atfMembershipsProvider(widget.atfId));
      ref.invalidate(atfListByPropertyProvider);
      // The newly-added animals' fichas should now show this ATF (WR-01).
      for (final animalId in _selectedIds) {
        ref.invalidate(reproductiveHistoryByAnimalProvider(animalId));
      }
      final count = _selectedIds.length;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('$count animais adicionados ao ATF.')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro ao adicionar animais. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final eligibleAsync =
        ref.watch(eligibleAnimalsForAtfProvider(widget.atfId));
    final lotsAsync = ref.watch(loteListByPropertyProvider);
    final lots = lotsAsync.asData?.value ?? const <Lot>[];
    final lotNames = {for (final l in lots) l.id: l.name};
    final eligible = eligibleAsync.asData?.value ?? const <EligibleAnimal>[];

    return Scaffold(
      body: Column(
        children: [
          Container(
            width: double.infinity,
            color: AppColors.primary,
            child: SafeArea(
              bottom: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 2, 14, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.close,
                              color: AppColors.onGreen),
                          tooltip: 'Fechar',
                          onPressed: _onClosePressed,
                        ),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Adicionar animais',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.onGreen,
                                ),
                              ),
                              Text(
                                '${widget.atfName} · só vacas e novilhas',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.onGreenSecondary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.only(left: 10),
                      child: GlassTile(
                        label: 'Lote base',
                        value: lotNames[_selectedLotId] ?? 'Selecionar lote',
                        onTap: () => _openLotPicker(lots, eligible),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: eligibleAsync.when(
              loading: () =>
                  const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: ErrorRetry(
                  message:
                      'Erro ao carregar. Verifique sua conexão e tente novamente.',
                  onRetry: () => ref.invalidate(
                    eligibleAnimalsForAtfProvider(widget.atfId),
                  ),
                ),
              ),
              data: (eligible) => _buildBody(theme, eligible, lotNames),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    List<EligibleAnimal> eligible,
    Map<String, String> lotNames,
  ) {
    // D-09 defense-in-depth: the repository already restricts eligible
    // animals to vaca/novilha, but both picker sections re-check the
    // category here so a touro or terneiro is never listed regardless of
    // what the data source returns.
    final lotAnimals = eligible
        .where((e) =>
            e.animal.lotId == _selectedLotId &&
            _eligibleCategories.contains(e.animal.category))
        .toList();
    final avulsos = eligible.where((e) {
      if (!_eligibleCategories.contains(e.animal.category)) return false;
      if (_selectedLotId != null && e.animal.lotId == _selectedLotId) {
        return false;
      }
      if (_categoryFilter != null && e.animal.category != _categoryFilter) {
        return false;
      }
      if (_query.isNotEmpty && !e.animal.number.toString().contains(_query)) {
        return false;
      }
      return true;
    }).toList();

    final selectedLotName = lotNames[_selectedLotId];

    return Column(
      children: [
        if (selectedLotName != null)
          StatsStrip(
            child: Row(
              children: [
                const Icon(Icons.done_all,
                    size: 18, color: AppColors.primaryDarkText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Elegíveis do $selectedLotName já vêm marcados',
                    style: const TextStyle(
                      fontSize: 12.5,
                      color: AppColors.primaryDarkText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        Expanded(
          child: Container(
            color: AppColors.surface,
            child: ListView(
              padding: const EdgeInsets.only(bottom: 16),
              children: [
                if (_selectedLotId != null && lotAnimals.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Text(
                      'Nenhuma vaca ou novilha neste lote.',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  )
                else
                  for (final e in lotAnimals) _buildRow(e),
                const Padding(
                  padding: EdgeInsets.fromLTRB(14, 18, 14, 8),
                  child: OverlineLabel('Avulsos de outros lotes'),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: SearchBar(
                    controller: _searchCtrl,
                    hintText: 'Buscar por número',
                    leading: const Icon(Icons.search),
                    onChanged: _onSearchChanged,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      FilterChip(
                        label: const Text('Todas'),
                        selected: _categoryFilter == null,
                        onSelected: (_) =>
                            setState(() => _categoryFilter = null),
                        showCheckmark: false,
                      ),
                      for (final c in _eligibleCategories)
                        FilterChip(
                          label: Text(kCategoryLabels[c]!),
                          selected: _categoryFilter == c,
                          onSelected: (sel) => setState(
                              () => _categoryFilter = sel ? c : null),
                          showCheckmark: false,
                        ),
                    ],
                  ),
                ),
                for (final e in avulsos)
                  _buildRow(e, originLabel: lotNames[e.animal.lotId]),
              ],
            ),
          ),
        ),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildRow(EligibleAnimal e, {String? originLabel}) {
    final blocked = e.blockedByAtfName != null;
    final catLabel = kCategoryLabels[e.animal.category] ?? e.animal.category;
    return CheckboxListTile(
      value: _selectedIds.contains(e.animal.id),
      enabled: !blocked,
      onChanged: blocked ? null : (checked) => _toggle(e.animal.id, checked),
      controlAffinity: ListTileControlAffinity.leading,
      visualDensity: VisualDensity.compact,
      tileColor: blocked ? AppColors.surfaceSubtle : null,
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '#${e.animal.number}',
              style: monoStyle(
                size: 15.5,
                weight: FontWeight.w700,
                color: blocked ? AppColors.textTertiary : AppColors.ink,
              ),
            ),
            TextSpan(
              text: '  $catLabel',
              style: TextStyle(
                fontSize: 14,
                color: blocked
                    ? AppColors.textTertiary
                    : AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
      subtitle: blocked
          ? Text(
              'já está no ${e.blockedByAtfName}',
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.accentTextDark,
              ),
            )
          : null,
      secondary: blocked
          ? const Icon(Icons.lock_outline,
              size: 18, color: AppColors.textTertiary)
          : (originLabel != null
              ? Text(
                  originLabel,
                  style: const TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary,
                  ),
                )
              : null),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final count = _selectedIds.length;
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
              child: count == 0
                  ? const Text(
                      'Selecione ao menos 1 animal',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    )
                  : Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '$count',
                            style: monoStyle(
                                size: 17, weight: FontWeight.w700),
                          ),
                          const TextSpan(
                            text: ' selecionados',
                            style: TextStyle(
                              fontSize: 12.5,
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
                  onPressed: (_saving || count == 0) ? null : _confirm,
                  child: _saving
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Adicionar ao ATF'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
