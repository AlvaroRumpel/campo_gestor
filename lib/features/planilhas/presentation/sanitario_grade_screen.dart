// Aplicação sanitária em grade multi-dose: lote + data no topo, linhas =
// animais ativos do lote, colunas = doses escolhidas, célula = checkbox.
// Salvar → bulk_register_sanitary (1 aplicação por dose marcada).
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/providers/current_property_provider.dart';
import '../../../core/providers/invalidate_property_data.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/campo_app_bar.dart';
import '../../../core/widgets/ui.dart';
import '../../animais/data/animal_constants.dart';
import '../../animais/data/animal_model.dart';
import '../../animais/data/animal_repository.dart';
import '../../lotes/data/lote_model.dart';
import '../../lotes/data/lote_repository.dart';
import '../../sanitario/data/dose_model.dart';
import '../../sanitario/data/dose_repository.dart';
import '../../sanitario/data/kg_per_ua_resolver.dart';
import '../../sanitario/data/sanitary_application_repository.dart';
import '../../sanitario/data/sanitary_calculations.dart';
import '../data/bulk_repository.dart';
import 'editable_grid.dart' show GridSaveBar;

final _dateOnlyFmt = DateFormat('yyyy-MM-dd');
final _brDateFmt = DateFormat('dd/MM/yyyy');

/// Marcações (doseId → animalIds) → payload de bulk_register_sanitary.
List<Map<String, dynamic>> gradeToRows({
  required Map<String, Set<String>> marks,
  required List<Animal> animals,
  required List<Dose> doses,
  required DateTime date,
}) {
  final numberById = {for (final a in animals) a.id: a.number};
  final doseNameById = {for (final d in doses) d.id: d.name};
  final dateStr = _dateOnlyFmt.format(date);
  return [
    for (final e in marks.entries)
      if (doseNameById[e.key] case final String doseName)
        for (final animalId in e.value)
          if (numberById[animalId] case final int number)
            {
              'animal_number': number,
              'dose_name': doseName,
              'applied_at': dateStr,
            },
  ];
}

class SanitarioGradeScreen extends ConsumerStatefulWidget {
  const SanitarioGradeScreen({super.key});

  @override
  ConsumerState<SanitarioGradeScreen> createState() =>
      _SanitarioGradeScreenState();
}

class _SanitarioGradeScreenState extends ConsumerState<SanitarioGradeScreen> {
  String? _lotId;
  DateTime _date = DateTime.now();
  late final _dateCtrl =
      TextEditingController(text: _brDateFmt.format(_date));
  final List<Dose> _doses = [];

  /// doseId → animalIds marcados.
  final Map<String, Set<String>> _marks = {};
  bool _saving = false;

  int get _totalMarks => _marks.values.fold(0, (n, s) => n + s.length);
  int get _doseCountWithMarks =>
      _marks.values.where((s) => s.isNotEmpty).length;
  Set<String> get _markedAnimals =>
      {for (final s in _marks.values) ...s};

  void _toggle(String doseId, String animalId, bool? v) => setState(() {
        final set = _marks.putIfAbsent(doseId, () => {});
        if (v ?? false) {
          set.add(animalId);
        } else {
          set.remove(animalId);
        }
      });

  void _toggleAll(String doseId, List<Animal> animals, bool? v) =>
      setState(() {
        _marks[doseId] = (v ?? false)
            ? {for (final a in animals) a.id}
            : <String>{};
      });

