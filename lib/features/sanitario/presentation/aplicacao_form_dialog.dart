import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../lotes/data/lote_repository.dart';
import '../data/dose_model.dart';
import '../data/dose_repository.dart';
import 'sanitary_animal_selection_screen.dart';

/// Resolves the active property's lots with each one's active-animal count
/// (D-18's gate mirrored here: a lot with zero active animals cannot be an
/// application target). Defined locally rather than in `lote_repository.dart`
/// because [LoteRepository.fetchLotsWithCountByProperty] already exists —
/// this file only needs a provider wrapping it (plan: "prefer an existing
/// lots-with-count repository method; only add one if none exists").
final _lotsWithActiveAnimalsProvider =
    FutureProvider<List<LotWithPaddockCount>>((ref) async {
  final property = await ref.watch(currentPropertyProvider.future);
  if (property == null) return const [];
  final repo = ref.watch(loteRepositoryProvider);
  return repo.fetchLotsWithCountByProperty(property.id);
});

/// Header dialog collecting lote, dose and date before the full-screen
/// animal checklist (SANI-02/03, D-17). Serves both entry points: opened
/// with [lotId] from `LoteDetailScreen`'s "Registrar aplicação" button
/// (the lote is already resolved and rendered read-only, D-17), or opened
/// with a null [lotId] from the `SanitarioScreen` FAB (the lote is picked
/// from a dropdown).
///
/// This dialog performs no write of any kind — its continue action is pure
/// client-side navigation to [SanitaryAnimalSelectionScreen], so there is no
/// saving flag and no spinner state.
class AplicacaoFormDialog extends ConsumerStatefulWidget {
  const AplicacaoFormDialog({super.key, this.lotId, this.onRegistered});

  final String? lotId;

  /// Fires with the registered animal count once the downstream flow
  /// (`SanitaryAnimalSelectionScreen` -> `ResumoAplicacaoDialog`) completes
  /// successfully. This dialog itself has already closed by the time it
  /// fires — `Continuar` pops the dialog immediately and pushes the
  /// selection screen on the same navigator (06-08), so the dialog's own
  /// `showDialog` future resolves to null before the flow even starts.
  /// Callers that need the eventual outcome (invalidate providers, show the
  /// D-24 success snackbar) hook this instead of awaiting `showDialog`.
  final ValueChanged<int>? onRegistered;

  @override
  ConsumerState<AplicacaoFormDialog> createState() =>
      _AplicacaoFormDialogState();
}

class _AplicacaoFormDialogState extends ConsumerState<AplicacaoFormDialog> {
  static final _dateFmt = DateFormat('dd/MM/yyyy');

  late final TextEditingController _dateCtrl;
  DateTime _appliedAt = DateTime.now();
  String? _selectedLotId;
  String? _selectedDoseId;

  @override
  void initState() {
    super.initState();
    _selectedLotId = widget.lotId;
    _dateCtrl = TextEditingController(text: _dateFmt.format(_appliedAt));
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
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
      setState(() {
        _appliedAt = picked;
        _dateCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  void _continue(String lotName, Dose dose) {
    final navigator = Navigator.of(context);
    final onRegistered = widget.onRegistered;
    navigator.pop();
    final pushed = navigator.push<int>(
      MaterialPageRoute(
        builder: (_) => SanitaryAnimalSelectionScreen(
          lotId: _selectedLotId!,
          lotName: lotName,
          dose: dose,
          appliedAt: _appliedAt,
        ),
      ),
    );
    pushed.then((count) {
      if (count != null) onRegistered?.call(count);
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dosesAsync = ref.watch(doseListByPropertyProvider);

    String? resolvedLotName;
    var lotResolved = false;
    Widget loteField;

    if (widget.lotId != null) {
      final lotAsync = ref.watch(loteByIdProvider(widget.lotId!));
      loteField = lotAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          'Erro ao carregar. Verifique sua conexão e tente novamente.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        data: (lot) {
          resolvedLotName = lot?.name;
          lotResolved = lot != null;
          return _KvRow(label: 'Lote *', value: Text(lot?.name ?? ''));
        },
      );
    } else {
      final lotsAsync = ref.watch(_lotsWithActiveAnimalsProvider);
      loteField = lotsAsync.when(
        loading: () => const LinearProgressIndicator(),
        error: (e, _) => Text(
          'Erro ao carregar. Verifique sua conexão e tente novamente.',
          style: TextStyle(color: theme.colorScheme.error),
        ),
        data: (lots) {
          final eligible = lots.where((l) => l.activeAnimalCount > 0).toList();
          if (_selectedLotId != null) {
            final match =
                eligible.where((l) => l.lot.id == _selectedLotId).firstOrNull;
            resolvedLotName = match?.lot.name;
            lotResolved = match != null;
          }
          return DropdownButtonFormField<String>(
            initialValue: _selectedLotId,
            decoration: const InputDecoration(
              labelText: 'Lote *',
              border: OutlineInputBorder(),
            ),
            items: [
              for (final l in eligible)
                DropdownMenuItem(value: l.lot.id, child: Text(l.lot.name)),
            ],
            onChanged: (v) => setState(() => _selectedLotId = v),
          );
        },
      );
    }

    Dose? selectedDose;
    final doseField = dosesAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (e, _) => Text(
        'Erro ao carregar. Verifique sua conexão e tente novamente.',
        style: TextStyle(color: theme.colorScheme.error),
      ),
      data: (doses) {
        if (_selectedDoseId != null) {
          selectedDose =
              doses.where((d) => d.id == _selectedDoseId).firstOrNull;
        }
        final isEmpty = doses.isEmpty;
        return DropdownButtonFormField<String>(
          initialValue: _selectedDoseId,
          decoration: InputDecoration(
            labelText: 'Dose *',
            border: const OutlineInputBorder(),
            helperText: isEmpty
                ? 'Nenhuma dose cadastrada — cadastre uma dose primeiro'
                : null,
          ),
          items: isEmpty
              ? const []
              : [
                  for (final dose in doses)
                    DropdownMenuItem(
                      value: dose.id,
                      child: Text(
                        dose.displayLabel,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
          onChanged: isEmpty ? null : (v) => setState(() => _selectedDoseId = v),
        );
      },
    );

    final canContinue = lotResolved && selectedDose != null;

    return AlertDialog(
      title: const Text('Registrar aplicação'),
      content: SizedBox(
        width: 480,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              loteField,
              const SizedBox(height: 16),
              doseField,
              const SizedBox(height: 16),
              TextFormField(
                controller: _dateCtrl,
                readOnly: true,
                decoration: InputDecoration(
                  labelText: 'Data da aplicação *',
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.calendar_today),
                    onPressed: _pickDate,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: canContinue
              ? () => _continue(resolvedLotName!, selectedDose!)
              : null,
          child: const Text('Continuar'),
        ),
      ],
    );
  }
}

/// Shared 120px-label key-value row (same pattern as
/// `resumo_aplicacao_dialog.dart`'s private `_KvRow`) — used only for the
/// locked-lote branch, where the value is plain, non-editable text.
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
                  color:
                      Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: value),
      ],
    );
  }
}
