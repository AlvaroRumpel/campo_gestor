import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/propriedade_model.dart';
import '../data/propriedade_repository.dart';

class PropertyFormDialog extends ConsumerStatefulWidget {
  const PropertyFormDialog({super.key, this.existing});
  final Property? existing;

  @override
  ConsumerState<PropertyFormDialog> createState() => _PropertyFormDialogState();
}

class _PropertyFormDialogState extends ConsumerState<PropertyFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _ownerCtrl;
  bool _saving = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.existing?.name ?? '');
    _ownerCtrl = TextEditingController(text: widget.existing?.owner ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _ownerCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final repo = ref.read(propertyRepositoryProvider);
      final name = _nameCtrl.text.trim();
      final owner =
          _ownerCtrl.text.trim().isEmpty ? null : _ownerCtrl.text.trim();
      if (_isEditing) {
        await repo.updateProperty(
          id: widget.existing!.id,
          name: name,
          owner: owner,
        );
      } else {
        await repo.createPropertyWithMembership(name: name, owner: owner);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao salvar fazenda: $e')),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEditing ? 'Editar fazenda' : 'Nova fazenda'),
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
                  labelText: 'Nome da fazenda *',
                  border: OutlineInputBorder(),
                ),
                validator: (v) =>
                    (v == null || v.trim().isEmpty) ? 'Nome é obrigatório' : null,
                autofocus: true,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _ownerCtrl,
                decoration: const InputDecoration(
                  labelText: 'Proprietário (opcional)',
                  border: OutlineInputBorder(),
                  hintText: 'Ex: João da Silva',
                ),
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