  Future<void> _pickLote(List<Lot> lots) async {
    final picked = await showModalBottomSheet<Lot>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final l in lots)
              ListTile(
                title: Text(l.name),
                onTap: () => Navigator.of(ctx).pop(l),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _lotId = picked.id;
        _marks.clear();
      });
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('pt', 'BR'),
    );
    if (picked != null) {
      setState(() {
        _date = picked;
        _dateCtrl.text = _brDateFmt.format(picked);
      });
    }
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    super.dispose();
  }

  Future<void> _addDose(List<Dose> available) async {
    final remaining = available
        .where((d) => !_doses.any((e) => e.id == d.id))
        .toList();
    if (remaining.isEmpty) return;
    final picked = await showModalBottomSheet<Dose>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final d in remaining)
              ListTile(
                title: Text(d.name),
                subtitle: d.activeIngredient == null
                    ? null
                    : Text(d.activeIngredient!),
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
    if (picked != null) {
      setState(() {
        _doses.add(picked);
        _marks.putIfAbsent(picked.id, () => {});
      });
    }
  }

  Future<void> _save(List<Animal> animals) async {
    final property = ref.read(currentPropertyProvider).asData?.value;
    final lotId = _lotId;
    if (property == null || lotId == null || _totalMarks == 0) return;

    // D-34: aviso de duplicata por coluna (mesmo lote+dose+data).
    final sanRepo = ref.read(sanitaryApplicationRepositoryProvider);
    final dupNames = <String>[];
    for (final d in _doses) {
      if ((_marks[d.id] ?? const {}).isEmpty) continue;
      final dup = await sanRepo.findRecentIdenticalApplication(
        lotId: lotId,
        doseId: d.id,
        appliedAt: _date,
      );
      if (dup != null) dupNames.add(d.name);
    }
    if (dupNames.isNotEmpty && mounted) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aplicação repetida?'),
          content: Text(
            'Já existe aplicação de ${dupNames.join(', ')} neste lote '
            'nesta data. Registrar mesmo assim?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Registrar mesmo assim'),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    if (!mounted) return;

    setState(() => _saving = true);
    try {
      final rows = gradeToRows(
        marks: _marks,
        animals: animals,
        doses: _doses,
        date: _date,
      );
      final res = await ref
          .read(bulkRepositoryProvider)
          .registerSanitary(property.id, rows);
      ref.invalidatePropertyData();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${res.applications} aplicações registradas em '
            '${res.animals} animais'),
      ));
      Navigator.of(context).pop();
    } on BulkImportException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final lots =
        ref.watch(loteListByPropertyProvider).asData?.value ?? const <Lot>[];
    final availableDoses =
        ref.watch(doseListByPropertyProvider).asData?.value ?? const <Dose>[];
    final animals = (_lotId == null
            ? const <Animal>[]
            : ref.watch(animalListByLotProvider(_lotId!)).asData?.value ??
                const <Animal>[])
        .toList()
      ..sort((a, b) => a.number.compareTo(b.number));
    final kgPerUa = resolveActiveKgPerUa(ref);

    return Scaffold(
      appBar: const CampoAppBar(title: 'Aplicação em grade'),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Marque as doses por animal',
                        style: TextStyle(
                            fontSize: 20, fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '1 aplicação por dose marcada ao salvar',
                        style: monoStyle(
                            size: 12.5, color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: DropdownButtonFormField<String>(
                    initialValue: _lotId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Lote'),
                    items: [
                      for (final l in lots)
                        DropdownMenuItem(value: l.id, child: Text(l.name)),
                    ],
                    onChanged: (v) => setState(() {
                      _lotId = v;
                      _marks.clear();
                    }),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 160,
                  child: TextFormField(
                    controller: _dateCtrl,
                    readOnly: true,
                    onTap: _pickDate,
                    style: monoStyle(size: 14),
                    decoration: const InputDecoration(
                      labelText: 'Data',
                      suffixIcon: Icon(Icons.calendar_today, size: 18),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                OutlinedButton.icon(
                  onPressed: () => _addDose(availableDoses),
                  icon: const Icon(Icons.add, size: 20),
                  label: const Text('Adicionar dose'),
                ),
              ],
            ),
          ),
          Expanded(
            child: _lotId == null
                ? EmptyState(
                    icon: Icons.grid_on,
                    title: 'Escolha um lote',
                    message:
                        'Selecione o lote para listar os animais na grade.',
                    action: FilledButton.icon(
                      onPressed: () => _pickLote(lots),
                      icon: const Icon(Icons.playlist_add_check, size: 20),
                      label: const Text('Escolher lote'),
                    ),
                  )
                : _doses.isEmpty
                    ? const EmptyState(
                        icon: Icons.science_outlined,
                        title: 'Adicione uma dose',
                        message:
                            'Cada dose vira uma coluna de marcação na grade.',
                      )
                    : _buildGrid(animals, kgPerUa),
          ),
          if (_totalMarks > 0)
            GridSaveBar(
              summary: Text(
                _doseCountWithMarks == 1
                    ? '1 aplicação será registrada · '
                        '$_totalMarks ${_totalMarks == 1 ? 'dose' : 'doses'} '
                        'em ${_markedAnimals.length} '
                        '${_markedAnimals.length == 1 ? 'animal' : 'animais'}'
                    : '$_doseCountWithMarks aplicações serão registradas · '
                        '$_totalMarks doses em ${_markedAnimals.length} animais',
              ),
              canSave: !_saving,
              saving: _saving,
              saveLabel: 'Registrar aplicações',
              onDiscard: () => setState(_marks.clear),
              onSave: () => _save(animals),
            ),
        ],
      ),
    );
  }

  Widget _buildGrid(List<Animal> animals, double kgPerUa) {
    const fixedWidth = 96.0 + 120.0 + 110.0;
    return Column(
      children: [
        // Cabeçalho
        Container(
          color: AppColors.surfaceVariant,
          child: Row(
            children: [
              const SizedBox(
                  width: 96,
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: OverlineLabel('Nº'),
                  )),
              const SizedBox(
                  width: 120,
                  child: OverlineLabel('CATEGORIA')),
              const SizedBox(width: 110, child: OverlineLabel('RAÇA')),
              for (final d in _doses)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Column(
                      children: [
                        Text(
                          d.name,
                          style: const TextStyle(
                              fontSize: 12.5, fontWeight: FontWeight.w700),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          '${d.dosagePerKg} ml/kg',
                          style: monoStyle(
                              size: 10.5, color: AppColors.textSecondary),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
        // Linha "marcar todos"
        Container(
          decoration: const BoxDecoration(
            color: AppColors.surfaceSubtle,
            border: Border(bottom: BorderSide(color: AppColors.divider)),
          ),
          child: Row(
            children: [
              const SizedBox(width: fixedWidth - 120 - 110),
              const SizedBox(
                width: 230,
                child: Text(
                  'marcar todos',
                  style: TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ),
              for (final d in _doses)
                Expanded(
                  child: Checkbox(
                    tristate: true,
                    value: (_marks[d.id] ?? const {}).isEmpty
                        ? false
                        : _marks[d.id]!.length == animals.length
                            ? true
                            : null,
                    onChanged: (v) =>
                        _toggleAll(d.id, animals, v ?? false),
                  ),
                ),
            ],
          ),
        ),
        // Linhas de animais
        Expanded(
          child: ListView.builder(
            itemCount: animals.length,
            itemBuilder: (context, i) {
              final a = animals[i];
              return Container(
                height: 44,
                decoration: const BoxDecoration(
                  border:
                      Border(bottom: BorderSide(color: AppColors.divider)),
                ),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        child: Text('#${a.number}',
                            style: monoStyle(
                                size: 15, weight: FontWeight.w700)),
                      ),
                    ),
                    SizedBox(
                      width: 120,
                      child: Text(
                          kCategoryLabels[a.category] ?? a.category,
                          style: const TextStyle(fontSize: 14)),
                    ),
                    SizedBox(
                      width: 110,
                      child: Text(
                        a.breed == null || a.breed!.trim().isEmpty
                            ? '—'
                            : a.breed!,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            fontSize: 13, color: AppColors.textSecondary),
                      ),
                    ),
                    for (final d in _doses)
                      Expanded(
                        child: Checkbox(
                          value:
                              (_marks[d.id] ?? const {}).contains(a.id),
                          onChanged: (v) => _toggle(d.id, a.id, v),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        // Totais por dose
        Container(
          color: AppColors.statsStrip,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            children: [
              const SizedBox(
                width: fixedWidth,
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10),
                  child: OverlineLabel('TOTAIS POR DOSE'),
                ),
              ),
              for (final d in _doses)
                Expanded(child: _doseTotals(d, animals, kgPerUa)),
            ],
          ),
        ),
      ],
    );
  }

  Widget _doseTotals(Dose d, List<Animal> animals, double kgPerUa) {
    final marked = _marks[d.id] ?? const <String>{};
    final categories = [
      for (final a in animals)
        if (marked.contains(a.id)) a.category,
    ];
    final ua = totalUaForCategories(categories);
    final volume = totalVolumeMl(ua, d.dosagePerKg, kgPerUa);
    final cost = totalCost(ua, d.costPerKg, kgPerUa);
    return Column(
      children: [
        Text('${marked.length} animais',
            style: monoStyle(size: 12, weight: FontWeight.w700)),
        Text(
          cost == null
              ? formatVolumeMl(volume)
              : '${formatVolumeMl(volume)} · ${formatCurrencyBrl(cost)}',
          style: monoStyle(size: 11, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
