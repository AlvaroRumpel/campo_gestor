import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/widgets/ui.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../data/dose_model.dart';
import '../data/dose_repository.dart';
import '../data/kg_per_ua_resolver.dart';
import '../data/sanitary_application_exception.dart';
import '../data/sanitary_calculations.dart';

/// Form content for creating or editing a dose (SANI-01) — shown via
/// `showAdaptiveForm` (bottom sheet <600px, dialog 480px acima). [existing]
/// present means edit mode — controllers seed from the passed row; absent
/// means create mode. One widget, one code path. Pops with `true` on save.
///
/// The two "(calculado)" fields are disabled `TextFormField`s whose
/// controllers are rewritten on every keystroke of their editable
/// counterpart, via `dosagePerUa`/`costPerUa` (sanitary_calculations.dart) —
/// the formula is never restated here (D-13). The per-UA cost field is
/// removed from the widget tree entirely while the cost input is blank
/// (D-11) — never rendered holding "R$ 0,00".
class DoseFormDialog extends ConsumerStatefulWidget {
  const DoseFormDialog({super.key, this.existing});

  final Dose? existing;

  @override
  ConsumerState<DoseFormDialog> createState() => _DoseFormDialogState();
}

class _DoseFormDialogState extends ConsumerState<DoseFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ingredientCtrl;
  late final TextEditingController _dosageCtrl;
  late final TextEditingController _costCtrl;
  final _dosageUaCtrl = TextEditingController();
  final _costUaCtrl = TextEditingController();
  bool _saving = false;
  String? _errorMessage;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    _nameCtrl = TextEditingController(text: existing?.name ?? '');
    _ingredientCtrl =
        TextEditingController(text: existing?.activeIngredient ?? '');
    _dosageCtrl = TextEditingController(
      text: existing != null ? _fmtDouble(existing.dosagePerKg) : '',
    );
    _costCtrl = TextEditingController(
      text:
          existing?.costPerKg != null ? _fmtDouble(existing!.costPerKg!) : '',
    );
    // Listeners recompute the two disabled computed fields live (Task 1
    // truth: "the per-UA dosage field ... recomputes live as the per-kg
    // field is typed").
    _dosageCtrl.addListener(_onNumbersChanged);
    _costCtrl.addListener(_onNumbersChanged);
    // Rebuild para o DiscardGuard reavaliar `dirty` a cada digitação.
    _nameCtrl.addListener(_onNumbersChanged);
    _ingredientCtrl.addListener(_onNumbersChanged);
  }

  @override
  void dispose() {
    _dosageCtrl.removeListener(_onNumbersChanged);
    _costCtrl.removeListener(_onNumbersChanged);
    _nameCtrl.dispose();
    _ingredientCtrl.dispose();
    _dosageCtrl.dispose();
    _costCtrl.dispose();
    _dosageUaCtrl.dispose();
    _costUaCtrl.dispose();
    super.dispose();
  }

  void _onNumbersChanged() => setState(() {});

  String _fmtDouble(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  /// Parses pt-BR decimal input (comma → period). Unparseable or blank input
  /// returns null — never coerced to zero (D-11, T-06-12).
  double? _parseDouble(String v) {
    final normalized = v.trim().replaceAll(',', '.');
    if (normalized.isEmpty) return null;
    return double.tryParse(normalized);
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _saving = true;
      _errorMessage = null;
    });

    try {
      final property = await ref.read(currentPropertyProvider.future);
      if (property == null) {
        throw StateError('Nenhuma propriedade ativa');
      }

      final repo = ref.read(doseRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final ingredientText = _ingredientCtrl.text.trim();
      final activeIngredient = ingredientText.isEmpty ? null : ingredientText;
      final dosage = _parseDouble(_dosageCtrl.text)!;
      final cost = _parseDouble(_costCtrl.text);

      if (_isEditing) {
        await repo.updateDose(
          id: widget.existing!.id,
          name: name,
          activeIngredient: activeIngredient,
          dosagePerKg: dosage,
          costPerKg: cost,
        );
      } else {
        await repo.createDose(
          propertyId: property.id,
          name: name,
          activeIngredient: activeIngredient,
          dosagePerKg: dosage,
          costPerKg: cost,
        );
      }

      ref.invalidatePropertyData();
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      final mapped = asSanitaryException(
        e,
        fallbackMessage:
            'Não foi possível salvar a dose. Verifique os dados e tente novamente.',
      );
      setState(() => _errorMessage = mapped.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final kgPerUa = resolveActiveKgPerUa(ref);
    final dosage = _parseDouble(_dosageCtrl.text);
    final cost = _parseDouble(_costCtrl.text);
    final dosageUa = dosage != null ? dosagePerUa(dosage, kgPerUa) : null;
    final costUa = costPerUa(cost, kgPerUa);
    _dosageUaCtrl.text = dosageUa != null ? _fmtDouble(dosageUa) : '';
    _costUaCtrl.text = costUa != null ? _fmtDouble(costUa) : '';

    final computedStyle = theme.textTheme.bodyMedium
        ?.copyWith(color: theme.colorScheme.primary);

    final existing = widget.existing;
    final dirty = existing == null
        ? (_nameCtrl.text.trim().isNotEmpty ||
            _ingredientCtrl.text.trim().isNotEmpty ||
            _dosageCtrl.text.trim().isNotEmpty ||
            _costCtrl.text.trim().isNotEmpty)
        : (_nameCtrl.text.trim() != existing.name ||
            _ingredientCtrl.text.trim() !=
                (existing.activeIngredient ?? '') ||
            _parseDouble(_dosageCtrl.text) != existing.dosagePerKg ||
            _parseDouble(_costCtrl.text) != existing.costPerKg);
    return DiscardGuard(
      dirty: dirty && !_saving,
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (_saving)
                const LinearProgressIndicator()
              else
                Text(
                  _isEditing ? 'Editar dose' : 'Nova dose',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _nameCtrl,
                  autofocus: true,
                  decoration: const InputDecoration(
                    labelText: 'Nome comercial *',
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Nome comercial é obrigatório'
                      : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _ingredientCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Princípio ativo',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dosageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Dosagem (mL/kg) *',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: 1,0',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) {
                      return 'Dosagem (mL/kg) é obrigatória';
                    }
                    final parsed = _parseDouble(v);
                    if (parsed == null) {
                      return 'Dosagem (mL/kg) é obrigatória';
                    }
                    if (parsed <= 0) {
                      return 'Dosagem (mL/kg) deve ser maior que zero';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _dosageUaCtrl,
                  enabled: false,
                  style: computedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Dosagem por UA (calculado)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Custo (R\$/kg)',
                    border: OutlineInputBorder(),
                    hintText: 'Ex: 8,50',
                  ),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  inputFormatters: [
                    FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                  ],
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return null;
                    if (_parseDouble(v) == null) {
                      return 'Custo (R\$/kg) inválido';
                    }
                    return null;
                  },
                ),
                if (costUa != null) ...[
                const SizedBox(height: 16),
                TextFormField(
                  controller: _costUaCtrl,
                  enabled: false,
                  style: computedStyle,
                  decoration: const InputDecoration(
                    labelText: 'Custo por UA (calculado)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
              if (_errorMessage != null) ...[
                const SizedBox(height: 12),
                Text(
                  _errorMessage!,
                  style:
                      TextStyle(color: theme.colorScheme.error, fontSize: 12),
                ),
              ],
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    flex: 10,
                    child: SizedBox(
                      height: 52,
                      child: OutlinedButton(
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Cancelar'),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 14,
                    child: SizedBox(
                      height: 52,
                      child: FilledButton(
                        onPressed: _saving ? null : _submit,
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: _saving
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Text('Salvar dose'),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
      ),
    );
  }
}
