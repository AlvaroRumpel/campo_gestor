import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/current_property_provider.dart';
import '../data/piquete_model.dart';
import '../data/piquete_repository.dart';

class PaddockFormDialog extends ConsumerStatefulWidget {
  const PaddockFormDialog({super.key, this.existing});
  final Paddock? existing;

  @override
  ConsumerState<PaddockFormDialog> createState() => _PaddockFormDialogState();
}

class _PaddockFormDialogState extends ConsumerState<PaddockFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _areaCtrl;
  late final TextEditingController _uaCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  String _fmtDouble(double v) => v.toStringAsFixed(2).replaceAll('.', ',');

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _areaCtrl = TextEditingController(
      text: widget.existing != null ? _fmtDouble(widget.existing!.areaHa) : '',
    );
    _uaCtrl = TextEditingController(
      text: widget.existing != null
          ? _fmtDouble(widget.existing!.uaCapacity)
          : '',
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _areaCtrl.dispose();
    _uaCtrl.dispose();
    super.dispose();
  }

  double? _parseDouble(String v) {
    final normalized = v.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }

  String? _validateDecimal(String? v) {
    if (v == null || v.trim().isEmpty) return 'Campo obrigatório';
    final parsed = _parseDouble(v);
    if (parsed == null) return 'Informe um número válido (ex: 8,5)';
    if (parsed <= 0) return 'Deve ser maior que zero';
    return null;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(paddockRepositoryProvider);
      final property = await ref.read(currentPropertyProvider.future);
      if (property == null) throw StateError('Nenhuma propriedade ativa');

      final name = _nameCtrl.text.trim();
      final areaHa = _parseDouble(_areaCtrl.text)!;
      final uaCapacity = _parseDouble(_uaCtrl.text)!;

      if (_isEditing) {
        await repo.updatePaddock(
          id: widget.existing!.id,
          name: name,
          areaHa: areaHa,
          uaCapacity: uaCapacity,
        );
      } else {
        await repo.createPaddock(
          propertyId: property.id,
          name: name,
          areaHa: areaHa,
          uaCapacity: uaCapacity,
        );
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar piquete: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar piquete' : 'Novo piquete'),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nome do piquete *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _areaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Área (ha) *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 8,5',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: _validateDecimal,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _uaCtrl,
                decoration: const InputDecoration(
                  labelText: 'Capacidade (UA) *',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: 12,0',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
                ],
                validator: _validateDecimal,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Text(_isEditing ? 'Salvar' : 'Criar'),
        ),
      ],
    );
  }
}
