import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animais/data/animal_constants.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/atf_repository.dart';

/// Animal selection screen for adding animals to an ATF (REPR-02, D-06..D-09).
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

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: _onClosePressed,
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Adicionar animais'),
            Text(widget.atfName, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: eligibleAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text(
            'Erro ao carregar. Verifique sua conexão e tente novamente.',
          ),
        ),
        data: (eligible) => _buildBody(theme, eligible, lotsAsync),
      ),
    );
  }

  Widget _buildBody(
    ThemeData theme,
    List<EligibleAnimal> eligible,
    AsyncValue<List<Lot>> lotsAsync,
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

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              lotsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const Text(
                  'Erro ao carregar. Verifique sua conexão e tente novamente.',
                ),
                data: (lots) => DropdownButtonFormField<String>(
                  initialValue: _selectedLotId,
                  decoration: const InputDecoration(
                    labelText: 'Lote base',
                    border: OutlineInputBorder(),
                  ),
                  items: [
                    for (final lot in lots)
                      DropdownMenuItem(value: lot.id, child: Text(lot.name)),
                  ],
                  onChanged: (id) => _onLotChanged(id, eligible),
                ),
              ),
              const SizedBox(height: 8),
              if (_selectedLotId != null && lotAnimals.isEmpty)
                Text(
                  'Nenhuma vaca ou novilha neste lote.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                )
              else
                ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: lotAnimals.length,
                  itemBuilder: (context, i) => _buildRow(theme, lotAnimals[i]),
                ),
              const Divider(height: 32),
              Text('Avulsos', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              SearchBar(
                controller: _searchCtrl,
                hintText: 'Buscar por número...',
                leading: const Icon(Icons.search),
                onChanged: _onSearchChanged,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilterChip(
                    label: const Text('Todas'),
                    selected: _categoryFilter == null,
                    onSelected: (_) => setState(() => _categoryFilter = null),
                    showCheckmark: false,
                  ),
                  for (final c in _eligibleCategories)
                    FilterChip(
                      label: Text(kCategoryLabels[c]!),
                      selected: _categoryFilter == c,
                      onSelected: (sel) =>
                          setState(() => _categoryFilter = sel ? c : null),
                      showCheckmark: false,
                    ),
                ],
              ),
              const SizedBox(height: 8),
              ListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: avulsos.length,
                itemBuilder: (context, i) => _buildRow(theme, avulsos[i]),
              ),
            ],
          ),
        ),
        _buildBottomBar(theme),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, EligibleAnimal e) {
    final catLabel = kCategoryLabels[e.animal.category] ?? e.animal.category;
    final title = e.blockedByAtfName != null
        ? '#${e.animal.number} · $catLabel — já em ${e.blockedByAtfName}'
        : '#${e.animal.number} · $catLabel';
    return CheckboxListTile(
      value: _selectedIds.contains(e.animal.id),
      enabled: e.blockedByAtfName == null,
      onChanged: e.blockedByAtfName == null
          ? (checked) => _toggle(e.animal.id, checked)
          : null,
      title: Text(title),
    );
  }

  Widget _buildBottomBar(ThemeData theme) {
    final count = _selectedIds.length;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Expanded(
              child: Text(
                count == 0
                    ? 'Selecione ao menos 1 animal'
                    : '$count selecionados',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            FilledButton(
              onPressed: (_saving || count == 0) ? null : _confirm,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Adicionar animais'),
            ),
          ],
        ),
      ),
    );
  }
}
