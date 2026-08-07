import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/dose_model.dart';
import '../data/sanitary_calculations.dart';
import 'resumo_aplicacao_dialog.dart';

/// Full-screen checklist of a lot's active animals for a sanitary
/// application (SANI-02/03, D-21). Pushed via `Navigator.push` — no
/// deep-link requirement (mirrors `AtfAnimalSelectionScreen`). Unlike its
/// ATF analog, the lot is already resolved by `AplicacaoFormDialog` — there
/// is no base-lot picker and no avulsos search, only the checklist itself
/// (SC-2: the composition is always the chosen lot).
///
/// Every active animal (`deletedAt == null`, D-22) arrives pre-checked —
/// the SANI-03 default is all selected, and unchecking is the interaction,
/// not an edge case. On a D-32 server rejection (stale composition),
/// [ResumoAplicacaoDialog] pops with the reload outcome and this screen
/// re-fetches the lot, preserving the user's still-valid deselections
/// (D-33) rather than resetting to "everyone selected".
class SanitaryAnimalSelectionScreen extends ConsumerStatefulWidget {
  const SanitaryAnimalSelectionScreen({
    super.key,
    required this.lotId,
    required this.lotName,
    required this.dose,
    required this.appliedAt,
  });

  final String lotId;
  final String lotName;
  final Dose dose;
  final DateTime appliedAt;

  @override
  ConsumerState<SanitaryAnimalSelectionScreen> createState() =>
      _SanitaryAnimalSelectionScreenState();
}

class _SanitaryAnimalSelectionScreenState
    extends ConsumerState<SanitaryAnimalSelectionScreen> {
  final Set<String> _selectedIds = {};

  /// Guards the initial default-all seeding so it fires exactly once — a
  /// rebuild triggered by an unrelated provider change must never silently
  /// undo the user's deselections.
  bool _seeded = false;

  /// Set the moment the user unchecks a row — the discard-confirm dialog
  /// only appears when there is real work to lose (plan: "only when the
  /// user has actually deselected something").
  bool _hasDeselected = false;

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

  /// D-32/D-33 recovery: re-fetches the lot's active animals after the RPC
  /// rejected a stale composition. Animals that left the lot disappear
  /// (set intersection), animals still present keep whatever check-state
  /// the user left them in, and animals that newly appeared arrive
  /// pre-checked (set union) — this is never a full reselect-everything.
  Future<void> _reload() async {
    ref.invalidate(animalListByLotProvider(widget.lotId));
    final fresh =
        await ref.read(animalListByLotProvider(widget.lotId).future);
    final freshActiveIds =
        fresh.where((a) => a.deletedAt == null).map((a) => a.id).toSet();
    final preserved = _selectedIds.intersection(freshActiveIds);
    final newlyArrived = freshActiveIds.difference(_selectedIds);
    if (!mounted) return;
    setState(() {
      _selectedIds
        ..clear()
        ..addAll(preserved)
        ..addAll(newlyArrived);
    });
  }

  Future<void> _continue(List<Animal> animals) async {
    final selected = animals.where((a) => _selectedIds.contains(a.id)).toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final deselectedCount = animals.length - selected.length;
    final result = await showDialog<ResumoAplicacaoResult>(
      context: context,
      builder: (_) => ResumoAplicacaoDialog(
        lotId: widget.lotId,
        lotName: widget.lotName,
        dose: widget.dose,
        appliedAt: widget.appliedAt,
        selectedAnimals: selected,
        deselectedCount: deselectedCount,
      ),
    );
    if (result == null) return;
    if (result.outcome == ResumoAplicacaoOutcome.registered) {
      if (mounted) Navigator.pop(context, result.animalCount);
      return;
    }
    await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final animalsAsync = ref.watch(animalListByLotProvider(widget.lotId));

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
            const Text('Selecionar animais'),
            Text(widget.lotName, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
      body: animalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => const Center(
          child: Text(
            'Erro ao carregar. Verifique sua conexão e tente novamente.',
          ),
        ),
        data: (allAnimals) {
          final animals =
              allAnimals.where((a) => a.deletedAt == null).toList()
                ..sort((a, b) => a.number.compareTo(b.number));
          if (!_seeded) {
            _seeded = true;
            _selectedIds.addAll(animals.map((a) => a.id));
          }
          return _buildBody(theme, animals);
        },
      ),
    );
  }

  Widget _buildBody(ThemeData theme, List<Animal> animals) {
    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, i) => _buildRow(theme, animals[i]),
          ),
        ),
        _buildBottomBar(theme, animals),
      ],
    );
  }

  Widget _buildRow(ThemeData theme, Animal animal) {
    final catLabel = kCategoryLabels[animal.category] ?? animal.category;
    return CheckboxListTile(
      value: _selectedIds.contains(animal.id),
      onChanged: (checked) => _toggle(animal.id, checked),
      title: Text.rich(
        TextSpan(
          children: [
            TextSpan(
              text: '#${animal.number}',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: ' · $catLabel'),
          ],
          style: theme.textTheme.bodyLarge,
        ),
      ),
    );
  }

  Widget _buildBottomBar(ThemeData theme, List<Animal> animals) {
    final count = _selectedIds.length;
    final total = animals.length;
    final selectedAnimals =
        animals.where((a) => _selectedIds.contains(a.id)).map((a) => a.category);
    final totalUa = totalUaForCategories(selectedAnimals);
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
                    : '$count de $total selecionados · ${formatUa(totalUa)} UA',
                style: theme.textTheme.bodyMedium,
              ),
            ),
            FilledButton(
              onPressed: count == 0 ? null : () => _continue(animals),
              child: const Text('Continuar'),
            ),
          ],
        ),
      ),
    );
  }
}
