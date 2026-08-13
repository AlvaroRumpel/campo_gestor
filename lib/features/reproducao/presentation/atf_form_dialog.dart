import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../data/atf_repository.dart';

/// Sentinel dropdown value for the "Outro / sêmen externo" bull option (D-05).
const kOtherBull = '__other__';

/// Single source of the bull display label (WR-01): used by the dropdown item
/// builder AND by `_submit()`'s persisted `bull_name`, so the label shown at
/// selection time can never drift from the label written to the database.
String _bullLabel(AnimalWithContext aw) => aw.animal.breed != null
    ? '#${aw.animal.number} — ${aw.animal.breed}'
    : '#${aw.animal.number}';

/// Creation-only dialog for a new LoteATF (REPR-01, D-01, D-05).
///
/// Sheet-style content shown via `showAdaptiveForm` (redesign): title 20/700,
/// theme inputs, footer Cancelar outline + "Criar ATF" filled h52 r14, with a
/// `LinearProgressIndicator` on top while saving — mirrors `LoteFormDialog`.
///
/// Create-only — no edit path ships this phase, since `atf_batches` has no
/// UPDATE RLS policy (05-RESEARCH.md assumption A3).
class AtfFormDialog extends ConsumerStatefulWidget {
  const AtfFormDialog({super.key, required this.propertyId});

  final String propertyId;

  @override
  ConsumerState<AtfFormDialog> createState() => _AtfFormDialogState();
}

class _AtfFormDialogState extends ConsumerState<AtfFormDialog> {
  final _formKey = GlobalKey<FormState>();
  final _dateFmt = DateFormat('dd/MM/yyyy');

  late final TextEditingController _nameCtrl;
  late final TextEditingController _implantationCtrl;
  late final TextEditingController _inseminationCtrl;
  late final TextEditingController _bullNameCtrl;
  late final TextEditingController _obsCtrl;

  DateTime _implantationDate = DateTime.now();
  DateTime _inseminationDate = DateTime.now();
  String? _selectedBull;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController();
    _implantationCtrl =
        TextEditingController(text: _dateFmt.format(_implantationDate));
    _inseminationCtrl =
        TextEditingController(text: _dateFmt.format(_inseminationDate));
    _bullNameCtrl = TextEditingController();
    _obsCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _implantationCtrl.dispose();
    _inseminationCtrl.dispose();
    _bullNameCtrl.dispose();
    _obsCtrl.dispose();
    super.dispose();
  }

  bool _sameOrAfter(DateTime a, DateTime b) {
    final aDate = DateTime(a.year, a.month, a.day);
    final bDate = DateTime(b.year, b.month, b.day);
    return !aDate.isBefore(bDate);
  }

  Future<void> _pickImplantationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _implantationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _implantationDate = picked;
        _implantationCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  Future<void> _pickInseminationDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _inseminationDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null && mounted) {
      setState(() {
        _inseminationDate = picked;
        _inseminationCtrl.text = _dateFmt.format(picked);
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(atfRepositoryProvider);
      final obsText = _obsCtrl.text.trim();
      final animals = ref.read(animalListByPropertyProvider).asData?.value ??
          const <AnimalWithContext>[];
      final selectedBull =
          animals.where((aw) => aw.animal.id == _selectedBull).firstOrNull;
      final created = await repo.createAtf(
        propertyId: widget.propertyId,
        name: _nameCtrl.text.trim(),
        implantationDate: _implantationDate,
        inseminationDate: _inseminationDate,
        bullAnimalId: _selectedBull != null && _selectedBull != kOtherBull
            ? _selectedBull
            : null,
        bullName: _selectedBull == kOtherBull
            ? _bullNameCtrl.text.trim()
            : (selectedBull != null ? _bullLabel(selectedBull) : null),
        observation: obsText.isEmpty ? null : obsText,
      );
      ref.invalidate(atfListByPropertyProvider);
      if (mounted) Navigator.pop<String>(context, created.id);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Não foi possível criar o ATF. Verifique os dados e tente novamente.',
          ),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final animalsAsync = ref.watch(animalListByPropertyProvider);
    final touros = (animalsAsync.asData?.value ?? const [])
        .where(
          (aw) => aw.animal.category == 'touro' && aw.animal.deletedAt == null,
        )
        .toList()
      ..sort((a, b) => a.animal.number.compareTo(b.animal.number));

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_saving)
              const Padding(
                padding: EdgeInsets.only(bottom: 10),
                child: LinearProgressIndicator(),
              ),
            const Text(
              'Novo ATF',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextFormField(
                      controller: _nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Nome do ATF *',
                      ),
                      validator: (v) => (v == null || v.trim().isEmpty)
                          ? 'Nome do ATF é obrigatório'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _implantationCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Data de implantação *',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickImplantationDate,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _inseminationCtrl,
                      readOnly: true,
                      decoration: InputDecoration(
                        labelText: 'Data de inseminação *',
                        suffixIcon: IconButton(
                          icon: const Icon(Icons.calendar_today),
                          onPressed: _pickInseminationDate,
                        ),
                      ),
                      validator: (v) {
                        if (!_sameOrAfter(
                            _inseminationDate, _implantationDate)) {
                          return 'Data de inseminação deve ser igual ou posterior à data de implantação';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String?>(
                      initialValue: _selectedBull,
                      decoration: const InputDecoration(
                        labelText: 'Touro',
                      ),
                      items: [
                        ...touros.map((aw) {
                          return DropdownMenuItem<String?>(
                            value: aw.animal.id,
                            child: Text(_bullLabel(aw)),
                          );
                        }),
                        const DropdownMenuItem<String?>(
                          value: kOtherBull,
                          child: Text('Outro / sêmen externo'),
                        ),
                      ],
                      onChanged: (v) => setState(() => _selectedBull = v),
                      validator: (v) => v == null
                          ? 'Selecione um touro ou informe sêmen externo'
                          : null,
                    ),
                    if (_selectedBull == kOtherBull) ...[
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _bullNameCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Nome do touro / identificação do sêmen',
                        ),
                        validator: (v) => (v == null || v.trim().isEmpty)
                            ? 'Selecione um touro ou informe sêmen externo'
                            : null,
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _obsCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Observação',
                      ),
                      maxLines: 3,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  flex: 10,
                  child: OutlinedButton(
                    onPressed: _saving
                        ? null
                        : () => Navigator.pop<String>(context, null),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: const Text('Cancelar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 16,
                  child: FilledButton(
                    onPressed: _saving ? null : _submit,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Criar ATF'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
